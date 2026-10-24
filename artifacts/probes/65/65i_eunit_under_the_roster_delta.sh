#!/usr/bin/env bash
# PROBE 65i — does the compiler's own eunit suite pass with the eleven-name roster reserved?
# 65c compared example programs; this runs the repo's tests (`rebar3 eunit`) in two scratch copies of
# compiler/ — one pristine, one with reserved_qualifiers/0 extended exactly as 65c does — and compares the
# counts. Scratch copies only; the repo is untouched. Slow (minutes). The tests that drive `bsc` need the
# escript built first (compiler/README), which this does.
#
#   source env.sh; bash artifacts/probes/65/65i_eunit_under_the_roster_delta.sh
set -uo pipefail
: "${S:?source env.sh first}"
REPO="$(git rev-parse --show-toplevel)"
ROSTER="'String', 'Enum', 'Int', 'Binary', 'Process', 'GenServer', 'Supervisor', 'Logger', 'System', 'Task', 'Agent'"
mk() { # name patched?
  local d="$S/compiler-65i-$1"; rm -rf "$d"; cp -r "$REPO/compiler" "$d"; rm -rf "$d/_build"
  if [ "$2" = yes ]; then
    grep -qF "reserved_qualifiers() -> ['List', 'Map', 'Term', 'Float']." "$d/src/bs_check.erl" || { echo "baseline line not found"; exit 2; }
    sed -i "s|reserved_qualifiers() -> \['List', 'Map', 'Term', 'Float'\].|reserved_qualifiers() -> ['List', 'Map', 'Term', 'Float', $ROSTER].|" "$d/src/bs_check.erl"
  fi
  echo "$d"
}
run() { # dir
  ( cd "$1" && rebar3 escriptize >/dev/null 2>&1 && rebar3 eunit 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$1/eunit.log"; grep -E 'Failed: |Passed: ' "$1/eunit.log" | tail -1 )
}
A="$(mk pristine no)"; B="$(mk patched yes)"
( run "$A" > "$A/summary.txt" ) & ( run "$B" > "$B/summary.txt" ) & wait
for d in "$A" "$B"; do
  echo "== $(basename "$d")"; sed 's/^/   /' "$d/summary.txt"
  echo "   the failing test(s), full eunit log:"
  grep -B3 -A6 -E '\*failed\*' "$d/eunit.log" | head -24 | sed 's/^/      /'
done
echo "== failure lines present only in the patched run (empty = the delta breaks no test)"
diff <(grep -E '\*failed\*' "$A/eunit.log" | sort) <(grep -E '\*failed\*' "$B/eunit.log" | sort) | grep '^>' | head
