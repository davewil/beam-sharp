-module(run_batch2).
-export([main/0]).

main() ->
    {ok, Pid1} = gen_server:start_link('BatchReduce', [], []),
    R1 = 'BatchReduce':'Reduce'(Pid1, [1,2,3,4,5]),
    io:format("happy path  Reduce([1..5])     = ~p (want 55)~n", [R1]),

    {ok, Pid2} = gen_server:start_link('BatchReduce', [], []),
    R2 = 'BatchReduce':'Reduce'(Pid2, []),
    io:format("empty batch Reduce([])         = ~p (want 0)~n", [R2]),

    {ok, Pid3} = gen_server:start_link('BatchReduce', [], []),
    %% Kill one of Pid3's monitored workers mid-flight, from outside, using
    %% the coordinator's own monitor list to find it -- simulates a worker
    %% crash the coordinator did not cause and must still settle around.
    Killer = spawn(fun() -> kill_one_worker(Pid3) end),
    unlink(Killer),
    R3 = 'BatchReduce':'Reduce'(Pid3, [10, 20, 30]),
    io:format("crash path  Reduce([10,20,30]) = ~p (one worker killed pre-cast)~n", [R3]),
    ok.

kill_one_worker(Pid3) ->
    kill_one_worker(Pid3, 200).

kill_one_worker(_Pid3, 0) ->
    io:format("kill_one_worker: gave up, no monitor seen~n");
kill_one_worker(Pid3, N) ->
    case erlang:process_info(Pid3, monitors) of
        {monitors, [{process, Worker} | _]} ->
            exit(Worker, kill);
        _ ->
            kill_one_worker(Pid3, N - 1)
    end.
