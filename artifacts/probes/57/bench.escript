#!/usr/bin/env escript
%% bench.escript EBIN MODDIR N -- in-VM timings, microseconds, over N runs after 3 warm-ups:
%%   parse = bs_lexer:string + bs_parser:parse   compile = bsc:status([MODDIR], batch)
%% Output is silenced.  Reports min / median / mean.
main([Ebin, Dir, NS]) ->
    true = code:add_patha(Ebin), N = list_to_integer(NS),
    {ok, Bin} = file:read_file(filename:join(Dir, "a.bs")), Src = binary_to_list(Bin),
    Null = spawn(fun Loop() -> receive {io_request, From, Ref, _} -> From ! {io_reply, Ref, ok}, Loop() end end),
    group_leader(Null, self()),
    Parse = fun() -> {ok, T, _} = bs_lexer:string(Src), R = bs_parser:parse(T), element(1, R) end,
    Comp  = fun() -> bsc:status([Dir], batch) end,
    [begin Parse(), Comp() end || _ <- lists:seq(1, 3)],
    P = [element(1, timer:tc(Parse)) || _ <- lists:seq(1, N)],
    C = [element(1, timer:tc(Comp)) || _ <- lists:seq(1, N)],
    S = fun(L) -> Ls = lists:sort(L), {hd(Ls), lists:nth((length(Ls)+1) div 2, Ls), round(lists:sum(Ls)/length(Ls))} end,
    {P1,P2,P3} = S(P), {C1,C2,C3} = S(C),
    io:format(standard_error, "  parse   min ~7w  median ~7w  mean ~7w us   (n=~w, parse result: ~w)~n  compile min ~7w  median ~7w  mean ~7w us   (exit status ~w)~n",
              [P1,P2,P3,N,Parse(),C1,C2,C3,Comp()]).
