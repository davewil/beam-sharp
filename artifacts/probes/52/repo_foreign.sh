#!/usr/bin/env bash
# Which foreign modules does this repo's own B# text name, and are they loadable on a bare OTP path?
# usage: repo_foreign.sh REPO_ROOT
R="${1:?repo root}"
cd "$R" || exit 1
for set in "examples+aoc (.bs on disk):compiler/examples aoc:*.bs" \
           "fixtures (.bs):compiler/bin/fixtures:*.bs" \
           "eunit sources (inline B#):compiler/test:*.erl" \
           "docs (LANGUAGE/TOUR/STANDARD-ENVIRONMENT):.:LANGUAGE.md TOUR.md STANDARD-ENVIRONMENT.md"; do
  label="${set%%:*}"; rest="${set#*:}"; dirs="${rest%%:*}"; globs="${rest#*:}"
  files=$(for d in $dirs; do for g in $globs; do find "$d" -maxdepth 6 -name "$g" -not -path '*/_build/*' 2>/dev/null; done; done | sort -u)
  # `using :name {` and `using :'Name' {` at line start / after a quote in test sources
  mods=$(echo "$files" | xargs grep -ohE "using :('[A-Za-z0-9_.]+'|\"[A-Za-z0-9_.]+\"|[a-z_][A-Za-z0-9_]*) *\{" 2>/dev/null \
         | sed -E "s/using :['\"]?([A-Za-z0-9_.]+)['\"]? *\{/\1/")
  total=$(echo "$mods" | grep -c .)
  echo "== $label: $total using-blocks naming $(echo "$mods" | sort -u | grep -c .) distinct modules"
  echo "$mods" | grep . | sort | uniq -c | sort -rn | awk '{print $2" "$1}' > "${TMPDIR:-/tmp}/mods.$$"
  MODS="${TMPDIR:-/tmp}/mods.$$" erl -noshell -eval '
    {ok, B} = file:read_file(os:getenv("MODS")),
    L = [list_to_atom(hd(string:tokens(X, " "))) || X <- string:split(binary_to_list(B), "\n", all), X =/= ""],
    Miss = [M || M <- L, code:which(M) =:= non_existing],
    io:format("   not loadable on a bare OTP path: ~p of ~p distinct~n   ~p~n", [length(Miss), length(L), Miss]), halt().' \
    2>&1 | sed 's/^/ /' 
done 2>&1
