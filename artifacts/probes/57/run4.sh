#!/usr/bin/env bash
# Ticket 57 P4/P5: does a negative LITERAL argument satisfy a signed refinement? Run against each variant's bsc via $BSC.
set -u
BSC=${BSC:?set BSC}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mk(){ mkdir -p "$W/$1/$1"; cat > "$W/$1/$1/$1.bs"; }
echo "--- P4a: literal -3 passed to Delta (needs the refinement to be writable first)"
mk A <<'B'
module A
type Delta = int where value >= -5 and value <= 5
public Delta Pass(Delta d)
Pass(d) -> d
public Delta Lit()
Lit() -> Pass(-3)
B
(cd $W/A && $BSC A 2>&1 | head -4; echo done)
echo "--- P4b: a computed value -x passed to Delta (must be refused: not provably in range)"
mk B <<'B'
module B
type Delta = int where value >= -5 and value <= 5
public Delta Pass(Delta d)
Pass(d) -> d
public Delta Neg(Delta d)
Neg(d) -> Pass(-d)
B
(cd $W/B && $BSC B 2>&1 | head -4; echo done)
echo "--- P4c: unsigned control, literal 3 to 0..5"
mk C <<'B'
module C
type Small = int where value >= 0 and value <= 5
public Small Pass(Small d)
Pass(d) -> d
public Small Lit()
Lit() -> Pass(3)
B
(cd $W/C && $BSC C 2>&1 | head -4; echo done)
echo "--- P5: 'value == 3' (positive!) — is the 'bad range type' a separate defect?"
mk D <<'B'
module D
type Three = int where value == 3
public Three Id(Three t)
Id(t) -> t
B
(cd $W/D && $BSC D 2>&1 | head -4; echo done)
echo "--- P6: negative literal clause pattern against a signed domain"
mk E <<'B'
module E
type Delta = int where value >= -5 and value <= 5
public atom Dir(Delta d)
Dir(<= -1) -> :down
Dir(0) -> :flat
Dir(>= 1) -> :up
B
(cd $W/E && $BSC E 2>&1 | head -6; echo done)
