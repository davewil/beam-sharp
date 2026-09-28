-module(outsider).
-export([go/0]).
go() -> shop_orders:recompute_total([10,20]).
