#!/usr/bin/env escript
%%! -noshell
%% 57_timing -- claim: neither fix costs measurable compile time (the fold is O(size of comparand)).
%% REFUTED by: a patched variant's median parse or check time exceeding stock's by more than the
%% run-to-run spread (compare min..median of stock against itself in the control rows).
%% usage: 57_timing.escript EBIN_DIR SOURCE_FILE N
main([Ebin, File, NS]) ->
    true = code:add_patha(Ebin),
    N = list_to_integer(NS),
    {ok, B} = file:read_file(File),
    Src = binary_to_list(B),
    Parse = fun() -> {ok, T, _} = bs_lexer:string(Src), {ok, D} = bs_parser:parse(T), D end,
    Decls = Parse(),
    Check = fun() -> bs_check:check(Decls) end,
    PT = times(Parse, N), CT = times(Check, N div 4),
    io:format("lex+parse n=~p min=~pus median=~pus | check n=~p min=~pus median=~pus~n",
              [N, lists:min(PT), med(PT), N div 4, lists:min(CT), med(CT)]).
times(F, N) -> F(), F(), [element(1, timer:tc(F)) || _ <- lists:seq(1, N)].
med(L) -> lists:nth((length(L) + 1) div 2, lists:sort(L)).
