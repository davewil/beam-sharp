%% Compiled (not erl_eval) so the loop is not the thing measured. Probe 62e.
-module(alias_bench).
-export([run/0]).
-define(N, 5000000).
loop_real(0, _O, A) -> A;
loop_real(I, O, A) -> loop_real(I - 1, O, A + 'Shop':'Squared'(O)).
loop_alias(0, _O, A) -> A;
loop_alias(I, O, A) -> loop_alias(I - 1, O, A + 'Shop':squared(O)).
loop_real2(0, _O, A) -> A;
loop_real2(I, O, A) -> loop_real2(I - 1, O, A + 'Shop':'Squared'(O)).
ns(F) -> {T, _} = timer:tc(F), T * 1000 / ?N.
med(L) -> lists:nth((length(L) + 1) div 2, lists:sort(L)).
show(Name, L) ->
    io:format("~-34s median ~.2f  min ~.2f  max ~.2f ns/call~n", [Name, med(L), lists:min(L), lists:max(L)]).
run() ->
    O = 'Shop':'New'(3),
    {_, _, _} = {'Shop':'Squared'(O), 'Shop':squared(O), ok},
    Once = fun() -> {ns(fun() -> loop_real(?N, O, 0) end),
                     ns(fun() -> loop_alias(?N, O, 0) end),
                     ns(fun() -> loop_real2(?N, O, 0) end)} end,
    _ = [Once() || _ <- lists:seq(1, 3)],
    Runs = [Once() || _ <- lists:seq(1, 15)],
    show("Squared (real)", [A || {A, _, _} <- Runs]),
    show("squared (delegating alias)", [B || {_, B, _} <- Runs]),
    show("Squared again (control, same fn)", [C || {_, _, C} <- Runs]),
    io:format("alias - real (median of paired deltas): ~.2f ns; control - real: ~.2f ns~n",
              [med([B - A || {A, B, _} <- Runs]), med([C - A || {A, _, C} <- Runs])]).
