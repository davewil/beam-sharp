-module(recloop_erl).
-export([run_noguard/1, run_guard/1]).
%% Hand-written equivalents of the loop in RecLoop/RecLoop.bs, written from the emitted code's semantics.
%% noguard: no tag test (what a private function would pay if ticket 59 rules the guard out).
%% guard:   the tag test per call, as bsc emits it today (map_get Kind =:= tag).
run_noguard(N) -> maps:get('Total', spin_n(#{'Kind' => 'RecLoop.Acc', 'Total' => 0, 'Count' => 0}, N)).
run_guard(N)   -> maps:get('Total', spin_g(#{'Kind' => 'RecLoop.Acc', 'Total' => 0, 'Count' => 0}, N)).
spin_n(A, 0) -> A;
spin_n(A, L) -> spin_n(A#{'Total' := map_get('Total', A) + L, 'Count' := map_get('Count', A) + 1}, L - 1).
spin_g(A, 0) when map_get('Kind', A) =:= 'RecLoop.Acc' -> A;
spin_g(A, L) when map_get('Kind', A) =:= 'RecLoop.Acc' ->
    spin_g(A#{'Total' := map_get('Total', A) + L, 'Count' := map_get('Count', A) + 1}, L - 1).
