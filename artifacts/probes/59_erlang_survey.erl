%% 59_erlang_survey.erl -- Erlang survey for ticket 59.
%% Claim: Erlang emits no guard of its own from a -spec, exported or local; a guard exists only where
%% the author wrote one, and stdlib's own idiom is a guard on the exported door + unguarded local worker
%% (lists.erl:477-487). A record pattern in a head is a tag+arity test the author chose, visibility-blind.
%% REFUTED if spec_only(1.5) raises (a spec would then be enforced), or if priv_rec(#invoice{}) returns.
-module('59_erlang_survey').
-export([go/0, spec_only/1, door/1, via_list/1, via_nested/1]).
-record(order,   {id, total}).
-record(invoice, {id, total}).
-record(wrapper, {inner}).

-spec spec_only(integer()) -> integer().
spec_only(X) -> X.

door(X) when is_integer(X) -> worker(X).      % guard on the export ...
worker(X) -> X.                               % ... none on the local helper
via_list([X | _]) -> worker(X).               % reaches the helper unguarded
priv_rec(#order{total = T}) -> T.              % author-written tag+arity pattern in a LOCAL function
via_nested(#wrapper{inner = I}) -> priv_rec(I).

go() ->
    P = fun(F) -> try {ok, F()} catch C:R -> {C, case R of T when is_tuple(T) -> element(1, T); A -> A end} end end,
    [io:format("~-52s -> ~w~n", [D, P(F)]) || {D, F} <- [
      {"spec_only(1.5)       [-spec integer()]",            fun() -> spec_only(1.5) end},
      {"door(1.5)            [guard on export]",            fun() -> door(1.5) end},
      {"via_list([1.5])      [reaches unguarded local]",    fun() -> via_list([1.5]) end},
      {"via_nested(#wrapper{inner=#invoice{}}) [local rec pattern]", fun() -> via_nested(#wrapper{inner = #invoice{id = 1, total = 5}}) end},
      {"via_nested(#wrapper{inner=#order{total=<<x>>}})",   fun() -> via_nested(#wrapper{inner = #order{id = 1, total = <<"x">>}}) end}]],
    ok.
