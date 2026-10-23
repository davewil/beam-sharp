#!/usr/bin/env bash
# PROBE 62f — does a delegating alias keep the boundary guard (F3 record tag test), and where does the blame land?
# Forged value: a map with the wrong Kind. CONTROL: the real export refuses it (function_clause in 'Squared').
# Claim under test: alias in `deleg` mode adds NO second copy of the guard (crash is attributed to 'Squared');
# in `dup` mode the guard is duplicated (crash attributed to squared). PROTOTYPE DELTA as in 62d.
set -uo pipefail
: "${ALIASBSC:?}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
for m in deleg dup; do
  mkdir -p "$W/$m"; BS_ALIAS=$m "$ALIASBSC" --src-root "$REPO/compiler/examples" -o "$W/$m" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
  echo "== mode=$m"
  erl -noshell -pa "$W/$m" -eval '
    Forged = #{'"'"'Kind'"'"' => '"'"'MyApp.Order'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 0},
    T = fun(Label, F) -> R = try F() of V -> {ok, V} catch error:E:St -> {error, E, element(2, hd(St))} end,
            io:format("  ~-28s ~p~n", [Label, case R of {error, E2, Fn, _} -> {error, E2, Fn}; O -> O end]) end,
    T("real  Squared(forged)", fun() -> '"'"'Shop'"'"':'"'"'Squared'"'"'(Forged) end),
    T("alias squared(forged)", fun() -> '"'"'Shop'"'"':squared(Forged) end),
    T("alias squared(valid)",  fun() -> '"'"'Shop'"'"':squared('"'"'Shop'"'"':'"'"'New'"'"'(3)) end),
    halt().'
done
