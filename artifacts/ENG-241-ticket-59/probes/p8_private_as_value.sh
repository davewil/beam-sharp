#!/usr/bin/env bash
# H8: a private function reachable as a fun value is callable with anything by foreign code, so a
#     test on the private function is the only test between the foreign argument and the body.
#     A: Total/1 (tag test) refuses a forged map; Big/1 (no kind test) answers 1 for 100.5 and 300.
#     B: Big/1 gains the kind test and refuses. C: Total/1 loses the tag test and answers 5.
# Falsifier: any observed value differs from the expectation printed beside it.
# Command: ./p8_private_as_value.sh
S=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad
cd "$(dirname "$0")/bs" || exit 2
rc=0
for v in "" B C; do
  O=$(mktemp -d); "$S/bsc$v/_build/default/bin/bsc" -o "$O" --src-root . P59 >/dev/null || exit 2
  echo "== variant ${v:-A}"
  erl -noshell -pa "$O" -eval '
    T = '"'"'P59'"'"':'"'"'TotalFn'"'"'(), B = '"'"'P59'"'"':'"'"'BigFn'"'"'(),
    R = fun(F, X) -> case catch F(X) of {'"'"'EXIT'"'"', {Why, _}} -> Why; V -> V end end,
    io:format("  Total(forged map)  -> ~p~n  Big(100.5)         -> ~p~n  Big(300)           -> ~p~n",
       [R(T, #{'"'"'Kind'"'"' => '"'"'Other.Thing'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 5}), R(B, 100.5), R(B, 300)]), halt().'
done
cat <<'X'
EXPECTED  A: function_clause / 1 / 1   B: function_clause / function_clause / function_clause   C: 5 / 1 / 1
X
