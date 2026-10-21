#!/bin/sh
# 64 / probe 3 — which declarations collapse, which survive, and what does the author see?
# Runs the built bsc (`bsc --api`) over one-line declarations. BSC=path to the escript.
set -u
BSC=${BSC:?set BSC}; W=${PROBE_TMP:-$(mktemp -d)}
row() { # name return-type [extra-decl]
  mkdir -p "$W/$1"
  { printf 'module %s\n\n' "$1"; [ -n "${3:-}" ] && printf '%s\n\n' "$3"
    printf 'public %s Go(int id)\nGo(id) -> :nothing\n' "$2"; } > "$W/$1/$1.bs"
  out=$("$BSC" --api "$W/$1/$1.bs" 2>&1)
  case "$out" in "module "*) shown=$(printf '%s' "$out" | sed -n 2p) ;; *) shown=$(printf '%s' "$out" | head -${LINES_PER:-1}) ;; esac   # accepted -> the --api signature line
  printf '%-5s %-34s -> %s\n' "$1" "$2" "$(printf '%s' "$shown" | cut -c1-150)"
}
echo '## T=term (success position)'
row A1 'option<term>'
row A2 'result<term, binary>'
row A3 'result<term, term>'
echo '## E=term only (failure position) — ticket 64 Q3'
row B1 'result<int, term>'
row B2 'result<binary, term>'
echo '## a concrete container of term'
row C1 'option<list<term>>'
row C2 'option<map<string, term>>'
row C3 'result<map<string, term>, binary>'
row C4 'option<(atom, term)>'
echo '## the spellings that DO survive at term'
row D1 'F' 'type F = (:ok, term) | :absent'
row D2 'F' 'type F = (:found, term) | :nothing'
row D3 'Found<term>' 'type Found<T> = (:found, T) | :absent'
echo '## full text the author sees for option<term>'
LINES_PER=30 row Z1 'option<term>' | cut -c1-200
