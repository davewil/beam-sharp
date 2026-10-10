#!/usr/bin/env escript
%% Does a module name determine its application?  Corpus = every app on the
%% code path (OTP + the Elixir distribution + the two fake apps, via ERL_LIBS).
main(_) ->
    Apps = [read_app(D) || D <- code:get_path(), filelib:is_file(app_file(D))],
    Apps1 = [A || A <- Apps, A =/= skip],
    io:format("apps with a .app file on the path: ~p~n", [length(Apps1)]),
    %% 1. does the .app `modules` list equal the beams in ebin?
    Mism = [{N, length(L -- B), length(B -- L)} || {N, L, B} <- Apps1, lists:sort(L) =/= lists:sort(B)],
    io:format("apps whose .app `modules` list /= beams in ebin: ~p~n", [length(Mism)]),
    io:format("  (name, listed-but-no-beam, beam-but-unlisted), first 8: ~p~n", [lists:sublist(Mism, 8)]),
    Empty = [N || {N, [], B} <- Apps1, B =/= []],
    io:format("apps with `{modules, []}` but beams present: ~p~n", [Empty]),
    %% 2. is a module in more than one app?
    All = [{M, N} || {N, _, B} <- Apps1, M <- B],
    Mods = lists:usort([M || {M, _} <- All]),
    Multi = [M || M <- Mods, length(lists:usort([N || {M2, N} <- All, M2 =:= M])) > 1],
    io:format("distinct beam modules: ~p; in more than one app dir: ~p ~p~n", [length(Mods), length(Multi), lists:sublist(Multi, 5)]),
    %% 3. does the module NAME predict the app?
    Pairs = lists:usort(All),
    {Hit, Miss} = lists:partition(fun({M, N}) -> predicts(M, N) end, Pairs),
    io:format("module->app by name rule (M == A, M = A_*, or Elixir first segment snake_cased == A): ~p hit, ~p miss of ~p~n",
              [length(Hit), length(Miss), length(Pairs)]),
    Miss2 = [{M, N} || {M, N} <- Miss],
    io:format("  sample misses: ~p~n", [lists:sublist(shuffle(Miss2), 12)]),
    MissApps = lists:usort([N || {_, N} <- Miss]),
    io:format("  apps containing at least one miss: ~p of ~p~n", [length(MissApps), length(Apps1)]),
    ElxPairs = [P || {M, _} = P <- Pairs, is_elixir(M)],
    {EH, EM} = lists:partition(fun({M, N}) -> predicts(M, N) end, ElxPairs),
    io:format("Elixir modules only: ~p hit, ~p miss: ~p~n", [length(EH), length(EM), lists:sublist(EM, 6)]),
    %% 4. the other direction: from code:which alone (no .app), the dir name
    Dirs = [{M, filename:basename(filename:dirname(filename:dirname(code:which(M))))} || M <- [crypto, httpc, 'Elixir.String', fakeerl_lib, 'Elixir.Fakeel']],
    io:format("app from code:which path (dir name minus -vsn): ~p~n", [[{M, strip_vsn(D)} || {M, D} <- Dirs]]),
    %% 5. -pa: a loose ebin dir has no app name in its path
    ok.

app_file(D) ->
    case filelib:wildcard(filename:join(D, "*.app")) of [F|_] -> F; [] -> filename:join(D, "none.app") end.
read_app(D) ->
    case filelib:wildcard(filename:join(D, "*.app")) of
        [F] -> {ok, [{application, N, Kv}]} = file:consult(F),
               B = [list_to_atom(filename:rootname(filename:basename(X))) || X <- filelib:wildcard(filename:join(D, "*.beam"))],
               {N, proplists:get_value(modules, Kv, []), B};
        _ -> skip
    end.
is_elixir(M) -> lists:prefix("Elixir.", atom_to_list(M)).
predicts(M, N) ->
    S = atom_to_list(M), A = atom_to_list(N),
    case is_elixir(M) of
        true -> [_, First | _] = string:split(S, ".", all), snake(First) =:= A;
        false -> S =:= A orelse lists:prefix(A ++ "_", S)
    end.
snake(S) -> lists:flatten(lists:join("_", [string:lowercase(P) || P <- re:split(S, "(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", [{return, list}])])).
strip_vsn(D) -> hd(string:split(D, "-")).
shuffle(L) -> [X || {_, X} <- lists:sort([{erlang:phash2({X, 7}), X} || X <- L])].
