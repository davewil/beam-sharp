-module(entry2).
-export([proven/1, unproven/1, rec_proven/1]).
%% Local-only functions carrying the guards bsc would emit if the scope were widened.
%% loc_int is called from proven/1 (argument already is_integer) and from unproven/1 (no proof).
loc_int(N) when is_integer(N) -> N + 1.
proven(Y) when is_integer(Y) -> loc_int(Y).
unproven(Y) -> loc_int(Y).
%% record tag test on a local-only function, called from a caller that has ALREADY tag-tested the same map.
loc_rec(O) when map_get('Kind', O) =:= 'T.Order' -> map_get('Total', O).
rec_proven(O) when map_get('Kind', O) =:= 'T.Order' -> loc_rec(O).
