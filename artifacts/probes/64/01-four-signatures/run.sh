#!/usr/bin/env bash
# Probe 01 -- ticket 64's four lookup signatures, re-measured at HEAD with --api and a plain compile.
# Ticket claim: FindR/FindT "COLLAPSED" to bare term (measured 2026-08-25, before F31 made it an error).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
mk() { mkdir -p "$W/$1"; cat > "$W/$1/$1.bs"; }
mk FindF <<'B'
module FindF
public (:ok, term) | :absent FindF(map<string, term> m, string k)
FindF(m, k) -> :absent
B
mk FindI <<'B'
module FindI
public option<int> FindI(map<string, int> m, string k)
FindI(m, k) -> :nothing
B
mk FindR <<'B'
module FindR
public result<term, atom> FindR(map<string, term> m, string k)
FindR(m, k) -> (:error, :absent)
B
mk FindT <<'B'
module FindT
public option<term> FindT(map<string, term> m, string k)
FindT(m, k) -> :nothing
B
for n in FindF FindI FindR FindT; do
  echo "=== $n: bsc --api ==="; "$BSC" --api "$W/$n" 2>&1
  echo "=== $n: bsc (compile) exit/ output ==="; "$BSC" "$W/$n" 2>&1; echo "exit=$?"
done
