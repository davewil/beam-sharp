-module(d1).
-export([e/1, esc/0, w/1, forge_local/0]).
-export_type([order/0]).
-type order() :: #{'Kind' := 'Order', total := integer(), status := atom()}.
-type wrapper() :: #{'Kind' := 'Wrapper', order := order()}.

%% exported entry, spec'd, passes its own parameter to a private function
-spec e(order()) -> integer().
e(O) -> p(O).

%% private function, spec'd like a public one (bs_emit.erl:32 does the same)
-spec p(order()) -> integer().
p(O) -> maps:get(total, O).

%% a FORGED literal reaching the private function from inside the module
forge_local() -> p(#{'Kind' => 'Invoice', total => 7, status => draft}).

%% nested: exported takes a wrapper, hands its field on
-spec w(wrapper()) -> integer().
w(W) -> p(maps:get(order, W)).

%% escape: a private function handed out as a value
-spec esc() -> fun((order()) -> integer()).
esc() -> fun p/1.
