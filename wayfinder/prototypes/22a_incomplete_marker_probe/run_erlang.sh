#!/usr/bin/env bash
# Ticket 22, BEAM half. B# compiles TO Erlang, so what Erlang does with a
# spec that has no function is the closest analogue on the target platform.
#
#   A  `-spec` with no matching function — B#'s exact `no_clauses` shape.
#   B  CONTROL: a known error must be reported.
#
# NOTE: run from a scratch dir, never from compiler/. C.beam there shadows
# stdlib's `c` on macOS (memory: bare-erl-dies-inside-the-compiler-directory).
set -uo pipefail
WORK="${TMPDIR:-/tmp}/bs_t22_erl.$$"
mkdir -p "$WORK"
cd "$WORK" || exit 1

banner() { printf '\n########## %s ##########\n' "$1"; }

cat > spec_no_fn.erl <<'EOF'
-module(spec_no_fn).
-export([apply_order/1]).

%% A spec whose function is never written. This is B#'s `no_clauses`
%% translated to the target platform, as literally as it goes.
-spec apply_order(integer()) -> integer().
EOF

cat > control_bad.erl <<'EOF'
-module(control_bad).
-export([oops/0]).
oops() -> undefined_function_xyz().
EOF

banner "A: -spec with no function body (B#'s no_clauses shape)"
erlc spec_no_fn.erl 2>&1 | head -5
echo "EXIT_A=$?"

banner "B: CONTROL — a known error must be reported"
erlc control_bad.erl 2>&1 | head -5
echo "EXIT_B=$?"

cd / || exit 0
rm -rf "$WORK"
