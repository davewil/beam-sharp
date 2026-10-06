#!/usr/bin/env bash
# 07 -- ticket 57's "residual doctrine" claim: "`subtract(-10..10, 0)` is
# `-10..-1 | 1..10` -- a residual the compiler prints and the surface cannot
# accept", so the doctrine (the residual IS the missing case) is capped.
# Test: take each clause the compiler PRINTS as missing, paste it into the
# program with a body, recompile. REFUTES the ticket's claim: every pasted
# residual compiles. (It would be CONFIRMED by a pasted head failing to parse.)
# Base compiler for the bare-int signed cases (no refinement needed); the
# signed-bounded-domain cases need a fix, so they run under g1 AND c1.
. "$(dirname "$0")/lib.sh"
PB_TOTAL=0; PB_OK=0
paste_back () { # variant name header-and-prefix-clauses  (clauses in $3 are the program body)
    local v=$1 name=$2 head=$3 body=$4 heads n=0 extra=""
    probe $v "$name" "$head
$body"
    if [ "$verdict" = accepted ]; then echo "SKIP     $v/$name already compiles"; return; fi
    heads=$(grep -E '^ {4}[A-Za-z]+\(.*\) -> \.\.\.$' "$OUT/cases/$v/$name.out" | sed 's/^ *//; s/-> \.\.\.$/-> :pasted/')
    printf '%s printed missing clauses:\n%s\n' "$v/$name" "$(echo "$heads" | sed 's/^/        /')"
    [ -z "$heads" ] && { echo "INVALID  no clause lines parsed from the diagnostic"; return; }
    probe $v "${name}_p" "$head
$body
$heads"
    expect "$v/$name: pasting the printed clauses compiles" accepted "$verdict"
    PB_TOTAL=$((PB_TOTAL+1)); [ "$verdict" = accepted ] && PB_OK=$((PB_OK+1))
}
D='type Dd = int where value >= -10 and value <= 10
public atom Sign(Dd d)'
paste_back g1 R1 "$D" 'Sign(0) -> :zero'
paste_back c1 R1 "$D" 'Sign(0) -> :zero'
paste_back g1 R2 "$D" 'Sign(<= -1) -> :neg
Sign(>= 1 and <= 9) -> :pos'
paste_back base R3 'public atom F(int d)' 'F(>= -10 and <= 10) -> :in'
paste_back base R4 'public atom F(int d)' 'F(<= -1) -> :neg'
echo "# the doctrine's OTHER direction: the printed residual of a guard-narrowed signed domain (guards cannot say -5 in base)"
paste_back base R5 'public atom Band(int n)' 'Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5 -> :low
Band(n) when n > 5 -> :high'
echo "# is the printed TYPE (not clause) writable? in every variant the printed type uses interval notation:"
probe g1 T1 'type Delta = int where value >= -100 and value <= 100
type Pos = int where value >= 1
int Take(Pos p)
Take(p) -> p
public int F(Delta d)
F(d) -> Take(d)'
sed -n 2,4p "$OUT/cases/g1/T1.out"
probe base T2 'type Octet = int where value >= 0 and value <= 255
type Pos = int where value >= 1
int Take(Pos p)
Take(p) -> p
public int F(Octet d)
F(d) -> Take(d)'
sed -n 2,4p "$OUT/cases/base/T2.out"
probe base T3 'type Octet = int where value >= 0 and value <= 255
type Big = int where value >= 100 and value <= 200
int Take(Big p)
Take(p) -> p
public int F(Octet d)
F(d) -> Take(d)'
sed -n 2,4p "$OUT/cases/base/T3.out"
echo "# ^ base prints '0..99 | 201..255'-style TYPES for a NON-negative domain too; the interval notation was never surface syntax in any sign."

echo "# the ticket's claim, stated as the ticket states it (a printed residual the surface cannot accept):"
[ "$PB_OK" = "$PB_TOTAL" ] && obs=accepted || obs=refused
expect "ticket 57: printed residual clauses are NOT acceptable ($PB_OK of $PB_TOTAL pasted ok)" refused $obs
