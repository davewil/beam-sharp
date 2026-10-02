%% HAND-WRITTEN MODEL of the Erlang shape bs_emit.erl:267-275 / 582-586 produces for
%% the B# program in brief s5. NOT bsc output (bsc cannot be run in this sandbox).
%% forge_u = SAME program, private functions carry NO tag test (the "exported only" narrowing).
-module(forge_u).
-export([ship/1, total/1]).
-define(CUST, 'Shop.Customer').
-define(ORDER, 'Shop.Order').

%% public string Ship(Order o)  -- exported: tag test on the PARAMETER only; o.Customer is not tested
ship(O) when map_get('Kind', O) == ?ORDER -> notify(map_get('Customer', O)).

%% private string Notify(Customer c)
notify(C) -> map_get('Email', C).

%% public int Total(list<Order> os) -- list param: no tag test at the boundary (record_tag/2 -> none)
total([]) -> 0;
total([O | T]) -> price(O) + total(T).

%% private int Price(Order o)
price(O) -> map_get('Amount', O).
