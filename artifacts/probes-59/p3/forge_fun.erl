-module(forge_fun).
-export([main/0, handler/0]).
%% A private function leaves the module as a fun value. Foreign code then calls it with any term.
%% Modelled B#:  public fun<Order,int> Handler() -> Total;   private int Total(Order o) -> o.Amount
handler() -> fun tot_ng/1.         %% exported-only: no tag test
tot_ng(O) -> map_get('Amount', O).
tot_g(O) when map_get('Kind', O) == 'Shop.Order' -> map_get('Amount', O).
main() ->
  Forged = #{'Kind' => 'Shop.Quote', 'Amount' => <<"free">>},
  %% the "foreign" caller: plain Erlang using only the fun value, no knowledge of the module's internals
  io:format("exported-only, fun escapes : ~p~n", [catch (handler())(Forged)]),
  io:format("every-function, fun escapes: ~p~n", [catch (fun tot_g/1)(Forged)]),
  io:format("control, valid via fun      : ~p~n", [catch (handler())(#{'Kind'=>'Shop.Order','Amount'=>1})]).
