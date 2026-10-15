#!/usr/bin/env bash
# 64_tagged_shapes.sh
# CLAIM: tagged success shapes survive at T = term in every position bsc checks, nest, and close the generic-
#   instantiation hole (R2 in 64_silent_routes.sh) -- with three live spellings in the repo: the F31 hint's
#   (:some, T) | :nothing, ticket 48 Q8's (:ok, T) | :absent, and OTP's (:ok, T) | :error.
# REFUTED if any case below prints REFUSED, or if G1 (tagged generic at T=term) answers 0 for Use(:nothing)
#   (that would be the collapse reappearing), or if N1 shows the nested type printed as the single-level one.
. "$(dirname "$0")/env.sh"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
run() { local d="$W/$1"; mkdir -p "$d"; cat > "$d/m.bs"; echo "== $1: $2"; $BSC -o "$W/out" --api "$d" 2>&1 | sed "s#$W/##g" | head -${3:-5}; }
run S1 "F31 hint spelling (:some, term) | :nothing" <<'E'
module S1

public (:some, term) | :nothing Find(int k)
Find(k) -> :nothing
E
run S2 "ticket 48 spelling (:ok, term) | :absent" <<'E'
module S2

public (:ok, term) | :absent Find(int k)
Find(k) -> :absent
E
run S3 "OTP spelling (:ok, term) | :error" <<'E'
module S3

public (:ok, term) | :error Find(int k)
Find(k) -> :error
E
run N1 "nesting: Found<Found<int>> stays two levels (a map of maps)" <<'E'
module N1

type Found<T> = (:ok, T) | :absent

public Found<Found<int>> Deep(int k)
Deep(k) -> (:ok, :absent)
E
run G1 "generic Found<T> Wrap<T>(T x) at T=term" 6 <<'E'
module G1

type Found<T> = (:ok, T) | :absent

public Found<T> Wrap<T>(T x)
Wrap(x) -> (:ok, x)

public int Use(term t)
Use(t) -> Wrap(t) switch { :absent => 0, (:ok, v) => 1 }
E
echo "G1 runtime (tagged generic: a present :nothing must NOT read as absent -> expect 1):"
mkdir -p "$W/out"; $BSC -o "$W/out" "$W/G1" Use :absent 2>&1 | tail -1
echo "R2 control (untagged generic, silent collapse -> 0):"; echo "   see 64_silent_routes.sh R2 runtime"
