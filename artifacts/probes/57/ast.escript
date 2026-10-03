#!/usr/bin/env escript
%% ast.escript EBIN -- parse trees for the refinement `value >= -5` vs the pattern `<= -1`
%% (and the other shapes the fold must cover).  bs_parser:parse of bs_lexer tokens.
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Cases = [
      {"refinement  value >= -5",       "module M\ntype T = int where value >= -5\n"},
      {"refinement  value >= 5",        "module M\ntype T = int where value >= 5\n"},
      {"refinement  value >= - 5",      "module M\ntype T = int where value >= - 5\n"},
      {"refinement  value >= (-5)",     "module M\ntype T = int where value >= (-5)\n"},
      {"refinement  value >= 2 + 3",    "module M\ntype T = int where value >= 2 + 3\n"},
      {"refinement  value >= --5",      "module M\ntype T = int where value >= --5\n"},
      {"refinement  value >= -n",       "module M\ntype T = int where value >= -n\n"},
      {"refinement  -5 <= value",       "module M\ntype T = int where -5 <= value\n"},
      {"refinement  value >= -5.0",     "module M\ntype T = int where value >= -5.0\n"},
      {"pattern     Sign(<= -1)",       "module M\npublic atom Sign(int n)\nSign(<= -1) -> :neg\n"},
      {"pattern     Sign(-1)",          "module M\npublic atom Sign(int n)\nSign(-1) -> :neg\n"},
      {"guard       when n >= -5",      "module M\npublic atom Sign(int n)\nSign(n) when n >= -5 -> :neg\n"},
      {"expr        x = -5",            "module M\nF() -> -5\n"}
    ],
    [begin
       {ok, Toks, _} = bs_lexer:string(Src),
       io:format("~s~n   tokens: ~w~n", [Name, [tokname(T) || T <- Toks]]),
       case bs_parser:parse(Toks) of
         {ok, Ast} -> io:format("   ast:    ~s~n", [pick(Ast)]);
         E -> io:format("   parse:  ~p~n", [E])
       end
     end || {Name, Src} <- Cases].

tokname(T) -> case T of {A,_} -> A; {A,_,V} -> {A,V}; _ -> T end.
%% print only the interesting declaration, stripped of line numbers
pick(Ast) ->
    D = lists:last(strip_mod(Ast)),
    lists:flatten(io_lib:format("~0p", [nolines(D)])).
strip_mod(Ast) when is_list(Ast) -> Ast;
strip_mod({_, Ds}) -> Ds;
strip_mod(Other) -> [Other].
nolines(T) when is_tuple(T), tuple_size(T) >= 2, is_atom(element(1,T)), is_integer(element(2,T)) ->
    list_to_tuple([element(1,T) | [nolines(X) || X <- tl(tl(tuple_to_list(T)))]]);
nolines(T) when is_tuple(T) -> list_to_tuple([nolines(X) || X <- tuple_to_list(T)]);
nolines(L) when is_list(L), L =/= [] -> case io_lib:printable_list(L) of true -> L; false -> [nolines(X) || X <- L] end;
nolines(X) -> X.
