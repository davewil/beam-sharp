#!/usr/bin/env bash
# 03 -- does `-5` in a `when` guard work today, what does it lower to, and does
# it narrow? Against the REPO's bsc.
# REFUTES "a guard reads -5 fine": (a) G3 refused or giving a wrong answer at
# runtime; (b) G1 (a three-clause program that IS exhaustive over int) being
# ACCEPTED would refute "the guard credits nothing for a negative literal".
. "$(dirname "$0")/lib.sh"
v=repo; b=$(bsc_of $v)
probe $v G3 'public atom Band(int n)
Band(n) when n >= -5 -> :a
Band(n) -> :b'
expect "guard with -5 compiles (has a catch-all)" accepted "$verdict"
r1=$("$b" "$OUT/cases/$v/m/G3/a.bs" Band -3 2>&1); r2=$("$b" "$OUT/cases/$v/m/G3/a.bs" Band -9 2>&1); r3=$("$b" "$OUT/cases/$v/m/G3/a.bs" Band -5 2>&1)
expect "runtime Band(-3)" ":a" "$r1"; expect "runtime Band(-9)" ":b" "$r2"; expect "runtime Band(-5)" ":a" "$r3"
echo "# emitted abstract form of the guard (raw):"
sed -n '/function,0,.Band/,$p' "$OUT/cases/$v/m/G3/G3.abstr" | tee "$OUT/G3_guard_abstr_repo.txt"
grep -q "{op,{3,19},'-',{integer,{3,20},5}}" "$OUT/G3_guard_abstr_repo.txt" && got=unary-op-over-5 || got=other
expect "guard lowers -5 to {op,'-',{integer,5}}" unary-op-over-5 $got

echo "# the same literal through a PATTERN (p_rel) lowers to a negative integer:"
probe $v P3 'public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos'
grep -o "{op,{3,6},'=<',{var,{3,6},'Bs@r1'},{integer,{3,6},-1}}" "$OUT/cases/$v/m/P3/P3.abstr"
expect "pattern <= -1 compiles" accepted "$verdict"

echo "# does a guard with a negative literal NARROW? three clauses that are exhaustive:"
probe $v G1 'public atom Band(int n)
Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5 -> :low
Band(n) when n > 5 -> :high'
expect "G1 (exhaustive by arithmetic) accepted" accepted "$verdict"
sed 's/^/    /' "$OUT/cases/$v/G1.out"
probe $v G2 'public atom Band(int n)
Band(n) when n >= 0 and n <= 5 -> :mid
Band(n) when n < 0 -> :low
Band(n) when n > 5 -> :high'
expect "G2 (same shape, no negative literal) accepted" accepted "$verdict"
echo "# the same G1 with the negative bound spelled as patterns is accepted:"
probe $v G1p 'public atom Band(int n)
Band(>= -5 and <= 5) -> :mid
Band(<= -6) -> :low
Band(>= 6) -> :high'
expect "G1 as relational patterns accepted" accepted "$verdict"
echo "# does the refused G1 mislead? it says the residual is <= 5, but the clauses cover -5..5, <-5, >5:"
probe $v G1x 'public atom Band(int n)
Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5 -> :low
Band(n) when n > 5 -> :high
Band(n) -> :never'
expect "adding a catch-all after G1 compiles" accepted "$verdict"
