#!/usr/bin/env bash
# Probe 02 -- ticket 64 Q3: does result<T, E> collapse at E = term?  (never measured before)
# Method: for each (T, E) write `public result<T,E> F(result<T,E> x)  F(x) -> x`, compile, report
# accept/refuse and the first diagnostic line, then print --api for the accepted ones.
# Nothing here is hard-coded: the verdict column is the compiler's exit status.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
i=0
printf '%-22s %-10s %-8s %s\n' T E verdict "first line / --api"
while read -r T E; do
  [ -z "$T" ] && continue
  i=$((i+1)); M="M$i"; mkdir -p "$W/$M"
  printf 'module %s\npublic result<%s, %s> F(result<%s, %s> x)\nF(x) -> x\n' "$M" "$T" "$E" "$T" "$E" > "$W/$M/$M.bs"
  out="$("$BSC" "$W/$M" 2>&1 </dev/null)"; rc=$?
  if [ $rc -eq 0 ]; then v=accept; d="$("$BSC" --api "$W/$M" 2>&1 </dev/null | sed -n 2p)"; else v=REFUSE; d="$(printf '%s' "$out" | head -1 | sed "s#$W/##")"; fi
  printf '%-22s %-10s %-8s %s\n' "$T" "$E" "$v" "$d"
done <<'T'
int term
int atom
int binary
atom term
atom atom
term atom
term term
term int
(atom,binary) binary
(atom,term) binary
(:error,int) binary
(:error,term) binary
list<term> term
map<atom,term> term
T
