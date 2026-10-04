#!/bin/bash
# Probe 01 (a): reproduce, with the real bsc, that a private Inner(Order o) gets the record
# TAG test and a private refined-int parameter does NOT get the int KIND test.
# Control: the same parameters on exported functions DO get both.
cd "$(dirname "$0")"; . ./lib.sh
W=$(mktemp -d); mkdir -p $W/Priv $W/out
cat > $W/Priv/priv.bs <<'BS'
module Priv
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

// private, record parameter
int Inner(Order o)
Inner(o) -> o.Total
// private, refined int parameter
int Scale(Octet n)
Scale(n) -> n * 2
// private, plain int
int Plain(int n)
Plain(n) -> n + 1

// exported controls
public int Outer(Order o)
Outer(o) -> Inner(o)
public int OuterInt(Octet n)
OuterInt(n) -> Scale(n)
public int OuterPlain(int n)
OuterPlain(n) -> Plain(n)
BS
bs_build $W/Priv $W/out || exit 1
echo "=== emitted Erlang (from the .beam abstract code) ==="
abstr $W/out/Priv.beam
echo
echo "=== disassembled BEAM: private Inner/1 (record tag test) ==="
asm $W/out/Priv.beam Inner 1
echo
echo "=== disassembled BEAM: private Scale/1 (refined int: expect NO is_integer) ==="
asm $W/out/Priv.beam Scale 1
echo
echo "=== disassembled BEAM: exported OuterInt/1 (expect is_integer + range) ==="
asm $W/out/Priv.beam OuterInt 1
echo
echo "=== counts of guard instructions per function ==="
for f in "Inner 1" "Scale 1" "Plain 1" "Outer 1" "OuterInt 1" "OuterPlain 1"; do
  set -- $f
  printf "%-12s is_integer=%s  get_map_element=%s\n" "$1/$2" \
    "$(asm $W/out/Priv.beam $1 $2 | grep -c is_integer)" "$(asm $W/out/Priv.beam $1 $2 | grep -c 'get_map_element\|bif.*map_get')"
done
