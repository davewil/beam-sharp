#!/bin/bash
# Ticket 52: prototype — bsc refuses a `using :mod {...}` block whose module is not on the code path.
# Then: what does that break? (a) the shipped examples/exemplars; (b) the gated LANGUAGE.md snippets.
. "$(dirname "$0")/../env.sh"
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
work 52p
mkdir R A; cat > R/R.bs <<'B'
module R
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
public term Client()
Client() -> :'Elixir.Req'.new([])
B
cat > A/A.bs <<'B'
module A
using :analytics_db {
    map<term, term> latest_row(binary site)
}
public map<term, term> LatestRow(binary site)
LatestRow(site) -> :analytics_db.latest_row(site)
B
for v in c c52; do
  export BSC_EBIN=$S/$v/ebin
  echo "=== variant $v"
  for m in R A; do printf '  %s: ' $m; bsc --src-root . $m 2>&1 | head -1 | cut -c1-100; echo; done
done
echo "--- foreign modules named across shipped examples + docs, and which resolve on this machine:"
grep -rhoE "using :('[^']+'|[a-zA-Z_][a-zA-Z0-9_]*)" $ROOT/compiler/examples $ROOT/LANGUAGE.md $ROOT/TOUR.md $ROOT/STANDARD-ENVIRONMENT.md $ROOT/aoc 2>/dev/null --include=*.bs --include=*.md | sed "s/using ://;s/'//g" | sort | uniq -c | sort -rn > mods.txt
cat > chk.escript <<'B'
#!/usr/bin/env escript
main([F]) ->
    {ok, Bin} = file:read_file(F),
    Ls = [string:trim(L) || L <- string:split(binary_to_list(Bin), "\n", all), string:trim(L) =/= ""],
    Rs = [begin [C, M] = string:split(L, " "), {list_to_integer(C), M, code:which(list_to_atom(M))} end || L <- Ls],
    Absent = [{C, M} || {C, M, non_existing} <- Rs],
    io:format("  distinct foreign modules named: ~p, resolvable now: ~p, absent: ~p ~p~n", [length(Rs), length(Rs) - length(Absent), length(Absent), Absent]).
B
escript chk.escript mods.txt
echo "--- which files name the absent ones:"
grep -rln "using :analytics_db\|using :epgsql" $ROOT/compiler/examples $ROOT/LANGUAGE.md $ROOT/TOUR.md $ROOT/STANDARD-ENVIRONMENT.md $ROOT/aoc 2>/dev/null
echo "--- today's parser has no attribute syntax at all: ticket 52's [app: req] spelling"
mkdir T; printf 'module T\n[app: req]\nusing :lists {\n    list<int> reverse(list<int> l)\n}\npublic list<int> Rev(list<int> l)\nRev(l) -> :lists.reverse(l)\n' > T/T.bs
BSC_EBIN=$S/c/ebin bsc --src-root . T 2>&1 | head -2
