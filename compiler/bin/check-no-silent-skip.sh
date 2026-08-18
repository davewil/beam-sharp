#!/usr/bin/env bash
#
# A TEST MAY NOT REPORT `ok` FOR WORK IT DID NOT DO.
#
# This is the failure `cli_tests.erl` already carries a comment about, three
# lines above a live instance of it. `built_escript_compiles_a_file_test`
# guarded itself with `filelib:is_regular/1` and returned `ok` when the escript
# was absent — and CI ran `rebar3 eunit` BEFORE `rebar3 escriptize`, so the
# artefact was always absent and the test passed without ever executing
# anything. A test written because the documented quickstart was broken had
# itself been green and empty since the day it was written.
#
# That one was fixed. Measured on this tree before the gate was written, the
# same shape was still live at 15 sites across 8 modules — bindings, body_check,
# cli, diagnostic_term, ffi, generics, pipe and visibility — every one of them
# able to go green while running nothing.
#
# THE RULE IS "NOT SILENTLY", NOT "NEVER SKIP", because the repo already has two
# precedents and they disagree about the remedy while agreeing about the fault:
#
#   `cli_tests` REMOVED its guard and throws, on the grounds that the workflow
#   builds the escript first so a missing one is a real failure.
#
#   `repl_tests` KEPT its guard and announces, routing 20 tests through a
#   `built()` helper that prints SKIPPED — "Twelve tests reporting `ok` while
#   running nothing is the precise failure this file was written to end".
#
# Either satisfies this gate. What does not is the third thing: a guard that
# returns `ok` and says nothing, which is indistinguishable from a pass.
#
# The check is anchored on the GUARD EXPRESSION rather than on `false -> ok`,
# because the latter is ordinary Erlang and appears in honest code. A skip is
# recognisable by what it asks about: the presence of a build artefact.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The predicates that mean "is the thing I need actually here?". A guard on one
# of these, whose false branch is a bare `ok`, is a vacuous pass.
PREDICATES='filelib:is_regular|filelib:is_file|filelib:is_dir'

# Scan one directory of Erlang sources. Prints one line per violation.
# Kept as a function so --self-test can point it at a fixture instead of at
# `test/`, and exercise the identical code path rather than a copy of it.
scan() {
  local dir="$1"
  local f
  for f in "$dir"/*.erl; do
    [ -e "$f" ] || continue
    # `false -> ok` is only a skip when the case it belongs to asked about an
    # artefact. awk carries the last `case ... of` seen, so the two lines are
    # judged together rather than one at a time.
    awk -v pred="$PREDICATES" -v file="$f" '
      /case[[:space:]].*[[:space:]]of[[:space:]]*$/ { guard = $0; guardline = NR }
      /^[[:space:]]*false[[:space:]]*->[[:space:]]*ok[[:space:],;.]*$/ {
        if (guard ~ pred && NR - guardline <= 2)
          printf "%s:%d: vacuous pass — guard at line %d asks for an artefact and the false branch is a bare ok\n", file, NR, guardline
      }
    ' "$f"
  done
}

# ---------------------------------------------------------------------------
# --self-test: the gate must be able to go red, and must not go red at random.
#
# A control that only proves the check FIRES is half a control: a gate that
# returns "violation" for every input passes that half and is worthless. So the
# fixture carries both shapes — the silent skip this gate exists to catch, and
# the announced skip `repl_tests` deliberately keeps — and the gate is only
# believed if it separates them.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # POSITIVE CONTROL — the defect. Must be reported.
  cat > "$CTL/silent_tests.erl" <<'ERL'
-module(silent_tests).
a_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true  -> ?assert(true)
    end.
ERL

  # NEGATIVE CONTROL — the announced skip, which is a deliberate convention in
  # this suite. Must NOT be reported, or the gate would force a rewrite of
  # `repl_tests` for doing the right thing.
  cat > "$CTL/announced_tests.erl" <<'ERL'
-module(announced_tests).
built() ->
    case filelib:is_regular(escript()) of
        true  -> true;
        false -> io:format(user, "  SKIPPED~n", []), false
    end.
a_test() ->
    case built() of
        false -> ok;
        true  -> ?assert(true)
    end.
ERL

  out="$(scan "$CTL" || true)"

  fail=0
  if ! grep -q 'silent_tests.erl' <<<"$out"; then
    echo "SELF-TEST FAILED: the gate did not catch the silent skip it exists for"
    fail=1
  fi
  if grep -q 'announced_tests.erl' <<<"$out"; then
    echo "SELF-TEST FAILED: the gate flagged an announced skip, so it cannot tell"
    echo "                  the defect from the convention and would be deleted"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught the silent skip, ignored the announced one — the gate discriminates"
    exit 0
  fi
  echo "$out"
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
violations="$(scan "$HERE/test" || true)"

if [ -n "$violations" ]; then
  echo "$violations"
  n=$(printf '%s\n' "$violations" | wc -l | tr -d ' ')
  echo
  echo "$n vacuous pass(es): a test returns ok when its artefact is missing, and says nothing."
  echo "Route the guard through an announcing helper, or drop the guard and let the"
  echo "missing artefact be the failure it is. See the header of this script."
  exit 1
fi

echo "no vacuous passes: every artefact guard either announces or is absent"
