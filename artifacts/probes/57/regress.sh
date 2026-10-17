#!/usr/bin/env bash
# regress.sh VARIANT  — run the repo's own eunit suite (compiler/test) against a variant's
# ebin, from a scratch dir, and print pass/fail counts. The suite was written for OTP 28 and
# some tests drive the escript or need OTP 26+, so BASE has failures; the number that
# matters is the DELTA from base (same tests, same OTP), listed by diff.
set -uo pipefail
root=$(cd "$(dirname "$0")/../../.." && pwd)
WORK=${WORK:-/tmp/p57work}; v=$1
t=$WORK/$v/tests; rm -rf "$t"; mkdir -p "$t"
cp "$root"/compiler/test/*.erl "$t/"
( cd "$t" && erlc -o . *.erl 2>/dev/null )
cd "$t" && modules=$(ls *.beam | sed 's/\.beam//' | grep -v bs_test_support | grep '_tests$' | tr '\n' ',' | sed 's/,$//')
timeout 900 erl -noshell -pa "$WORK/$v/ebin" -pa "$t" -eval "
  Ms = [list_to_atom(M) || M <- string:tokens(\"$modules\", \",\")],
  R = [{M, (catch eunit:test(M, []))} || M <- Ms],
  [io:format(\"~s ~p~n\", [atom_to_list(M), X]) || {M, X} <- R],
  halt()." > "$WORK/$v/regress.txt" 2>&1
# per-test failure names (stable across variants), and eunit's own totals
grep -E '\*failed\*|\*timed out\*' "$WORK/$v/regress.txt" | sed 's/\.\.\..*//' | sort -u > "$WORK/$v/failing.txt"
echo "$v: $(wc -l < "$WORK/$v/failing.txt") failing tests; eunit totals: $(grep -hE 'Failed: [0-9]+|tests passed' "$WORK/$v/regress.txt" | awk '/Failed/{f+=$2; p+=$6} /passed/{p+=$2} END{print "failed=" f+0 " passed=" p+0}')"
