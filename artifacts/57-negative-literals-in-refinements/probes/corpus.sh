#!/usr/bin/env bash
# Usage: corpus.sh [EBIN]   (default: the unpatched reference compiler build)
# Runs every case through the compiler in EBIN; prints "name  accepted|refused  first-diagnostic-line".
# Negative controls are the cases whose expected column says REFUSED: a patch that accepts them is wrong.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
EBIN=${1:-$S/bsc-ebin}
source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
n=0
c () { # name expect src
  local name=$1 expect=$2 src=$3 out got
  mkdir -p "$W/$name" "$W/out/$name"; printf 'module %s\n%s\n' "$name" "$src" > "$W/$name/a.bs"
  out=$(cd "$W/out/$name" && erl -noshell -pa "$EBIN" -run bsc main "$W/$name/a.bs" -run init stop 2>&1)
  # a harness that cannot run must not read as "refused": bsc prints nothing on success, so a VM error is caught here
  case "$out" in *"is not exported"*|*"Error!"*|*"is the module directory"*|*"undef"*) echo "HARNESS BROKEN: $out"; exit 2;; esac
  if [ -z "$out" ]; then got=accepted; else got=refused; fi
  local mark=ok; [ "$got" = "$expect" ] || mark='!!'
  printf '%s %-22s %-8s (want %-8s) %s\n' "$mark" "$name" "$got" "$expect" "$(echo "$out" | head -1 | sed "s#$W/[^ ]*/a.bs#a.bs#" | cut -c1-90)"
}
r () { # name expect refinement-expr
  c "$1" "$2" "type T = int where $3
public int Id(T b)
Id(b) -> b"
}
echo "# ticket's five rows"
r R1_ge_neg5          accepted 'value >= -5'
r R2_neg5_and_5       accepted 'value >= -5 and value <= 5'
r R3_1_or_neg1        accepted 'value >= 1 or value <= -1'
r R4_le3_or_ge10      accepted 'value <= 3 or value >= 10'
r R5_ne0              accepted 'value != 0'
echo "# controls the ticket omits"
r C1_gt_neg1          accepted 'value > -1'
r C2_ge_paren5        accepted 'value >= -(5)'
r C3_ge_0minus5       accepted 'value >= 0 - 5'
r C4_neg5_le_value    accepted '-5 <= value'
r C5_ge_neg0          accepted 'value >= -0'
r C6_eq_neg5          accepted 'value == -5'
r C7_ne_neg5          accepted 'value != -5'
r C8_neg_neg5         accepted 'value >= -(-5)'
r C9_space            accepted 'value >= - 5'
r C10_hex             accepted 'value >= 0xFF'
r C11_neg_hex         accepted 'value >= -0xFF'
r C12_big             accepted 'value >= -99999999999999999999999'
r C13_2plus3          accepted 'value >= 2 + 3'
r C14_pos_paren       accepted 'value >= (5)'
echo "# emission shapes once negatives are writable (singleton and negative-only ranges)"
r E1_eq_pos5          accepted 'value == 5'
r E2_neg_only_range   accepted 'value >= -10 and value <= -3'
r E3_le_neg1          accepted 'value <= -1'
r E4_eq_0             accepted 'value == 0'
echo "# negative controls: must stay REFUSED under any fold"
r N1_value_ge_value   refused  'value >= value'
r N2_ge_x_plus_1      refused  'value >= x + 1'
r N3_ge_n             refused  'value >= n'
r N4_ge_call          refused  'value >= F(1)'
r N5_float            refused  'value >= 1.5'
echo "# float"
c F1_float_neg refused 'type T = float where value >= -1.5
public float Id(T b)
Id(b) -> b'
echo "# patterns"
c P1_rel_neg accepted 'public atom Sign(int n)
Sign(>= 0) -> :nonneg
Sign(<= -1) -> :neg'
c P2_lit_neg accepted 'public atom Z(int n)
Z(-5) -> :a
Z(_) -> :b'
c P3_rel_paren refused 'public atom Sign(int n)
Sign(>= 0) -> :nonneg
Sign(<= -(1)) -> :neg'
echo "# guards"
c G1_guard_neg accepted 'public atom Sign(int n)
Sign(n) when n <= -1 -> :neg
Sign(n) when n >= 0 -> :nonneg'
c G2_guard_neg_exhaust accepted 'public atom Sign(int n)
Sign(n) when n < 0 -> :neg
Sign(n) when n >= 0 -> :nonneg'
