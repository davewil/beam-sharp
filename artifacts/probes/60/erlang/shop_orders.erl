-module(shop_orders).
-export([total/1]).
total(X) -> shop_orders_cache:get(X).
