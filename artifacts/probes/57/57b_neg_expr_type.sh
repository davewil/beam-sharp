#!/usr/bin/env bash
# 57b: NEW findings, not in the ticket. The ticket's mechanism ("-5 desugars to 0 - 5") is STALE:
# since F51 (2026-09-16) the parser emits {e_neg,L,E}; a negated FLOAT literal folds in the parser
# (negate/2), an INT literal does not. Consequences at two further sites:
#  (1) the checker types the expression `-3` as plain `int`, not the singleton -3..-3, so passing
#      the literal -3 where a bounded int is expected is refused although 2 is accepted;
#  (2) a negative literal on the left of a bare `=` is refused as "not a literal pattern".
# Controls: PosLitArg (2, same boundary) must be accepted; PosBare (literal 1) must reach a DIFFERENT
# diagnostic ("this bind can fail", i.e. the left side was accepted) -- so the refusals are about the sign.
# Run from repo root with env.sh sourced.
set -u
. "$(dirname "$0")/lib.sh"
probe PosLitArg accepted 'type T = int where value <= 3
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(2)'
probe NegLitArg refused 'type T = int where value <= 3
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(-3)'
echo "-- NegLitArg's full diagnostic (note: it names the upper half, not the sign):"
$BSC --src-root "$WORK/src" -o "$WORK/oo" "$WORK/src/NegLitArg" 2>&1 | sed "s#$WORK/src/##" | head -6
probe NegBare refused 'public int F((int, int) p)
F(p) ->
    (_, -1) = p
    0'
probe PosBare refused 'public int F((int, int) p)
F(p) ->
    (_, 1) = p
    0'
echo "-- first line of each (the two refusals must differ):"
for n in NegBare PosBare; do $BSC --src-root "$WORK/src" -o "$WORK/oo" "$WORK/src/$n" 2>&1 | head -1 | sed "s#$WORK/src/##;s/^/   $n: /" | cut -c1-150; done
echo "fails=$fails"
