#!/usr/bin/env bash
# literal-consistency.sh — is `-1` treated like `1` wherever a literal is typed? Runs the SAME
# program with K=1 and K=-1 under each variant and prints both verdicts. A mismatch is the
# ticket-57 family's second symptom: type_of({e_neg,..}) returns `int`, not the literal (bs_check.erl:2889).
# Options A1/A2 leave it (checker folds only inside comparison/2); option B closes it.
set -uo pipefail
WORK=${WORK:-/tmp/p57work}; w=$(mktemp -d); trap 'rm -rf "$w"' EXIT; cd "$w"
verdict() { mkdir -p "$1"; printf 'module %s\n%s\n' "$1" "$2" > "$1/a.bs"; o=$("$3" "$1/a.bs" 2>&1 </dev/null); [ $? -eq 0 ] && [ -z "$o" ] && echo ok || echo REFUSED; }
progs=(
'type Nz = int where value != 0
public int Id(Nz b)
public int Go()
Id(b) -> b
Go() -> Id(@K@)'
'type P = int where value >= -9 and value <= 9
public P F()
F() -> @K@'
'public int Take((int, atom) t)
public int Go()
Take(t) -> 0
Go() -> Take((@K@, :a))'
'type Small = int where value >= -9 and value <= 9
public int Take(list<Small> xs)
public int Go()
Take(xs) -> 0
Go() -> Take([@K@, 2])'
)
printf '%-34s %-8s %-8s\n' program K=1 K=-1
i=0
for v in base optA1 optA2 optB; do
  echo "== $v"
  i=0
  for p in "${progs[@]}"; do
    i=$((i+1))
    a=$(verdict "P${v}${i}p" "${p//@K@/1}" "$WORK/$v/bsc"); b=$(verdict "P${v}${i}n" "${p//@K@/-1}" "$WORK/$v/bsc")
    # the refinements in programs 2 and 4 need the NEGATIVE bound, so on base they are refused for both K
    mark=""; [ "$a" != "$b" ] && mark="   <-- -1 differs from 1"
    printf '  prog %d (%s)  %-8s %-8s%s\n' $i "$(echo "$p" | sed -n 's/^public \([^(]*\)(.*/\1/p;' | head -1 | tr -d '\n')" "$a" "$b" "$mark"
  done
done
