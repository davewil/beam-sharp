-module(forge).
-export([main/0]).
%% Erlang models of the shapes bs_emit would produce. Tag test shape = bs_emit:tag_test/3 (line 590):
%%   map_get('Kind', X) == 'Shop.Order'   as a head guard.
%% B# being modelled (three programs; Total reads a field and returns it as `int`):
%%
%%  A  public int Sum(Order o)               -> Total(o)         // depth 0: exported param IS the record
%%  B  public int First(list<Order> os)      -> Total(hd(os))    // depth 1: record arrives inside an aggregate
%%  C  public int Owed(Basket b)             -> Total(b.Primary) // depth 1: record is a field of a guarded record
%%  private int Total(Order o) -> o.Amount

%% --- Option "exported only": private Total has NO tag test
a_pub(O) when map_get('Kind', O) == 'Shop.Order' -> tot_ng(O).
b_pub([H|_]) -> tot_ng(H).                      %% list<Order>: element not checked (F24 §5 / 18 §2: O(1) only)
c_pub(B) when map_get('Kind', B) == 'Shop.Basket' -> tot_ng(map_get('Primary', B)).
tot_ng(O) -> map_get('Amount', O).

%% --- Option "every function": private Total gets the tag test too
b_pub_g([H|_]) -> tot_g(H).
c_pub_g(B) when map_get('Kind', B) == 'Shop.Basket' -> tot_g(map_get('Primary', B)).
tot_g(O) when map_get('Kind', O) == 'Shop.Order' -> map_get('Amount', O).

forged() -> #{'Kind' => 'Shop.Quote', 'Amount' => <<"free">>}.   %% wrong identity AND wrong payload type
good()   -> #{'Kind' => 'Shop.Order', 'Amount' => 42}.

t(Label, F) ->
  R = try F() of V -> {returned, V} catch C:E -> {C, element(1, if is_tuple(E) -> E; true -> {E} end)} end,
  io:format("~-46s ~p~n", [Label, R]).

main() ->
  io:format("--- forged = ~p~n", [forged()]),
  t("A exported-only   Sum(forged)            ", fun() -> a_pub(forged()) end),
  t("B exported-only   First([forged])        ", fun() -> b_pub([forged()]) end),
  t("C exported-only   Owed(Basket{forged})   ", fun() -> c_pub(#{'Kind'=>'Shop.Basket','Primary'=>forged()}) end),
  t("B every-function  First([forged])        ", fun() -> b_pub_g([forged()]) end),
  t("C every-function  Owed(Basket{forged})   ", fun() -> c_pub_g(#{'Kind'=>'Shop.Basket','Primary'=>forged()}) end),
  io:format("--- limit: right tag, wrong payload (tag test cannot see it, under ANY option)~n"),
  Pay = #{'Kind' => 'Shop.Order', 'Amount' => <<"free">>},
  t("B every-function  First([tag-ok,bad payload])", fun() -> b_pub_g([Pay]) end),
  io:format("--- negative controls (valid input must pass under every option)~n"),
  t("A exported-only   Sum(good)              ", fun() -> a_pub(good()) end),
  t("B exported-only   First([good])           ", fun() -> b_pub([good()]) end),
  t("B every-function  First([good])           ", fun() -> b_pub_g([good()]) end),
  t("C every-function  Owed(Basket{good})      ", fun() -> c_pub_g(#{'Kind'=>'Shop.Basket','Primary'=>good()}) end).
