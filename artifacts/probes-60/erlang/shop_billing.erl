-module(shop_billing).
-export([charge/1, bad/1]).
charge(X) -> shop_orders_internal:recompute(X).   % outside the subtree: the "friend" violation
bad(X) -> shop_orders_internal:hidden(X).         % not exported
