%% Caller with deliberate type errors against the B# spec: dialyzer must flag BOTH spellings if specs carry.
-module(misuse).
-export([via_original/0, via_alias/0]).
via_original() -> 'Shop':'Amount'(not_a_map).
via_alias() -> 'Shop':amount(not_a_map).
