#!/usr/bin/env escript
%% a52: is the owning application derivable from the module name? Compare the app that actually holds the beam with the naive guess (first segment lowercased).
main(_) ->
  [code:add_pathz(P) || P <- filelib:wildcard("/usr/lib/elixir/lib/*/ebin")],
  Mods = ['Elixir.Enum','Elixir.Kernel','Elixir.Logger','Elixir.ExUnit.Case','Elixir.IEx.Helpers','Elixir.Mix.Task','Elixir.Registry',crypto,ssl,public_key,gen_server,lists,mnesia],
  io:format("~-22s ~-14s ~-14s ~s~n",["module","actual app","naive guess","match"]),
  [begin
     P = code:which(M),
     App = case P of non_existing -> "(absent)"; _ -> [_,_|_] = L = filename:split(P), N = lists:nth(length(L)-2, L), hd(string:split(N,"-")) end,
     S = atom_to_list(M),
     Guess = case S of "Elixir."++R -> string:lowercase(hd(string:split(R,"."))); _ -> S end,
     io:format("~-22s ~-14s ~-14s ~p~n",[S, App, Guess, App=:=Guess])
   end || M <- Mods].
