-module(bench).
-export([main/1, id/1]).
%% usage: erl -noshell -pa EBIN -pa BENCHDIR -run bench main Module Fun ArgTerm Trials Calls
%% Prints: min/median/max ns per call over Trials, minus nothing (the baseline
%% loop is measured in the same VM and printed beside it).
main([M, F, ArgS, TS, NS]) ->
    Mod = list_to_atom(M), Fun = list_to_atom(F),
    {ok, Toks, _} = erl_scan:string(ArgS ++ "."),
    {ok, Arg} = erl_parse:parse_term(Toks),
    T = list_to_integer(TS), N = list_to_integer(NS),
    Target = fun() -> loop(Mod, Fun, Arg, N) end,
    Base   = fun() -> loop(?MODULE, id, Arg, N) end,
    _ = Target(), _ = Base(),                       % warm-up (JIT is ahead of time on load; this warms caches)
    Ts = [time(Target) / N || _ <- lists:seq(1, T)],
    Bs = [time(Base)   / N || _ <- lists:seq(1, T)],
    io:format("~s min=~.3f med=~.3f max=~.3f | baseline med=~.3f (ns/call)~n",
              [M, lists:min(Ts), med(Ts), lists:max(Ts), med(Bs)]),
    halt().
id(X) -> X.
time(Fun) -> S = erlang:monotonic_time(nanosecond), Fun(), erlang:monotonic_time(nanosecond) - S.
loop(_, _, _, 0) -> ok;
loop(M, F, A, N) -> _ = M:F(A), loop(M, F, A, N - 1).
med(L) -> S = lists:sort(L), lists:nth((length(S) + 1) div 2, S).
