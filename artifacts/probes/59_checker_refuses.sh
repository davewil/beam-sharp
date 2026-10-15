#!/usr/bin/env bash
# 59_checker_refuses.sh -- can B# source itself hand a non-Order (a term, a narrowed term, a union)
# to a private Order parameter? Claim tested: "a forged record can reach a private function by
# being passed through an exported one" via an exported function typed term/union/wire.
# CONFIRMED-as-refuted-path if each bad program below is REFUSED at compile time; the control
# (ValidateAs) must compile. REFUTES the refusal claim if any bad program compiles (exit 0).
set -u
cd "$(dirname "$0")"; . ./env.sh; . ./59_lib.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59ref.XXXXXX")
try() { # name body
  mkdir -p "$T/$1/G"
  printf 'module G\nrecord Order { Id: int, Total: int }\nrecord Invoice { Id: int, Total: int }\ntype Doc = Order | Invoice\nint Priv(Order o)\nPriv(o) -> o.Total\n%s\n' "$2" > "$T/$1/G/g.bs"
  echo "--- $1"; (cd "$T/$1" && "$BSC_HEAD" --src-root . -o "$T/$1/out" G 2>&1; echo "exit=$?") | head -8
}
try term_passed_on      'public int F(term t)
F(t) -> Priv(t)'
try term_narrowed       'public int F(term t)
F(Order o) -> Priv(o)
F(_) -> -1'
try union_passed_on     'public int F(Doc d)
F(d) -> Priv(d)'
try CONTROL_validate    'public int F(term t)
F(t) -> ValidateAs<Order>(t) switch {
    (:error, _) => -1,
    o => Priv(o)
}'
try CONTROL_union_narrowed 'public int F(Doc d)
F(Order o) -> Priv(o)
F(Invoice i) -> 0'
