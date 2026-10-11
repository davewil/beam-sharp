-module(shop_orders).
-export([apply_order/1, recompute_total/1]).
apply_order(N) -> recompute_total(N) + 1.
recompute_total(N) -> N * 2.
hidden(N) -> N.
