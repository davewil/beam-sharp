-module(erl_head).
-export([via_cart/1, spec_only/1]).
-record(order, {id, total}).
-record(cart, {item, n}).

via_cart(#cart{item = I}) -> amount(I).          %% exported: cart tag+arity matched in the head
amount(#order{total = T}) -> T.                  %% private: order tag+arity matched in the head, by hand

-spec spec_only(integer()) -> integer().         %% a -spec is documentation: no guard, no check
spec_only(X) -> X + 1.
