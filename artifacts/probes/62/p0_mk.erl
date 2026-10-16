-module(p0_mk).
-export([main/0]).
main() ->
  Forms = [{attribute,1,module,'Shop'},
           {attribute,1,export,[{'New',1},{new,1}]},
           {function,1,'New',1,[{clause,1,[{var,1,'X'}],[],[{tuple,1,[{atom,1,ok},{var,1,'X'}]}]}]},
           {function,2,new,1,[{clause,2,[{var,2,'X'}],[],[{tuple,2,[{atom,2,ok},{var,2,'X'}]}]}]}],
  {ok,_,Bin} = compile:forms(Forms),
  ok = file:write_file("Elixir.Shop.beam.tmp", Bin), % not used
  file:write_file("Shop.beam", Bin),
  file:delete("Elixir.Shop.beam.tmp"),
  halt().
