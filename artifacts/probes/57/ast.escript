#!/usr/bin/env escript
%% Probe A: AST shapes. Real lexer+parser from compiler/src (OTP-25 shim, see build.sh).
main([Ebin]) ->
    true = code:add_patha(Ebin),
    P = fun(Label, Src) ->
        {ok, T, _} = bs_lexer:string(Src),
        {ok, D} = bs_parser:parse(T),
        io:format("~-34s ~p~n", [Label, strip(D)]),
        D
    end,
    [R] = [X || X = {type_refined,_,_,_,_} <- P("refinement value >= -5", "module M\ntype T = int where value >= -5\n")],
    {type_refined,_,_,_,Pred} = R,
    {e_op,_,'>=',_,{e_neg,_,{e_int,_,5}}} = Pred,   %% falsifier: ticket's {e_op,'-',{e_int,0},..}
    P("pattern rel  <= -1", "module M\npublic atom S(int n)\nS(<= -1) -> :a\nS(_) -> :b\n"),
    P("pattern lit  -1",    "module M\npublic atom S(int n)\nS(-1) -> :a\nS(_) -> :b\n"),
    P("refinement value >= 2 + 3", "module M\ntype T = int where value >= 2 + 3\n"),
    P("refinement value >= -(5)",  "module M\ntype T = int where value >= -(5)\n"),
    P("refinement value >= 0 - 5", "module M\ntype T = int where value >= 0 - 5\n"),
    P("refinement value >= - -5",  "module M\ntype T = int where value >= - -5\n"),
    P("refinement value >= -5.0 (float)", "module M\ntype T = int where value >= -5.0\n"),
    %% term sizes of the competing node shapes, words (erts_debug)
    Lit = -5, Neg = {e_neg,2,{e_int,2,5}}, Old = {e_op,2,'-',{e_int,2,0},{e_int,2,5}}, EInt = {e_int,2,-5},
    io:format("flat_size words: literal ~p  {e_int,L,-5} ~p  e_neg ~p  old 0-5 ~p~n",
              [erts_debug:flat_size(Lit), erts_debug:flat_size(EInt), erts_debug:flat_size(Neg), erts_debug:flat_size(Old)]).
strip(X) -> X.
