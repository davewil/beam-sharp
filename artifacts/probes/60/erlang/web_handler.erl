-module(web_handler).
-export([handle/1]).
handle(C) -> shop_orders:recompute(C).
