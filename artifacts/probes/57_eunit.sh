#!/usr/bin/env bash
# 57_eunit -- claim: neither prototype breaks an existing test (no shipped program relied on `-N` being an
# e_neg node or typing as `int`). REFUTED by: a patched build's failed-test list containing a name stock's lacks.
# CONTROL: stock itself fails 4 tests in this sandbox (environmental: UTF-8 locale / aoc / batch); the
# comparison is of FAILED NAMES, not of "all green". Takes ~4 min per build; builds run in parallel.
# usage: V57=<dir> 57_eunit.sh        (V57 must contain stock gramA gramB chk with examples/ and bin/ copied in)
. "$(dirname "$0")/env.sh"; : "${V57:?}"
[ -n "${SUMMARIZE_ONLY:-}" ] || for v in stock gramA gramB chk; do
  mkdir -p "$V57/$v"; [ -d "$V57/$v/examples" ] || cp -r "$REPO/compiler/examples" "$REPO/compiler/bin" "$V57/$v/"
  (cd "$V57/$v" && rebar3 eunit > "$V57/$v.eunit.log" 2>&1) &
done; wait   # SUMMARIZE_ONLY=1 skips the run and reads the existing $V57/*.eunit.log
for v in stock gramA gramB chk; do echo "== $v"; grep -E "Failed: |Passed: |\*failed\*" "$V57/$v.eunit.log" | sed 's/\.\.\.\[.*//; s/\.\.\.\*failed\*/ FAILED/'; done
