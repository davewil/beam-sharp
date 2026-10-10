-module(shop_orders).
-export([total/1, recompute/1]).
total(C) -> recompute(C).
recompute(C) -> C + 100.
