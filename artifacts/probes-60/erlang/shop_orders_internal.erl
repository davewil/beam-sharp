-module(shop_orders_internal).
-export([recompute/1]).
recompute(X) -> hidden(X) + 1.
hidden(X) -> X.
