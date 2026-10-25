#!/usr/bin/env bash
# Ticket 57. Once `-5` is accepted, is the set RIGHT? Call a function over `int where value >= -5 and value <= 5`
# with in-range and out-of-range literals, and print the residual of dropping a clause.
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); mkdir -p "$W/M"
run() { printf 'module M\n\n%s\n' "$2" > "$W/M/m.bs"; out=$(bsc -o "$W/out" "$W/M" "${@:3}" 2>&1); rc=$?; printf '== %s: rc=%s\n%s\n' "$1" $rc "$(echo "$out" | head -8 | sed "s|$W/M/m.bs:||")"; }
D='type Delta = int where value >= -5 and value <= 5

public int Abs(Delta d)

Abs(>= 0) -> d0()
'
run 'in range  (-5)' 'type Delta = int where value >= -5 and value <= 5

public int Id(Delta d)

Id(d) -> d' Id -5
run 'in range  (5)'  "$(cat <<'X'
type Delta = int where value >= -5 and value <= 5

public int Id(Delta d)

Id(d) -> d
X
)" Id 5
run 'out of range (-6) — expect a refusal or a guard error' "$(cat <<'X'
type Delta = int where value >= -5 and value <= 5

public int Id(Delta d)

Id(d) -> d
X
)" Id -6
run 'residual: drop the negative clause' "$(cat <<'X'
type Delta = int where value >= -5 and value <= 5

public atom Sign(Delta d)

Sign(0)    -> :zero
Sign(> 0)  -> :pos
X
)"
