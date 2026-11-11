#!/usr/bin/env bash
# PROTOTYPE 64a — what can report "absent" at a `term` value today, and where
# does `option<T>` at `T = term` get past the refusal F31 and F36 built?
#
# Throwaway. Ticket 64, round 1 (2026-11-11). The ticket says a refusal of
# `option<term>` "leaves the author with nothing to reach for". Since it was
# written F36 widened the refusal, F45 shipped the polymorphic signature, F75
# shipped the total `Map` rows, and ticket 108 decided `Map.?Get` returns
# `option<V>`. This probe measures each against the same headers map.
#
#   1. `option<term>` written out            — refused where it is written?
#   2. `option<T>` solved to `T = term`      — refused at the call, or silent?
#   3. the same program run on a header holding the atom `:nothing`
#   4. `Map.?Get` and `Map.Get`              — built?
#   5. the hand-tagged lookup the F31 hint names, over `maps:find/2`
#   6. `Map.Has`, the total row F75 shipped
#
#   ./64a_absent_at_term.sh
#
# Requires: OTP 28, a built bsc. Runs in a temp dir, touches nothing in the tree.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

mk  () { mkdir -p "$WORK/$1"; cat > "$WORK/$1/$1.bs"; }
bsc () { "$BSC" "$@" 2>&1 | sed "s#$WORK/##g" | sed 's/^/    /'; }
hdr () { echo; echo "=== $* ==="; }

# ---------------------------------------------------------------------------
hdr "1. option<term> written out"
mk Written <<'EOF'
module Written

public option<term> Trace(list<(string, term)> headers)
Trace([])                               -> :nothing
Trace([(k, v), ..rest]) when k == "x-trace" -> v
Trace([_, ..rest])                      -> Trace(rest)
EOF
bsc "$WORK/Written/Written.bs"

# ---------------------------------------------------------------------------
hdr "2. option<T>, with T solved to term at the call"
mk Solved <<'EOF'
module Solved

public string Trace(list<(string, term)> headers)
Trace(hs) -> Find(hs, "x-trace") switch {
    :nothing => "no trace header",
    v        => "traced"
}

public term Raw(list<(string, term)> headers)
Raw(hs) -> Find(hs, "x-trace")

private option<T> Find<T>(list<(string, T)> xs, string key)
Find([], _)                         -> :nothing
Find([(k, v), ..rest], key) when k == key -> v
Find([_, ..rest], key)              -> Find(rest, key)
EOF
echo "  compile:"
bsc "$WORK/Solved/Solved.bs"
echo "  --api:"
bsc --api "$WORK/Solved/Solved.bs"

hdr "3. the same program, run"
echo "  header absent:"
bsc "$WORK/Solved/Solved.bs" Trace '[("host", "a")]'
echo "  header present, holding a string:"
bsc "$WORK/Solved/Solved.bs" Trace '[("x-trace", "abc")]'
echo "  header present, holding the atom :nothing:"
bsc "$WORK/Solved/Solved.bs" Trace '[("x-trace", :nothing)]'

# The control: the same Find at a T that does not absorb :nothing.
mk Control <<'EOF'
module Control

public string Port(list<(string, int)> headers)
Port(hs) -> Find(hs, "port") switch {
    :nothing => "no port",
    n        => "has port"
}

private option<T> Find<T>(list<(string, T)> xs, string key)
Find([], _)                         -> :nothing
Find([(k, v), ..rest], key) when k == key -> v
Find([_, ..rest], key)              -> Find(rest, key)
EOF
echo "  CONTROL, T = int, header absent / present:"
bsc "$WORK/Control/Control.bs" Port '[("host", 1)]'
bsc "$WORK/Control/Control.bs" Port '[("port", 80)]'

# ---------------------------------------------------------------------------
hdr "4. Map.?Get and Map.Get over map<string, term>"
mk Marked <<'EOF'
module Marked

public string Trace(map<string, term> headers)
Trace(hs) -> Map.?Get(hs, "x-trace") switch {
    :nothing => "no trace header",
    v        => "traced"
}
EOF
bsc "$WORK/Marked/Marked.bs"
mk Plain <<'EOF'
module Plain

public term Trace(map<string, term> headers)
Trace(hs) -> Map.Get(hs, "x-trace")
EOF
bsc "$WORK/Plain/Plain.bs"

# ---------------------------------------------------------------------------
hdr "5. the hand-tagged lookup, over maps:find/2"
mk Tagged <<'EOF'
module Tagged

using :maps {
    (:ok, term) | :error find(term key, map<term, term> m)
}

public string Trace(map<string, term> headers)
Trace(hs) -> :maps.find("x-trace", hs) switch {
    :error   => "no trace header",
    (:ok, v) => "traced"
}
EOF
echo "  compile:"
bsc "$WORK/Tagged/Tagged.bs"
echo "  header absent / holding a string / holding :nothing:"
bsc "$WORK/Tagged/Tagged.bs" Trace '{ "host" = "a" }'
bsc "$WORK/Tagged/Tagged.bs" Trace '{ "x-trace" = "abc" }'
bsc "$WORK/Tagged/Tagged.bs" Trace '{ "x-trace" = :nothing }'

# ---------------------------------------------------------------------------
hdr "6. Map.Has, the total row F75 shipped"
mk Has <<'EOF'
module Has

public string Trace(map<string, term> headers)
Trace(hs) -> Map.Has(hs, "x-trace") switch {
    :true  => "traced",
    :false => "no trace header"
}
EOF
echo "  compile:"
bsc "$WORK/Has/Has.bs"
echo "  header absent / holding :nothing:"
bsc "$WORK/Has/Has.bs" Trace '{ "host" = "a" }'
bsc "$WORK/Has/Has.bs" Trace '{ "x-trace" = :nothing }'
