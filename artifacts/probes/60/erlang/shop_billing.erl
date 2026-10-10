-module(shop_billing).
-export([invoice/1]).
invoice(C) -> shop_orders:recompute(C).
