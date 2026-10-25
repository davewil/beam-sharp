#!/usr/bin/env bash
# Ticket 57. A literal `-5` as an EXPRESSION: is it typed as the literal, or as `int`?
# Control: `5` returned where `int where value >= 1` is declared is accepted, so literals do narrow.
# Test: `-5` returned where `int where value <= -1` is declared. Needs a fix that makes the type declarable.
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); mkdir -p "$W/M"
run() { printf 'module M\n\n%s\n' "$2" > "$W/M/m.bs"; out=$(bsc -o "$W/out" "$W/M" 2>&1); printf '== %s: rc=%s\n%s\n' "$1" $? "$(echo "$out" | head -4 | sed "s|$W/M/m.bs:||")"; }
run 'control: 5 as >=1' 'type Pos = int where value >= 1

public Pos Five(int n)

Five(n) -> 5'
run 'test: -5 as <= -1' 'type Neg = int where value <= -1

public Neg MinusFive(int n)

MinusFive(n) -> -5'
run 'test: -(5) as <= -1' 'type Neg = int where value <= -1

public Neg MinusFive(int n)

MinusFive(n) -> -(5)'
run 'test: 0 - 5 as <= -1' 'type Neg = int where value <= -1

public Neg MinusFive(int n)

MinusFive(n) -> 0 - 5'
