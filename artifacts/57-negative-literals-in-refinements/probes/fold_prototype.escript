#!/usr/bin/env escript
%% NOT bsc behaviour. This models what each option WOULD do by rewriting the parsed AST with a
%% probe-local fold, then feeding the result to the UNMODIFIED bs_check (built by run.sh from the repo files).
%% It answers "is the checker's downstream ready for a literal -5?", not "what does bsc do today".
%% Fold variants:  neg_all   = program-wide {e_neg,_,{e_int,N}} -> {e_int,-N}   (models a fold in parser negate/2)
%%                 neg_pred  = same, but only inside refinement predicates and guards (models checker-side fold in alternatives/1)
%%                 arith_pred= neg_pred plus + - * over two e_int literals inside predicates/guards (wider checker fold)
%% PREDICTION (before running):
%%  F1 neg_pred and neg_all both make `value >= -5 and value <= 5`, `value >= 1 or value <= -1` accepted (the
%%     algebra takes negative bounds: ticket 57 says so and P9 in bsc_pieces.out shows it prints them).
%%  F2 neg_pred makes the two-guard `F` (n >= -5 / n < -5) exhaustive; without it (bsc_pieces P7a) it is not.
%%  F3 `Neg F(int n)\nF(n) -> -1` with `type Neg = int where value <= 0`: refused TODAY (e_neg types as int,
%%     bs_check.erl:2807) -- and neg_pred does NOT fix it, while neg_all DOES (type_of(e_int) = range(N,N)).
%%     (If F3 is accepted today my reading of 2807-2811 is wrong.)
%%  F4 `value >= 2 + 3` is refused under neg_pred and accepted under arith_pred (value >= 5).
%%  F5 the residual `-10..-1 | 1..10` is writable under both folds as
%%     `value >= -10 and value <= -1 or value >= 1 and value <= 10` and prints as -10..-1 | 1..10.
main(_) ->
    D = filename:dirname(escript:script_name()),
    true = code:add_patha(D ++ "/build"),

    Progs = [
      {"F1a refinement -5..5",  "type T = int where value >= -5 and value <= 5\n"},
      {"F1b refinement <=-1 | >=1", "type T = int where value >= 1 or value <= -1\n"},
      {"F5  residual spelled out", "type T = int where value >= -10 and value <= -1 or value >= 1 and value <= 10\n"},
      {"F4  refinement >= 2 + 3", "type T = int where value >= 2 + 3\n"},
      {"F2  guards -5 halves", "module M\nint F(int n)\nF(n) when n >= -5 -> 1\nF(n) when n < -5 -> 2\n"},
      {"F3  return -1 into `value <= 0`", "module M\ntype Neg = int where value <= 0\nNeg F(int n)\nF(n) -> -1\n"},
      {"F3b return 0 (control)", "module M\ntype Neg = int where value <= 0\nNeg F(int n)\nF(n) -> 0\n"},
      {"F3c return -1 into bare int (control)", "module M\nint F(int n)\nF(n) -> -1\n"}
    ],
    lists:foreach(fun({N, Src}) ->
        io:format("~s~n", [N]),
        [io:format("    ~-11s ~s~n", [V, verdict(Src, V)]) || V <- [none, neg_pred, neg_all, arith_pred]]
      end, Progs).
verdict(Src, V) ->
    try
      {ok, D0} = bs_parser:parse(lex_mini:tokens(Src)),
      D = case V of
            none -> D0;
            neg_all -> fold(D0, neg);
            neg_pred -> map_preds(D0, fun(P) -> fold(P, neg) end);
            arith_pred -> map_preds(D0, fun(P) -> fold(fold(P, neg), arith) end)
          end,
      case bs_check:check(D) of
        {ok, _, _} -> "accepted";
        {error, Ds} -> "refused " ++ lists:flatten(io_lib:format("~p", [[reason(X) || X <- Ds, element(1,X) =:= error]]))
      end
    catch error:{opaque_refinement,_} -> "refused opaque_refinement";
          error:R -> "raised " ++ lists:flatten(io_lib:format("~P", [R, 8]))
    end.
reason({error,_,F,{inexhaustive,Res,_}}) -> {F, inexhaustive, lists:flatten(bs_types:to_pattern(Res))};
reason({error,_,F,R}) -> {F, element(1, R)}.
map_preds(Ds, Fun) -> [map_pred(D, Fun) || D <- Ds].
map_pred({type_refined,L,N,B,P}, Fun) -> {type_refined,L,N,B,Fun(P)};
map_pred({clause,L,N,Ps,{guard,G},B}, Fun) -> {clause,L,N,Ps,{guard,Fun(G)},B};
map_pred(D, _) -> D.
fold(T, neg) when is_tuple(T) ->
    case T of
      {e_neg,L,{e_int,_,N}} -> {e_int,L,-N};
      _ -> list_to_tuple([fold(X, neg) || X <- tuple_to_list(T)]) end;
fold(T, arith) when is_tuple(T) ->
    case [fold(X, arith) || X <- tuple_to_list(T)] of
      [e_op,L,Op,{e_int,_,A},{e_int,_,B}] when Op=:='+'; Op=:='-'; Op=:='*' ->
          {e_int,L,erlang:Op(A,B)};
      Es -> list_to_tuple(Es) end;
fold(L, K) when is_list(L) -> [fold(X, K) || X <- L];
fold(X, _) -> X.
