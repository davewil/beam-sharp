-module(other_thing).
-compile(no_auto_import).
-export([go/1]).
go(X) -> shop_orders_cache:get(X).
