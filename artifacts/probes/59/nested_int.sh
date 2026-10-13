#!/usr/bin/env bash
# Ticket 59 P2b: the same nested-forgery hole for the INT guard. BSC=<bsc> nested_int.sh
set -u
BSC=${BSC:?}; W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/N59"
cat > "$W/N59/n59.bs" <<'B'
module N59
type Byte = int where value >= 0 and value <= 255
record Gauge { Level: Byte }
public int Read(Gauge g)
Read(g) -> Next(g.Level)
public int Inline(Gauge g)
Inline(g) -> g.Level + 1

private int Next(Byte b)
Next(b) -> b + 1
B
cd "$W" && "$BSC" N59 2>&1 | head -3; D=$(find "$W" -name 'N59.beam' -printf '%h\n' | head -1)
erl -noshell -pa "$D" -eval '
 T = fun(L) -> R = (catch '"'"'N59'"'"':'"'"'Read'"'"'(#{'"'"'Kind'"'"' => '"'"'N59.Gauge'"'"', '"'"'Level'"'"' => L})),
              io:format("Read(Level=~p) -> ~P~n", [L, case R of {'"'"'EXIT'"'"', {E, _}} -> {raised, E}; V -> V end, 8]) end,
 T(7), T(999), T(1.5), T(not_a_number),
 I = fun(L) -> R = (catch '"'"'N59'"'"':'"'"'Inline'"'"'(#{'"'"'Kind'"'"' => '"'"'N59.Gauge'"'"', '"'"'Level'"'"' => L})), io:format("Inline(Level=~p) -> ~P~n", [L, case R of {'"'"'EXIT'"'"', {E, _}} -> {raised, E}; V -> V end, 8]) end,
 I(999), halt().' 2>&1
