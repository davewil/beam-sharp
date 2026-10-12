#!/usr/bin/env bash
# 57-02 what is the TYPE of the expression `-5`? type_of(e_int) gives 5..5, type_of(e_neg) gives int.
# NonPos (value <= 0) is spellable today, so it can witness whether `-5` inhabits it.
root=$(cd "$(dirname "$0")/../../.." && pwd)
bsc="$root/compiler/_build/default/bin/bsc"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
# bsc writes <Module>.beam/.abstr into the CWD, so always run it from the scratch dir.
probe () { local n=$1 src=$2; mkdir -p "$work/$n"; printf 'module %s\n%s\n' "$n" "$src" > "$work/$n/a.bs"
  out=$(cd "$work" && "$bsc" "$work/$n/a.bs" 2>&1); if [ -z "$out" ]; then echo "$n: accepted"; else echo "$n: refused"; echo "$out" | head -${3:-3} | sed "s#$work/##;s/^/    /"; fi; }
probe RetZero 'type NonPos = int where value <= 0
public NonPos F()
F() -> 0'
probe RetNegLit 'type NonPos = int where value <= 0
public NonPos F()
F() -> -5' 6
probe RetNegViaParam 'type NonPos = int where value <= 0
public NonPos F(NonPos n)
F(n) -> n'
echo "== is there any other surface for a signed domain? (type-expression literals/ranges) =="
probe TyLitUnion 'type S = -1 | 0 | 1'
probe TyRange 'type S = -5..5'
