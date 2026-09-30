#!/usr/bin/env bash
# 57e: LANGUAGE.md section 3's own program. Delete the third clause, read the residual, PASTE what it prints.
# Does the pasted clause close the hole?  (README: "the whole bet of the language")
. "$(dirname "$0")/common.sh"
show () { mkdir -p "$work/$1"; printf 'module %s\n%s\n' "$1" "$2" > "$work/$1/a.bs"
  echo "--- $1"; "$BSC" "$work/$1/a.bs" 2>&1 | sed 's/^/  | /'; echo "  rc=${PIPESTATUS[0]}"; }
HEAD='type Verdict = :positive | :zero | :negative | :unknown
type Reading = (:ok, int) | (:error, atom)

public Verdict Classify(Reading r)
'
show P1_deleted "$HEAD
Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:error, e))         -> :unknown"
show P2_pasted_guard_form "$HEAD
Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n)) when n <= -1 -> :negative
Classify((:error, e))         -> :unknown"
show P3_pattern_form "$HEAD
Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, <= -1))        -> :negative
Classify((:error, e))         -> :unknown"
