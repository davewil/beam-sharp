-module(shop_reports).
-export([go/0]).
go() -> shop_orders:recompute_total([1,2,3]).
