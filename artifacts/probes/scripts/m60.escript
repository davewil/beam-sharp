#!/usr/bin/env escript
%% m60: cost of the subtree predicate per (importer, module) pair, and per import_env over a world of N modules
may_name(Self, M) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case lists:splitwith(fun(S) -> S =/= "Internal" end, Segs) of
        {_, []}      -> true;
        {[], _}      -> true;
        {Prefix, _}  -> lists:prefix(Prefix, string:split(atom_to_list(Self), ".", all))
    end.
main(_) ->
  Self='Shop.Orders',
  W=[list_to_atom("Shop.Mod"++integer_to_list(I)) || I <- lists:seq(1,1000)] ++ ['Shop.Internal.Rate'],
  {US,_}=timer:tc(fun() -> [lists:filter(fun(M)->may_name(Self,M) end, W) || _ <- lists:seq(1,1000)] end),
  io:format("filter over a 1001-module world: ~.1f us per import_env (~.3f us per module)~n",[US/1000, US/1000/1001]).
