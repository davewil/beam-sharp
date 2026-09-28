#!/usr/bin/env escript
%% NOTE: first run used an escript-local fold and printed 60 us/call (interpreted by erl_eval, invalid); moved to compiled foldmod.erl. Not a tuned result.
%% PREDICTION (before running): flat_size words: {e_int,{1,30},5} = 4+3 = 7 (the {L,C} tuple is shared
%%  in the term only if it is the same heap object; flat_size counts sharing-free, so 7);
%%  {e_neg,{1,29},{e_int,{1,30},5}} = 7 + 4 + 3 = 14; the pre-F51 {e_op,L,'-',{e_int,L,0},{e_int,L,5}} ~ 5+1+... larger (~24).
%%  So the literal is about half the size of e_neg and a third of the old form. Fold cost of a
%%  refinement the size of `value >= -100 and value <= 100` is well under 5 microseconds per fold
%%  (a handful of tuple visits); resolve/2 of the same refinement (real bs_check) is far more than the fold.
main(_) ->
    D = filename:dirname(escript:script_name()),
    true = code:add_patha(D ++ "/build"),
    L = {1,30}, L2 = {1,29},
    Lit = {e_int, L, 5}, Neg = {e_neg, L2, Lit},
    Old = {e_op, L2, '-', {e_int, L2, 0}, Lit},
    [io:format("~-34s flat_size=~3w words  external_size=~3w bytes~n", [N, erts_debug:flat_size(T), erlang:external_size(T)])
       || {N, T} <- [{"{e_int,{1,30},5} (literal)", Lit},
                     {"{e_neg,..,{e_int,..}} (today)", Neg},
                     {"{e_op,'-',{e_int,0},{e_int,5}} (pre-F51, RECORDED shape)", Old}]],
    Pred = fun(N) -> {e_op,{1,31},'and',
                 {e_op,{1,26},'>=',{e_var,{1,20},value}, N(100, {1,29})},
                 {e_op,{1,50},'<=',{e_var,{1,44},value}, {e_int,{1,53},100}}} end,
    Un = Pred(fun(K, Loc) -> {e_neg, Loc, {e_int, Loc, K}} end),
    Fo = Pred(fun(K, Loc) -> {e_int, Loc, -K} end),
    io:format("whole predicate `value >= -100 and value <= 100`: unfolded ~w words, folded ~w words~n",
              [erts_debug:flat_size(Un), erts_debug:flat_size(Fo)]),
    N = 200000,
    {TF, _} = timer:tc(fun() -> [foldmod:fold(Un) || _ <- lists:seq(1, N)] end),
    {TC, _} = timer:tc(fun() -> [Un || _ <- lists:seq(1, N)] end),
    io:format("fold(pred) [probe-local]: ~.3f us/call (loop overhead ~.3f us)~n", [TF / N, TC / N]),
    {TT, _} = timer:tc(fun() -> [foldmod:fold_pred(Un) || _ <- lists:seq(1, N)] end),
    io:format("fold_pred(pred) targeted [probe-local]: ~.3f us/call~n", [TT / N]),
    true = foldmod:fold_pred(Un) =:= Fo,
    M = 20000,
    Ref = {t_refined, 1, {t_builtin, int}, Fo},
    {TR, _} = timer:tc(fun() -> [bs_check:resolve(Ref, #{}) || _ <- lists:seq(1, M)] end),
    io:format("bs_check:resolve/2 of the folded refinement (real module, includes alternatives/1 + refine_all): ~.3f us/call~n", [TR / M]),
    Ref0 = {t_refined, 1, {t_builtin, int}, {e_op,{1,26},'>=',{e_var,{1,20},value},{e_int,{1,29},0}}},
    {TR0, _} = timer:tc(fun() -> [bs_check:resolve(Ref0, #{}) || _ <- lists:seq(1, M)] end),
    io:format("bs_check:resolve/2 of `value >= 0` for scale: ~.3f us/call~n", [TR0 / M]).
