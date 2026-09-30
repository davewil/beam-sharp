%% Hand-written Erlang with the same loop and NO boundary guard; and with the same guard bsc emits.
-module(rec_erl).
-export([run_noguard/1, run_guard/1]).
spin_ng(_O, 0, Acc) -> Acc;
spin_ng(O, N, Acc) -> spin_ng(O, N - 1, Acc + map_get('Total', O)).
spin_g(O, 0, Acc) when (map_get('Kind', O) =:= 'RecPub.Order') andalso is_integer(Acc) -> Acc;
spin_g(O, N, Acc) when (map_get('Kind', O) =:= 'RecPub.Order') andalso (is_integer(N) andalso is_integer(Acc)) -> spin_g(O, N - 1, Acc + map_get('Total', O)).
run_noguard(N) -> spin_ng(#{'Kind' => 'RecPub.Order', 'Id' => 1, 'Total' => 3}, N, 0).
run_guard(N) -> spin_g(#{'Kind' => 'RecPub.Order', 'Id' => 1, 'Total' => 3}, N, 0).
