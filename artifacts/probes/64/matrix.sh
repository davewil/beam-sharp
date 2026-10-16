#!/usr/bin/env bash
# 64 / matrix — which spellings of "a lookup that can report absent" survive at value type term?
#   matrix.sh PATH_TO_BSC
set -uo pipefail
BSC=${1:?bsc}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
row() {   # name, source (a whole module body)
  mkdir -p "$W/$1"; printf 'module %s\n%s\n' "$1" "$2" > "$W/$1/a.bs"
  out=$("$BSC" -o "$W/$1/out" "$W/$1/a.bs" 2>&1); rc=$?
  if [ $rc -eq 0 ] && ! echo "$out" | grep -q "error"; then
     api=$("$BSC" --api "$W/$1" 2>&1 | grep -m1 'Find' | cut -c1-90); printf '%-16s accepted   api: %s\n' "$1" "$api"
  else printf '%-16s REFUSED    %s\n' "$1" "$(echo "$out" | grep -m1 -o 'error: .*' | cut -c1-95)"; fi
}
row OptTerm   $'public option<term> FindA(map<string, term> m, string k)\nFindA(m, k) -> :nothing'
row OptInt    $'public option<int> FindB(map<string, int> m, string k)\nFindB(m, k) -> :nothing'
row ResTermA  $'public result<term, atom> FindC(map<string, term> m, string k)\nFindC(m, k) -> (:error, :missing)'
row ResIntTerm $'public result<int, term> FindD(map<string, int> m, string k)\nFindD(m, k) -> (:error, :missing)'
row ResTermTerm $'public result<term, term> FindE(map<string, term> m, string k)\nFindE(m, k) -> (:error, :missing)'
row Handrolled $'public (:ok, term) | :absent FindF(map<string, term> m, string k)\nFindF(m, k) -> :absent'
row BareUnion $'type Lookup = term | :nothing\npublic Lookup FindG(map<string, term> m, string k)\nFindG(m, k) -> :nothing'
row ParamAlias $'type Found<T> = (:found, T) | :absent\npublic Found<term> FindH(map<string, term> m, string k)\nFindH(m, k) -> :absent'
row AtomNothing $'type Maybe = atom | :nothing\npublic Maybe FindI(string k)\nFindI(k) -> :nothing'
row NestedOpt $'public option<option<int>> FindJ(map<string, int> m, string k)\nFindJ(m, k) -> :nothing'
row NestedFound $'type Found<T> = (:found, T) | :absent\npublic Found<Found<int>> FindK(string k)\nFindK(k) -> :absent'
