#!/usr/bin/env escript
%% PREDICTION (written before running):
%%  P1 `type T = int where value >= -5` parses to {type_refined,..,{e_op,_,'>=',{e_var,_,value},
%%     {e_neg,_,{e_int,_,5}}}} (NOT the ticket's {e_op,'-',{e_int,0},..}: F51 changed it) and
%%     bs_check:check/1 raises opaque_refinement.
%%  P2 `value >= 0 and value <= 5`, `value <= 3 or value >= 10`, `value != 0` are accepted.
%%  P3 `value >= -5 and value <= 5`, `value >= 1 or value <= -1` refused.
%%  P4 `value >= 2 - 7`, `value >= 2 + 3`, `value >= --5`, `value >= -(5)` refused (all non-e_int).
%%  P5 `value >= -5.0` shape is {e_float,..,-5.0}: the parser already folds negated FLOAT literal.
%%  P6 pattern `Sign(<= -1) -> :neg` parses to p_rel with -1 and checks fine.
%%  P9 subtract(-10..10,0) prints "-10..-1 | 1..10" (ticket claim) and int-0..255 prints a negative part.
%%  P7 guard `F(n) when n >= -5 -> ...` parses; guard is unread (no coverage credit), so
%%     `F(n) when n >= -5 -> :a` alone over int is NOT exhaustive (or is accepted only with catch-all).
main(_) ->
    B = filename:dirname(escript:script_name()) ++ "/build",
    true = code:add_patha(B), true = code:add_patha(filename:dirname(escript:script_name())),
    {ok,_} = compile:file(filename:dirname(escript:script_name()) ++ "/lex_mini.erl",
                          [{outdir, B}]), 
    Cases = [
     {"P1 >= -5", "type T = int where value >= -5"},
     {"P2a >= 0 and <= 5", "type T = int where value >= 0 and value <= 5"},
     {"P2b <=3 or >=10", "type T = int where value <= 3 or value >= 10"},
     {"P2c != 0", "type T = int where value != 0"},
     {"P3a -5..5", "type T = int where value >= -5 and value <= 5"},
     {"P3b >=1 or <=-1", "type T = int where value >= 1 or value <= -1"},
     {"P4a 2 - 7", "type T = int where value >= 2 - 7"},
     {"P4b 2 + 3", "type T = int where value >= 2 + 3"},
     {"P4c - -5", "type T = int where value >= - -5"},
     {"P4d -(5)", "type T = int where value >= -(5)"},
     {"P5 -5.0 float lit", "type T = int where value >= -5.0"},
     {"P8 -5 on the left", "type T = int where -5 <= value"}],
    [run(N, S) || {N, S} <- Cases],
    Pat = "module M\natom Sign(int n)\nSign(<= -1) -> :neg\nSign(0) -> :zero\nSign(>= 1) -> :pos\n",
    show("P6 pattern", Pat),
    show("P6b same, no -1 clause", "module M\natom Sign(int n)\nSign(0) -> :zero\nSign(>= 1) -> :pos\n"),
    G1 = "module M\nint F(int n)\nF(n) when n >= -5 -> 1\nF(n) when n < -5 -> 2\n",
    show("P7a guard -5 both halves (would be exhaustive if read)", G1),
    G2 = "module M\nint F(int n)\nF(n) when n >= 0 -> 1\nF(n) when n < 0 -> 2\n",
    show("P7b same guards, non-negative literal 0", G2),
    p9().
run(N, S) ->
    {ok, Ts} = {ok, lex_mini:tokens(S)},
    Res = try {ok, D} = bs_parser:parse(Ts),
               [{type_refined,_,_,_,Pred}] = D,
               {parsed, Pred, chk(D ++ [])}
          catch C:E -> {C, E} end,
    io:format("~s~n  src: ~s~n  ~p~n", [N, S, Res]).
chk(D) -> try case bs_check:check(D) of
                  {ok, _World, _Warnings} -> accepted;
                  {error, Ds} -> {refused, [diag(X) || X <- Ds, element(1,X) =:= error]};
                  Other -> {other, element(1, Other)} end
          catch error:R -> {refused_raised, R} end.
diag({error, _Loc, F, {inexhaustive, Res, _}}) -> {F, inexhaustive, residual, lists:flatten(bs_types:to_pattern(Res))};
diag({error, _Loc, F, R}) -> {F, R}.
show(N, S) ->
    Ts = lex_mini:tokens(S),
    R = case bs_parser:parse(Ts) of
        {ok, D} -> {ast_omitted, chk(D)};
        Err -> Err end,
    io:format("~s~n  ~p~n", [N, R]).
p9() ->
    T = bs_types:range(-10, 10),
    Res = bs_types:subtract(T, bs_types:range(0, 0)),
    io:format("P9 subtract(-10..10, 0) prints as ~s~n", [lists:flatten(bs_types:to_pattern(Res))]),
    R2 = bs_types:subtract(bs_types:int(), bs_types:range(0, 255)),
    io:format("P9b int minus 0..255 prints as ~s~n", [lists:flatten(bs_types:to_pattern(R2))]).
