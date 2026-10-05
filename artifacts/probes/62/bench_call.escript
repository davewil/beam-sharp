#!/usr/bin/env escript
%% usage: bench_call.escript EBINDIR MODULE PASCAL_FN SNAKE_FN ITERS
%% Prints: loop=<ns> pc1 pc2 sc1 sc2  (ns per call, min of 3 timed runs of ITERS calls)
%% v2: TWO copies (c1,c2) of the loop for EACH target. Same target, different copy = code-placement bias/noise floor (pc1 vs pc2);
%% effect = mean(sc) - mean(pc), which cancels placement bias. (v1 had one loop copy per target and the A/A/A control showed 0.65ns of placement bias.)
main([Dir, ModS, PS, SS, ItS]) ->
    true = code:add_patha(Dir),
    Mod = list_to_atom(ModS), P = list_to_atom(PS), S = list_to_atom(SS), N = list_to_integer(ItS),
    {module, Mod} = code:ensure_loaded(Mod),
    Src = lists:flatten(io_lib:format(
      "-module(benchx).~n-export([loop/1,p1/1,p2/1,s1/1,s2/1]).~n"
      "loop(0) -> ok; loop(N) -> id(5), loop(N-1).~n id(X) -> X.~n"
      "p1(0) -> ok; p1(N) -> '~s':'~s'(5), p1(N-1).~n"
      "p2(0) -> ok; p2(N) -> '~s':'~s'(5), p2(N-1).~n"
      "s1(0) -> ok; s1(N) -> '~s':'~s'(5), s1(N-1).~n"
      "s2(0) -> ok; s2(N) -> '~s':'~s'(5), s2(N-1).~n", [Mod,P,Mod,P,Mod,S,Mod,S])),
    {ok, Toks, _} = erl_scan:string(Src),
    Forms = parse(Toks, []),
    {ok, benchx, Bin} = compile:forms(Forms, [no_inline]),   %% no_inline: keep `loop`'s id/1 call real
    {module, benchx} = code:load_binary(benchx, "benchx.beam", Bin),
    T = fun(F) -> lists:min([begin {U, ok} = timer:tc(benchx, F, [N]), U end || _ <- [1,2,3]]) * 1000 / N end,
    _ = T(loop),                       %% warm-up
    L = T(loop), PA = T(p1), SA = T(s1), PB = T(p2), SB = T(s2),
    io:format("loop=~.2f pc1=~.2f pc2=~.2f sc1=~.2f sc2=~.2f effect=~.2f~n", [L, PA, PB, SA, SB, (SA+SB)/2 - (PA+PB)/2]).
parse([], Acc) -> lists:reverse(Acc);
parse(Toks, Acc) ->
    {Form, Rest} = split(Toks, []),
    {ok, F} = erl_parse:parse_form(Form),
    parse(Rest, [F | Acc]).
split([{dot, _} = D | R], Acc) -> {lists:reverse([D | Acc]), R};
split([T | R], Acc) -> split(R, [T | Acc]).
