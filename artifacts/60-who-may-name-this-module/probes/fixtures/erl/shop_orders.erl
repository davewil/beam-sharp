-module(shop_orders).
-export([total/1, recompute_total/1, nif_like/0, loaded/0]).
-compile({inline, [recompute_total/1]}).
-nifs([nif_like/0]).
-on_load(init/0).
init() -> persistent_term:put(shop_orders_loaded, true), ok.
total(L) -> recompute_total(L).
recompute_total(L) -> lists:sum(L).
nif_like() -> not_a_nif.
loaded() -> persistent_term:get(shop_orders_loaded).
