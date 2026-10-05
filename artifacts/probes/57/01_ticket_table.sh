#!/usr/bin/env bash
# 01 -- reproduce ticket 57's refusal table row by row against the REPO's built
# bsc, then test "the refused form is what the diagnostic recommends".
#
# Each row states the ticket's claim as EXPECTED. A row that does not match is
# printed REFUTED. REFUTES the table: any row whose observed verdict differs.
# REFUTES "the diagnostic recommends the refused form": the message NOT
# naming "comparisons on `value`", or the message's own example failing to
# compile, or `value >= -5` being accepted.
. "$(dirname "$0")/lib.sh"
v=repo
mk () { printf 'type T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
echo "# bsc: $REPO_BSC"
row () { probe $v "$1" "$(mk "$2")"; expect "table: $2" "$3" "$verdict"; }
row R1 'value >= -5'                     refused
row R2 'value >= -5 and value <= 5'      refused
row R3 'value >= 1 or value <= -1'       refused
row R4 'value <= 3 or value >= 10'       accepted
row R5 'value != 0'                      accepted

# "genuinely excludes 0": calling the refined function with 0 must be refused,
# with 1 accepted. REFUTED if a call with 0 is accepted.
probe $v R5a 'type Nz = int where value != 0
int G(Nz b)
G(b) -> b
public int F()
F() -> G(0)'
expect "!= 0 excludes a literal 0 at a call" refused "$verdict"
probe $v R5b 'type Nz = int where value != 0
int G(Nz b)
G(b) -> b
public int F()
F() -> G(1)'
expect "!= 0 admits a literal 1 at a call" accepted "$verdict"

echo "# --- is the refused form what the diagnostic recommends? ---"
probe $v D1 "$(mk 'value >= -5')"
grep -q 'comparisons on `value`' "$OUT/cases/$v/D1.out" && has=yes || has=no
expect "message names 'comparisons on \`value\`'" yes $has
grep -q 'value >= 0 and value <= 255' "$OUT/cases/$v/D1.out" && ex=yes || ex=no
expect "message's own example is printed" yes $ex
probe $v D2 "$(mk 'value >= 0 and value <= 255')"
expect "message's own example compiles" accepted "$verdict"
# the message must not tell the reader a negative literal is the problem
grep -qi 'negative\|minus\|literal' "$OUT/cases/$v/D1.out" && hint=yes || hint=no
expect "message mentions negative/minus/literal at all" no $hint
echo "# --- is there ANY spelling of a signed bound today? (all expected refused) ---"
for pred in 'value > -6' 'value >= 0 - 5' '0 - 5 <= value' 'value + 5 >= 0' '-5 <= value' 'value >= - 5' 'value >= -(5)' 'value >= --5'; do
    probe $v W "$(mk "$pred")"; expect "workaround: $pred" refused "$verdict"
done
echo "# --- the ticket's table is of the repo's bsc; the 38b probe shipped with the ticket: ---"
(cd "$WORK" && bash "$REPO/wayfinder/prototypes/38b_divisor_expressiveness.sh") > "$OUT/38b_shipped_probe.txt" 2>&1; tail -3 "$OUT/38b_shipped_probe.txt"
