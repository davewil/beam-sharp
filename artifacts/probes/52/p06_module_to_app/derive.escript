#!/usr/bin/env escript
%% Can the application be derived from the module name in `using :M`? Test the obvious rules over every
%% module of every installed application (OTP + Elixir's own), read from the .app `modules` key.
main(_) ->
    Apps = filelib:wildcard("/tmp/otp/lib/erlang/lib/*/ebin/*.app") ++ filelib:wildcard("/tmp/otp/lib/elixir/lib/*/ebin/*.app"),
    Rows = lists:append([mods(F) || F <- Apps]),
    {Erl, Ex} = lists:partition(fun({_, M}) -> not lists:prefix("Elixir.", atom_to_list(M)) end, Rows),
    io:format("applications scanned: ~p   modules: ~p (erlang-style ~p, Elixir ~p)~n", [length(Apps), length(Rows), length(Erl), length(Ex)]),
    %% Rule E: first '_'-segment of the module name equals the app name
    RE = [R || R = {A, M} <- Erl, first_seg(atom_to_list(M), $_) =:= atom_to_list(A)],
    io:format("rule 'first _ segment of module == app' holds for ~p of ~p erlang-style modules (~.1f%)~n", [length(RE), length(Erl), 100*length(RE)/length(Erl)]),
    %% Rule X: Elixir.Seg1 lowercased == app
    RX = [R || R = {A, M} <- Ex, string:lowercase(first_seg(strip(atom_to_list(M)), $.)) =:= atom_to_list(A)],
    io:format("rule 'Elixir.<First> lowercased == app' holds for ~p of ~p Elixir modules (~.1f%)~n", [length(RX), length(Ex), 100*length(RX)/length(Ex)]),
    io:format("  ...excluding app 'elixir' (String, Enum, Map, Kernel... all live in app elixir): ~p of ~p~n",
              [length([1 || {A, M} <- RX, A =/= elixir]), length([1 || {A, _} <- Ex, A =/= elixir])]),
    io:format("modules of app elixir that rule X gets wrong: ~p of ~p  e.g. ~p~n",
              [length([1 || {elixir, M} <- Ex, not lists:member({elixir, M}, RX)]), length([1 || {elixir, _} <- Ex]),
               lists:sublist([M || {elixir, M} <- Ex, not lists:member({elixir, M}, RX)], 3)]),
    %% Famous erlang counter-examples
    [io:format("  ~-12w lives in app ~w~n", [M, hd([A || {A, M2} <- Erl, M2 =:= M])]) || M <- [lists, ets, file, gen_server, public_key, erlang]],
    ok.
mods(F) ->
    {ok, [{application, A, Props}]} = file:consult(F),
    [{A, M} || M <- proplists:get_value(modules, Props, [])].
first_seg(S, C) -> hd(string:split(S, [C])).
strip("Elixir." ++ R) -> R.
