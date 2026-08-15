-module(fibbench).
-export([main/1]).

%% fib(N) here builds a LIST of N Fibonacci numbers, so a single run allocates
%% on the order of a gigabyte — the last number alone has ~0.209N digits.
%%
%% THE FIRST VERSION OF THIS HARNESS WAS MEASURING GARBAGE COLLECTION. Timing
%% the calls in one process gave a min/median spread of 8x for Elixir (82 ms
%% against 832 ms), because each run's garbage was still being collected while
%% the next one ran, and the order the implementations happened to run in
%% decided who paid.
%%
%% Every run now happens in a FRESH PROCESS which then exits, so its heap is
%% discarded wholesale rather than collected — the standard shape for
%% allocation-heavy work on this VM. A settle pause and an explicit collection
%% between implementations keeps one from paying for the last.
main([Arg]) ->
    N = list_to_integer(if is_atom(Arg) -> atom_to_list(Arg); true -> Arg end),
    Impls = [{"Erlang",     fun fib_erl:fib/1},
             {"Elixir",     fun 'Elixir.FibEx':fib/1},
             {"Gleam",      fun fib_gleam:fib/1},
             {"beam-sharp", fun 'Fib':'Fib'/1}],
    Runs = 9,
    Results = [run(Nm, F, N, Runs) || {Nm, F} <- Impls],
    [{_, Ref, _, _, _} | _] = Results,
    io:format("fib(~w) — a list of ~w numbers, the last with ~w digits~n",
              [N, length(Ref), length(integer_to_list(lists:last(Ref)))]),
    io:format("~w runs each, every run in its own process~n~n", [Runs]),
    io:format("~-12s ~9s ~9s ~9s ~8s~n", ["", "min ms", "med ms", "max ms", "rel"]),
    Base = lists:min([Mn || {_, _, Mn, _, _} <- Results]),
    [io:format("~-12s ~9.1f ~9.1f ~9.1f ~7.2fx~n",
               [Nm, Mn / 1000, Md / 1000, Mx / 1000, Mn / Base])
     || {Nm, _, Mn, Md, Mx} <- Results],
    case length(lists:usort([R || {_, R, _, _, _} <- Results])) of
        1 -> io:format("~nall four agree~n");
        K -> io:format("~n~w DIFFERENT ANSWERS~n", [K])
    end,
    halt().

run(Name, F, N, Runs) ->
    Answer = call(F, N),
    settle(),
    Ts = [time_once(F, N) || _ <- lists:seq(1, Runs)],
    S = lists:sort(Ts),
    {Name, Answer, hd(S), lists:nth(Runs div 2 + 1, S), lists:last(S)}.

%% A fresh process per run: its heap dies with it, so nothing it allocated is
%% still being collected when the next run starts.
time_once(F, N) ->
    Self = self(),
    Pid = spawn(fun() -> {T, _} = timer:tc(F, [N]), Self ! {done, self(), T} end),
    receive {done, Pid, T} -> T end.

call(F, N) ->
    Self = self(),
    Pid = spawn(fun() -> Self ! {r, self(), F(N)} end),
    receive {r, Pid, R} -> R end.

settle() ->
    [erlang:garbage_collect(P) || P <- processes()],
    timer:sleep(150).
