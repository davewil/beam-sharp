#!/usr/bin/env escript
%% 59_call.escript BEAM_DIR MODULE FUN 'ERLANG-TERM-ARGLIST' -- call one exported function with
%% a literal argument list and print `ok V` or `Class:Reason`.
main([Dir, M, F, ArgsS]) ->
    true = code:add_patha(Dir),
    {ok, Toks, _} = erl_scan:string(ArgsS ++ "."),
    {ok, Args} = erl_parse:parse_term(Toks),
    R = try {ok, apply(list_to_atom(M), list_to_atom(F), Args)} catch C:E -> {C, E} end,
    case R of {ok, V} -> io:format("~s:~s~w -> ok ~p~n", [M, F, Args, V]);
              {C1, E1} -> io:format("~s:~s~w -> ~s:~p~n", [M, F, Args, C1, E1]) end.
