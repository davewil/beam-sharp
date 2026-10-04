#!/bin/bash
# Probe 06 (premise of 18 s4 / F24 s2 / F37.5): "a private function's every call site is a checked
# B# call site, so site 1 has already refused the out-of-domain argument". Does bsc actually
# refuse a wrong-kind / out-of-range / wrong-record argument at a call to a private function?
# Each case is a separate one-module program compiled with the real (current) bsc.
cd "$(dirname "$0")"; . ./lib.sh
try() { # label, source
  W=$(mktemp -d); mkdir -p $W/T $W/o; printf '%s\n' "$2" > $W/T/t.bs
  printf '%-58s ' "$1"; OUT=$("$BSC" -o $W/o $W/T 2>&1); rc=$?
  if [ $rc -eq 0 ]; then echo "ACCEPTED"; else echo "REFUSED: $(echo "$OUT" | grep -m1 -i 'error\|expected\|not' | cut -c1-110)"; fi; }
HDR='module T
record Order { Id: int, Total: int }
record Invoice { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255
int Scale(Octet n)
Scale(n) -> n * 2
int Inner(Order o)
Inner(o) -> o.Total
atom Tag(atom a)
Tag(a) -> a
'
try "private Scale(Octet) called with literal 300"            "$HDR
public int A(int x)
A(x) -> Scale(300)"
try "private Scale(Octet) called with a plain int variable"   "$HDR
public int A(int x)
A(x) -> Scale(x)"
try "private Scale(Octet) called with a float literal"        "$HDR
public int A(int x)
A(x) -> Scale(1.5)"
try "private Scale(Octet) called with an atom"                "$HDR
public int A(int x)
A(x) -> Scale(:foo)"
try "private Inner(Order) called with an Invoice"              "$HDR
public int A(Invoice i)
A(i) -> Inner(i)"
try "private Inner(Order) called with an int"                  "$HDR
public int A(int x)
A(x) -> Inner(x)"
try "control: private Scale(Octet) called with a valid literal" "$HDR
public int A(int x)
A(x) -> Scale(200)"
echo
echo "--- can a B# program obtain an unproven value of a declared type at all? (term -> typed) ---"
try "term parameter passed where Order is declared"            "$HDR
public int A(term t)
A(t) -> Inner(t)"
try "projected field of a record (declared int, but forged at runtime) -> Scale(Octet)" "$HDR
record Cart { Qty: int }
public int A(Cart c)
A(c) -> Scale(c.Qty)"
