%% Probe 7: per-process memory footprint, bare spawn vs a gen_server-started
%% worker, and mailbox growth under a batch fan-out — the numbers ticket 25's
%% async-processing brief needs to weigh "supervised pool" against "bare spawn".
%% Run: erl -noshell -s probe7_overhead run -s init stop
-module(probe7_overhead).
-export([run/0]).
-export([bare_loop/0]).
-export([init/1, handle_call/3, handle_cast/2]).
-behaviour(gen_server).

run() ->
    io:format("OTP release: ~s~n", [erlang:system_info(otp_release)]),
    bare_spawn_cost(),
    genserver_cost(),
    fanout_cost(1000),
    fanout_cost(10000),
    ok.

%% --- a bare spawned process, parked in receive, doing nothing else ---
bare_loop() ->
    receive
        stop -> ok;
        _ -> bare_loop()
    end.

bare_spawn_cost() ->
    Before = erlang:memory(processes_used),
    Pids = [spawn(?MODULE, bare_loop, []) || _ <- lists:seq(1, 1000)],
    timer:sleep(50),
    After = erlang:memory(processes_used),
    Sizes = [element(2, erlang:process_info(P, memory)) || P <- Pids],
    Words = [element(2, erlang:process_info(P, heap_size)) || P <- Pids],
    io:format("bare spawn x1000: memory delta=~p bytes, per-process avg=~.1f bytes "
               "(process_info memory), avg heap_size=~.1f words~n",
               [After - Before, lists:sum(Sizes) / length(Sizes),
                lists:sum(Words) / length(Words)]),
    [P ! stop || P <- Pids],
    timer:sleep(50),
    ok.

%% --- a minimal gen_server, same idea, via the OTP behaviour ---
init(_) -> {ok, 0}.
handle_call(_Req, _From, S) -> {reply, S, S}.
handle_cast(_Msg, S) -> {noreply, S}.

genserver_cost() ->
    Before = erlang:memory(processes_used),
    Pids = [begin {ok, P} = gen_server:start_link(?MODULE, [], []), P end
            || _ <- lists:seq(1, 1000)],
    timer:sleep(50),
    After = erlang:memory(processes_used),
    Sizes = [element(2, erlang:process_info(P, memory)) || P <- Pids],
    Words = [element(2, erlang:process_info(P, heap_size)) || P <- Pids],
    io:format("gen_server x1000: memory delta=~p bytes, per-process avg=~.1f bytes "
               "(process_info memory), avg heap_size=~.1f words~n",
               [After - Before, lists:sum(Sizes) / length(Sizes),
                lists:sum(Words) / length(Words)]),
    [gen_server:stop(P) || P <- Pids],
    timer:sleep(50),
    ok.

%% --- fan-out-and-collect: N short-lived bare-spawned workers report to self() ---
fanout_cost(N) ->
    Parent = self(),
    T0 = erlang:monotonic_time(microsecond),
    Before = erlang:memory(processes_used),
    _Pids = [spawn(fun() -> Parent ! {result, self(), Id * 2} end)
             || Id <- lists:seq(1, N)],
    Results = collect(N, []),
    T1 = erlang:monotonic_time(microsecond),
    After = erlang:memory(processes_used),
    io:format("fan-out N=~p: collected=~p results, wall=~p us (~.2f us/task), "
               "processes_used delta while running unmeasured (workers exit fast); "
               "post-collect delta=~p bytes~n",
               [N, length(Results), T1 - T0, (T1 - T0) / N, After - Before]),
    ok.

collect(0, Acc) -> Acc;
collect(N, Acc) ->
    receive
        {result, _Pid, V} -> collect(N - 1, [V | Acc])
    after 5000 ->
        io:format("TIMEOUT waiting for fan-out results, got ~p/~p~n", [length(Acc), N]),
        Acc
    end.
