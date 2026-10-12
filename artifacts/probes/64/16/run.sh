#!/usr/bin/env bash
# Probe 64/16 - the SECOND site where the term collapse bites: an OPTIONAL KEY whose value may be any term
# (F61 fills an absent key as :nothing only at a field spelled option<T>; at T=term that spelling is refused).
# What can a wire type say today for "key may be absent, value may be anything"?
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mkdir -p $W/Wire; cat > $W/Wire/Wire.bs <<'B'
module Wire

using :maps {
    term from_list(list<(string, term)> kvs)
}

// (1) value may be anything, key REQUIRED
type Req = { "id": string, "extra": term, .. }
// (2) hand-rolled tagged optional: key required, value (:some, x) | :nothing
type Tagged = { "id": string, "extra": (:some, term) | :nothing, .. }

public term ReqAbsent(string i)
ReqAbsent(i) -> ValidateAs<Req>(:maps.from_list([("id", i)]))

public term ReqPresent(string i)
ReqPresent(i) -> ValidateAs<Req>(:maps.from_list([("id", i), ("extra", :nothing)]))

public term TaggedAbsent(string i)
TaggedAbsent(i) -> ValidateAs<Tagged>(:maps.from_list([("id", i)]))

public term TaggedWire(string i)
TaggedWire(i) -> ValidateAs<Tagged>(:maps.from_list([("id", i), ("extra", (:some, 7))]))
B
for f in ReqAbsent ReqPresent TaggedAbsent TaggedWire; do printf '  %-14s -> ' $f; "$BSC" -o $W/o $W/Wire $f '"x"' 2>&1 | tail -1 | sed "s|$W/||"; done
echo "(refused spelling, for the record: \"extra\": option<term> -- see probe 03 R4)"
