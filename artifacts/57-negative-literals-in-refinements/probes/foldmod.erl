%% Probe-local prototype of the fold (compiled, because escript bodies are interpreted by erl_eval
%% and a first run of sizes_cost measured 60 us/call for the SAME logic under the interpreter: an artefact).
-module(foldmod).
-export([fold/1, fold_pred/1]).
fold({e_neg,L,{e_int,_,K}}) -> {e_int,L,-K};
fold(T) when is_tuple(T) -> list_to_tuple([fold(X) || X <- tuple_to_list(T)]);
fold(X) -> X.
%% Targeted form: descends only the nodes a predicate is made of (what a real delta would do).
fold_pred({e_op,L,Op,A,B}) -> {e_op,L,Op,fold_pred(A),fold_pred(B)};
fold_pred({e_neg,L,{e_int,_,K}}) -> {e_int,L,-K};
fold_pred(E) -> E.
