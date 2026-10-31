#!/usr/bin/env bash
# Probe 02: how erlc / Elixir 1.14 / dialyzer report an unreachable clause and
# a clause outside the declared input. Command: bash 02_unreachable_precedent.sh
# Asserts on OBSERVED output: each tool's exit code and presence/absence of a
# warning line is captured, and the final PASS/FAIL lines are derived from it.
cd "$(dirname "$0")" || exit 2
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
fail=0
chk() { # name, observed, wanted
  if [ "$2" = "$3" ]; then echo "PASS  $1 (observed=$2)"; else echo "FAIL  $1 (observed=$2 wanted=$3)"; fail=1; fi; }

echo "== erlc shadowed clause =="
out=$(erlc -o "$W" 02_src/shadow.erl 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "erlc shadowed: exit 0"          "$rc" 0
chk "erlc shadowed: warning emitted"  "$(echo "$out" | grep -c 'cannot match because a previous clause')" 1
echo "== erlc +warnings_as_errors shadowed =="
out=$(erlc +warnings_as_errors -o "$W" 02_src/shadow.erl 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "erlc opt-in strict: exit nonzero" "$([ $rc -ne 0 ] && echo nonzero || echo zero)" nonzero

echo "== erlc clause outside the -spec (exemplar 5 shape) =="
out=$(erlc -o "$W" 02_src/vacuous.erl 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "erlc vacuous-vs-spec: exit 0"   "$rc" 0
chk "erlc vacuous-vs-spec: NO warning (compiler does not read -spec)" "$(echo "$out" | grep -ci 'warning')" 0

echo "== dialyzer clause outside the -spec =="
if [ -f /tmp/p66.plt ]; then
  erlc +debug_info -o "$W" 02_src/vacuous.erl
  out=$(dialyzer --plt /tmp/p66.plt "$W/vacuous.beam" 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
  chk "dialyzer default flags: SILENT on a clause outside the spec (claim under test)" "$(echo "$out" | grep -ci 'warning\|never\|can not\|cannot')/$rc" "0/0"
  out=$(dialyzer -Wunderspecs --plt /tmp/p66.plt "$W/vacuous.beam" 2>&1); rc=$?; echo "-- with -Wunderspecs --"; echo "$out"; echo "rc=$rc"
  echo "(informational: whatever -Wunderspecs said is recorded above; it is about the SPEC being narrower than the code, not a vacuous clause)"
else
  echo "SKIP dialyzer: /tmp/p66.plt not built (run: dialyzer --build_plt --output_plt /tmp/p66.plt --apps erts kernel stdlib)"
fi

echo "== Elixir 1.14.0 shadowed clause =="
mkdir -p "$W/e1"; out=$(cd "$W/e1" && elixirc "$OLDPWD/02_src/shadow.ex" 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "elixirc shadowed: exit 0"       "$rc" 0
chk "elixirc shadowed: warning"      "$(echo "$out" | grep -c 'this clause cannot match')" 1
echo "== Elixir 1.14.0 shadowed, --warnings-as-errors =="
mkdir -p "$W/e2"; out=$(cd "$W/e2" && elixirc --warnings-as-errors "$OLDPWD/02_src/shadow.ex" 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "elixirc strict: exit nonzero"   "$([ $rc -ne 0 ] && echo nonzero || echo zero)" nonzero
echo "== Elixir 1.14.0 clause outside @spec =="
mkdir -p "$W/e3"; out=$(cd "$W/e3" && elixirc "$OLDPWD/02_src/vacuous.ex" 2>&1); rc=$?; echo "$out"; echo "rc=$rc"
chk "elixirc vacuous-vs-spec: exit 0, no warning" "$rc/$(echo "$out" | grep -ci warning)" "0/0"
exit $fail
