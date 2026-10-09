#!/usr/bin/env escript
%% P15: how many `using :M {` blocks per .bs file, and how many DISTINCT applications do they come from?
%% (measures the "repeat `in :app` per block" write/read cost on the repo's own sources; unresolvable modules shown as ?)
main(_) ->
    [code:add_pathz(D) || D <- filelib:wildcard("/usr/lib/elixir/lib/*/ebin")],
    Fs = string:split(os:cmd("cd /home/user/beam-sharp && grep -rl --include=*.bs '^using :' . | grep -v _build | sort"), "\n", all),
    lists:foreach(fun("") -> ok; (F) ->
        {ok, B} = file:read_file(filename:join("/home/user/beam-sharp", F)),
        {match, Ms} = re:run(B, "^using :('[^']+'|[a-z_0-9]+)", [multiline, {capture, all_but_first, list}, global]),
        Mods = [list_to_atom(string:trim(M, both, "'")) || [M] <- Ms],
        Apps = [app_of(M) || M <- Mods],
        io:format("~-62s blocks=~p distinct_apps=~p ~w~n", [F, length(Mods), length(lists:usort(Apps)), lists:zip(Mods, Apps)])
    end, Fs).
app_of(M) -> case code:which(M) of
    non_existing -> '?';
    preloaded -> erts;
    Beam -> list_to_atom(hd(string:split(filename:basename(filename:dirname(filename:dirname(Beam))), "-")))
  end.
