#!/usr/bin/env bash
# For each shipped example file with foreign `using` blocks: which application owns each block's module
# (the .app beside the beam), and is any application named by more than one block in the file?
# usage: per_file_apps.sh REPO_ROOT      (ERL_LIBS unset: epgsql is not on this machine's path)
R="${1:?repo root}"; cd "$R/compiler/examples" || exit 1
grep -rn "^using :" . --include=*.bs | sed -E "s/^\.\/([^:]+):[0-9]+:using :['\"]?([A-Za-z0-9_.]+)['\"]? *\{.*/\1 \2/" > "${TMPDIR:-/tmp}/pfa.$$"
PFA="${TMPDIR:-/tmp}/pfa.$$" erl -noshell -eval '
  {ok, B} = file:read_file(os:getenv("PFA")),
  Rows = [list_to_tuple(string:tokens(L, " ")) || L <- string:split(binary_to_list(B), "\n", all), L =/= ""],
  App = fun(M) -> P = code:which(list_to_atom(M)),
            case P of
              non_existing -> not_on_path;
              preloaded -> erts;
              _ -> case filelib:wildcard(filename:join(filename:dirname(P), "*.app")) of
                     [F|_] -> list_to_atom(filename:basename(F, ".app")); [] -> unknown end end end,
  Files = lists:usort([F || {F,_} <- Rows]),
  Rep = [begin As = [App(M) || {F2,M} <- Rows, F2 =:= F],
               io:format("~-46s ~p~n", [F, As]),
               length(As) =/= length(lists:usort(As)) end || F <- Files],
  io:format("files with a foreign block: ~p; of those, an application named by 2+ blocks in one file: ~p~n",
            [length(Files), length([x || true <- Rep])]), halt().'
