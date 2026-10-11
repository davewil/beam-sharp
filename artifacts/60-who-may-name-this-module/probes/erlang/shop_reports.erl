-module(shop_reports).
-export([report/1]).
report(N) -> shop_orders:recompute_total(N).
