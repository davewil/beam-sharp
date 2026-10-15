#!/usr/bin/env bash
# 64_collapse_table.sh
# CLAIM (ticket 64 "mechanism"): option<term>, result<term,atom> COLLAPSE to bare `term` and survive as
# a signature (silently), vs ticket text elsewhere / F31 S5,S7 saying they are REFUSED at the declaration.
# Measures at HEAD, for each instantiation, three positions: signature return, record field, type alias.
# Output: per-case bsc exit status + first diagnostic line, + `bsc --api` rendering when accepted.
# REFUTES "refused at the declaration" for a case if it prints ACCEPTED with the collapsed type.
# REFUTES "collapses silently" for a case if it prints REFUSED.
# Controls: option<int>, result<int,binary> (expected ACCEPTED, survive); option<atom> (expected REFUSED).
. "$(dirname "$0")/env.sh"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
cases=(
 "option<term>" "result<term, atom>" "result<int, term>" "result<term, term>" "option<atom>"
 "result<term, binary>" "option<int>" "result<int, binary>" "option<option<int>>"
 "result<(atom, term), binary>" "result<list<term>, term>" "option<list<term>>" "option<map<term, term>>" "option<(atom, term)>" "option<pid>" "option<binary>"
)
i=0
for t in "${cases[@]}"; do
  i=$((i+1))
  for pos in sig field alias; do
    d="$W/M${i}$pos"; mkdir -p "$d"
    case $pos in
      sig)   body="public $t Find(map<string, term> m, string k)
Find(m, k) -> :nothing" ;;
      field) body="record Box { V: $t }" ;;
      alias) body="type A = $t" ;;
    esac
    # sig bodies are not meant to typecheck for result; use foreign-free declaration-only form
    if [ $pos = sig ]; then body="public $t Find(int k)
Find(k) -> k"; fi
    printf 'module M%s%s\n\n%s\n' "$i" "$pos" "$body" > "$d/m.bs"
    out=$($BSC --api "$d" 2>&1); rc=$?
    first=$(echo "$out" | head -2 | sed "s#$W/##g" | tr "\n" "|")
    if [ $rc -eq 0 ]; then v=ACCEPTED; else v=REFUSED; fi
    printf '%-24s %-6s %-9s rc=%d  %s\n' "$t" "$pos" "$v" "$rc" "$first"
  done
done
