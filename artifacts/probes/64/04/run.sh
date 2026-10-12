#!/usr/bin/env bash
# Probe 64/04 - what an author can ALREADY write today: a user-declared parametric tagged alias.
# Claim under test: ticket 64 says refusal "leaves the author with nothing to reach for".
# Does a hand-rolled Maybe<T> = (:some, T) | :nothing work at term, nest, and stay exhaustive?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mkdir -p $W/Maybe; cat > $W/Maybe/Maybe.bs <<'B'
module Maybe

type Maybe<T> = (:some, T) | :nothing

// A generic lookup over an assoc list, returning the tagged alias at ANY T including term.
public Maybe<V> Get<V>(list<(atom, V)> xs, atom k)
Get([], k)                        -> :nothing
Get([(kk, v), ..rest], k) when kk == k -> (:some, v)
Get([(kk, v), ..rest], k)         -> Get(rest, k)

// Caller at T = term: can distinguish absent from "present and holds :nothing".
public atom Describe(list<(atom, term)> xs, atom k)
Describe(xs, k) -> Get(xs, k) switch {
    :nothing    => :absent,
    (:some, :nothing) => :present_and_is_nothing,
    (:some, v)  => :present
}

// Nesting survives (untagged option<option<int>> is refused by F31).
public Maybe<Maybe<int>> Nested(int n)
Nested(0) -> :nothing
Nested(1) -> (:some, :nothing)
Nested(n) -> (:some, (:some, n))

B
echo "=== api ==="; "$BSC" --api $W/Maybe 2>&1
echo; echo "=== compile ==="; "$BSC" -o $W/o $W/Maybe 2>&1 | sed "s|$W/||"
mkdir -p $W/Part; { printf 'module Part\n\ntype Maybe<T> = (:some, T) | :nothing\n\npublic Maybe<V> Get<V>(list<(atom, V)> xs, atom k)\nGet(xs, k) -> :nothing\n\n'; sed 's/^\/\/.*//' <<'B2'
// Non-exhaustive on purpose: the checker should still see the missing arm at T = term.
public atom Partial(list<(atom, term)> xs, atom k)
Partial(xs, k) -> Get(xs, k) switch {
    (:some, v) => :present
}
B2
} > $W/Part/Part.bs
echo; echo "=== non-exhaustive switch at T = term must still be refused ==="; "$BSC" -o $W/o3 $W/Part 2>&1 | sed "s|$W/||"
echo; echo "=== runs ==="
run(){ printf '  %-40s -> ' "$*"; "$BSC" -o $W/o2 $W/Maybe "$@" 2>&1 | tail -1 | sed "s|$W/||"; }
run Describe '[(:a, 1)]' :b
run Describe '[(:a, 1)]' :a
run Describe '[(:a, :nothing)]' :a
run Nested 0
run Nested 1
run Nested 2
