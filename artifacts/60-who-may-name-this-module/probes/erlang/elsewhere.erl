-module(elsewhere).
-export([poke/1, poke_hidden/1]).
poke(N) -> shop_orders:recompute_total(N).
poke_hidden(N) -> shop_orders:hidden(N).
