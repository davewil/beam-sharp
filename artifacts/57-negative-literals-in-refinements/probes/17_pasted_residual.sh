#!/usr/bin/env bash
# LANGUAGE.md section 3 promises: delete a clause and the compiler hands back the clause to paste. The printed head is
#   Classify((:ok, n)) when n <= -1 -> ...
# Does PASTING it back (with a body) make the function exhaustive?  Step 1: delete the clause.  Step 2: paste what is printed.
source "$(dirname "$0")/lib.sh"
H='type Verdict = :positive | :zero | :negative | :unknown
type Reading = (:ok, int) | (:error, atom)
public Verdict Classify(Reading r)'
echo "### step 1: clause deleted -> what is printed"
probe Deleted "$H
Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:error, e))         -> :unknown"
echo "### step 2: paste exactly the printed head, add a body"
probe Pasted "$H
Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n)) when n <= -1 -> :negative
Classify((:error, e))         -> :unknown"
echo "### control: the same shape with a POSITIVE literal (residual n >= 1 printed as a guard) pasted back"
probe PastedPos "$H
Classify((:ok, n)) when n < 0 -> :negative
Classify((:ok, 0))            -> :zero
Classify((:ok, n)) when n >= 1 -> :positive
Classify((:error, e))         -> :unknown"
