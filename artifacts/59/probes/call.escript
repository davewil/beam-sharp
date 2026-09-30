#!/usr/bin/env escript
%% call.escript BEAMDIR Mod "Erlang expression using M as the module alias"
%% e.g.  call.escript /tmp/x 'P2' "M:'ViaInt'({1.5, 2})"
main([Dir, Mod, Expr]) ->
    true = code:add_patha(Dir),
    {module, _} = code:load_abs(filename:join(Dir, Mod)),
    {ok, Toks, _} = erl_scan:string(Expr ++ "."),
    {ok, Es} = erl_parse:parse_exprs(Toks),
    Bind = erl_eval:add_binding('M', list_to_atom(Mod), erl_eval:new_bindings()),
    R = try {ok, element(2, erl_eval:exprs(Es, Bind))}
        catch C:E -> {C, E} end,
    io:format("~s~n    => ~p~n", [Expr, R]).
