#!/usr/bin/env escript
%% What does a compiled B# beam ALREADY say about its foreign modules, with no attribute at all?
%% And can the app be DERIVED from the module (code:which -> sibling .app) rather than declared?
main([Beam]) ->
  {ok, {Mod, [{imports, Imps}]}} = beam_lib:chunks(Beam, [imports]),
  Mods = lists:usort([M || {M,_,_} <- Imps]),
  Foreign = [M || M <- Mods, not lists:member(M, [erlang])],
  io:format("beam ~w imports modules: ~p~n", [Mod, Foreign]),
  [io:format("  ~-18w derive app via code:which -> ebin sibling .app: ~p   | naive lowercase guess: ~p~n",
             [M, derive(M), guess(M)]) || M <- Foreign].

derive(M) ->
  case code:which(M) of
    P when is_list(P) ->
      Ebin = filename:dirname(P),
      case filelib:wildcard(filename:join(Ebin, "*.app")) of
        [App] -> list_to_atom(filename:basename(App, ".app"));
        []    -> {no_app_file_beside_beam, Ebin};
        Many  -> {ambiguous, [filename:basename(A) || A <- Many]}
      end;
    Other -> Other
  end.
guess(M) ->
  case atom_to_list(M) of "Elixir." ++ R -> list_to_atom(string:lowercase(R)); S -> list_to_atom(S) end.
