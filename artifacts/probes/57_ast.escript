#!/usr/bin/env escript
%%! -noshell
%% 57_ast -- claim (ticket 57 "Why it happens"): `value >= -5` reaches the checker as
%% {e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}.
%% REFUTED by: the stock line for R1 not being that tuple. (It is NOT at HEAD: F51 made
%% unary minus an `e_neg` node, so the stock output is {e_neg,..}.)
%% usage: 57_ast.escript EBIN_DIR   -- prints the parsed AST of several sources
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Srcs = ["type T = int where value >= -5",
            "type T = int where value >= 5",
            "type T = int where value >= -5.0",
            "type T = int where value >= -(-5)",
            "type T = int where value >= -5 + 10",
            "type T = int where value >= 1 - -5",
            "type T = int where value >= -2 * 3",
            "type T = int where value >= - 5",
            "F(n) when n >= -5 -> n"],
    [show(S) || S <- Srcs].
show(S) ->
    {ok, Toks, _} = bs_lexer:string(S ++ "\n"),
    R = case bs_parser:parse(Toks) of
            {ok, [D]} -> strip(D);
            Other -> Other
        end,
    io:format("~s~n   ~w~n", [S, R]).
%% drop {Line,Col} locations so the shape is readable
strip({L, C}) when is_integer(L), is_integer(C) -> l;
strip(T) when is_tuple(T) -> list_to_tuple([strip(X) || X <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(X) || X <- L];
strip(X) -> X.
