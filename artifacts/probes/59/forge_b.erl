%% HAND-WRITTEN MODEL of the Erlang shape bs_emit.erl produces for the B# program in the brief (s5).
%% NOT bsc output (bsc cannot be built in this sandbox); the guard forms are the ones read at
%% bs_emit.erl:582-586 (tag_test) and 495 (int_test).
%% forge_b = OPTION B: every function carries the guards it is owed, private ones included.
-module(forge_b).
-export([ship/1, ship_whole/1, total/1, rule/0, rule_int/0]).
-define(CUST, 'Shop.Customer').
-define(ORDER, 'Shop.Order').

%% public string Ship(Order o)  -- tag test on the PARAMETER only; o.Customer is a sub-term, not tested
ship(O) when map_get('Kind', O) == ?ORDER -> notify(map_get('Customer', O)).
%% private string Notify(Customer c)
notify(C) when map_get('Kind', C) == ?CUST -> map_get('Email', C).

%% public int ShipWhole(Order o) -- hands its whole parameter on (18 s4: "counts as unchecked, and is guarded")
ship_whole(O) when map_get('Kind', O) == ?ORDER -> describe(O).
%% private int Describe(Order o)
describe(O) when map_get('Kind', O) == ?ORDER -> map_get('Id', O).

%% public int Total(list<Order> os) -- a list parameter: record_tag/2 -> none, no guard at the boundary
total([]) -> 0;
total([O | T]) -> price(O) + total(T).
%% private int Price(Order o)
price(O) when map_get('Kind', O) == ?ORDER -> map_get('Amount', O).

%% F46: an exported function returns a PRIVATE function as a value (`Rule() -> Notify`)
rule() -> fun notify/1.

%% same, for an int: private int Dbl(int n); public fn(int) -> int RuleInt() -> Dbl
rule_int() -> fun dbl/1.
dbl(N) when is_integer(N) -> N * 2.
