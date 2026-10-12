#!/usr/bin/env bash
# Probe 64/12 - what can an author write TODAY to look up in a map<string, term>?
#  (a) Map.Get (the decided-but-unbuilt operation)       (b) :maps.find via a foreign signature, tagged
#  (c) :maps.get/3 via a foreign signature returning option<term> / a default       (d) the tagged use at runtime
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mk(){ mkdir -p $W/$1; cat > $W/$1/$1.bs; echo; echo "=== $1 ==="; sed 's/^/  | /' $W/$1/$1.bs; }
mk A_MapGet <<'B'
module A_MapGet
public term Look(map<string, term> m, string k)
Look(m, k) -> Map.Get(m, k)
B
echo "  -- compile (not just --api):"; "$BSC" -o $W/oa $W/A_MapGet 2>&1 | sed "s|$W/||" | sed 's/^/  /' | head -8
mk B_FindTagged <<'B'
module B_FindTagged

using :maps {
    (:ok, term) | :error find(string key, map<string, term> m)
}

public atom Describe(map<string, term> m, string k)
Describe(m, k) -> :maps.find(k, m) switch {
    (:ok, :nothing) => :present_and_is_nothing,
    (:ok, v)        => :present,
    :error          => :absent
}

public (:ok, term) | :error Look(map<string, term> m, string k)
Look(m, k) -> :maps.find(k, m)
B
"$BSC" --api $W/B_FindTagged 2>&1 | sed "s|$W/||" | sed 's/^/  /' | head -6
echo "  -- compile:"; "$BSC" -o $W/ob $W/B_FindTagged 2>&1 | sed "s|$W/||" | sed 's/^/  /'
mk C_GetDefaultOptionTerm <<'B'
module C_GetDefaultOptionTerm

using :maps {
    option<term> get(string key, map<string, term> m, option<term> dflt)
}

public int Use(map<string, term> m)
Use(m) -> 0
B
"$BSC" --api $W/C_GetDefaultOptionTerm 2>&1 | sed "s|$W/||" | sed 's/^/  /' | head -8
mk D_GetWithSentinel <<'B'
module D_GetWithSentinel

// The Get-with-default operation shape. A sentinel the CALLER picks; ambiguity is the caller's.
using :maps {
    term get(string key, map<string, term> m, term dflt)
}

public term Look(map<string, term> m, string k)
Look(m, k) -> :maps.get(k, m, :nothing)
B
"$BSC" --api $W/D_GetWithSentinel 2>&1 | sed "s|$W/||" | sed 's/^/  /' | head -6
echo
echo "=== run B_FindTagged.Describe over real maps (via ValidateAs-free term maps built with :maps.from_list) ==="
mkdir -p $W/E_Run; cat > $W/E_Run/E_Run.bs <<'B'
module E_Run

using :maps {
    map<term, term> from_list(list<(string, term)> kvs)
    (:ok, term) | :error find(string key, map<term, term> m)
}

public atom Describe(string k)
Describe(k) -> :maps.find(k, :maps.from_list([("a", :nothing), ("b", 1)])) switch {
    (:ok, :nothing) => :present_and_is_nothing,
    (:ok, v)        => :present,
    :error          => :absent
}
B
for k in '"a"' '"b"' '"zz"'; do printf '  Describe %-5s -> ' "$k"; "$BSC" -o $W/oe $W/E_Run Describe "$k" 2>&1 | tail -1 | sed "s|$W/||"; done
