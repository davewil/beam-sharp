#!/usr/bin/env bash
#
# compiler/README.md'S REPL TRANSCRIPT IS A PROMISE TO A PERSON, NOT A SAMPLE.
#
# The bindings section is deliberately a session against Shop rather than a
# copied unit-test assertion.  `bsc --repl` is the public command a reader can
# run; its stdin and stdout are consequently the seam this gate measures.
#
# Self-test copies are passed directly to judge.  Ordinary invocation always
# reads the committed document, so an ambient environment cannot choose a
# friendlier transcript.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
README="$HERE/README.md"

[ -x "$BSC" ] || {
  echo "no built bsc at ${BSC#"$REPO"/} — run rebar3 escriptize"
  exit 2
}
[ -f "$README" ] || { echo "no README at $README"; exit 2; }

transcript() {
  awk '
    /^\*\*The prompt holds bindings\*\*/ { wanted = 1; next }
    wanted && /^```$/ { if (!inside) { inside = 1; next }; exit }
    inside { print }
  ' "$1"
}

judge() {
  local doc="$1" source="$2" work missing=0 repl_status
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN

  transcript "$doc" > "$work/transcript"
  if ! grep -q '^bs> ' "$work/transcript"; then
    echo "DRIFTED: no bindings REPL transcript found in ${doc#"$REPO"/}"
    return 1
  fi

  sed -n 's/^bs> //p' "$work/transcript" > "$work/commands"
  awk '!/^bs> / && NF { print }' "$work/transcript" > "$work/expected"
  printf ':quit\n' >> "$work/commands"
  if [ ! -s "$work/expected" ]; then
    echo "DRIFTED: README bindings transcript has no expected output"
    missing=1
  fi

  set +e
  "$BSC" --repl "$source" < "$work/commands" > "$work/output" 2>&1
  repl_status=$?
  set -e
  sed 's/^bs> //' "$work/output" > "$work/visible"

  if [ "$repl_status" -ne 0 ]; then
    echo "DRIFTED: bsc --repl exited $repl_status while replaying README bindings"
    missing=1
  fi

  # Exact lines, in transcript order. Membership alone accepts a reader-facing
  # lie such as the result and `81` swapped; the later indented `:env` value is
  # deliberately not interchangeable with the result line above it.
  if ! awk '
    BEGIN { next_expected = 1 }
    NR == FNR { expected[++count] = $0; next }
    next_expected <= count && $0 == expected[next_expected] { next_expected++ }
    END { exit next_expected > count ? 0 : 1 }
  ' "$work/expected" "$work/visible"; then
    echo "DRIFTED: README expected output is absent or out of order in bsc --repl"
    missing=1
  fi

  if grep -E 'is introduced here|is not bound|crashed:|(^|[^[:alpha:]])error:' "$work/visible" >/dev/null; then
    echo "DRIFTED: README commands produced an error in bsc --repl"
    grep -E 'is introduced here|is not bound|crashed:|(^|[^[:alpha:]])error:' "$work/visible"
    missing=1
  fi

  [ "$missing" -eq 0 ]
}

if [ "${1:-}" = "--self-test" ]; then
  ctl="$(mktemp -d)"
  trap 'rm -rf "$ctl"' EXIT

  run_judge() {
    set +e
    result="$(judge "$1" "$2" 2>&1)"
    result_status=$?
    set -e
  }

  sed -e 's/^bs> var t = 9$/bs> t = 9/' \
      -e 's/^bs> var o = /bs> o = /' \
      -e 's/^bs> var n = /bs> n = /' \
      "$README" > "$ctl/bare-bindings.md"
  run_judge "$ctl/bare-bindings.md" "$HERE/examples/Shop"

  failed=0
  case "$result" in
    *DRIFTED*) ;;
    *) echo "SELF-TEST FAILED: mutating the real README transcript was not reported as DRIFTED"
       failed=1 ;;
  esac
  if [ "$result_status" -eq 0 ]; then
    echo "SELF-TEST FAILED: bare bindings reported DRIFTED but still exited 0"
    failed=1
  else
    echo "  ok red on the original bare bindings transcript"
  fi

  sed '/^n = {Kind = /d; /^81$/d' "$README" > "$ctl/no-expected-output.md"
  run_judge "$ctl/no-expected-output.md" "$HERE/examples/Shop"
  if [ "$result_status" -eq 0 ]; then
    echo "SELF-TEST FAILED: a transcript with no expected output was accepted"
    failed=1
  else
    echo "  ok red on a transcript with no expected output"
  fi

  awk '
    /^n = \{Kind = / { held = $0; next }
    /^81$/ { print; print held; next }
    { print }
  ' "$README" > "$ctl/swapped-output.md"
  run_judge "$ctl/swapped-output.md" "$HERE/examples/Shop"
  if [ "$result_status" -eq 0 ]; then
    echo "SELF-TEST FAILED: a transcript with swapped expected output was accepted"
    failed=1
  else
    echo "  ok red on swapped expected output"
  fi

  run_judge "$README" "$ctl/no-such-module"
  case "$result" in
    *DRIFTED*) ;;
    *) echo "SELF-TEST FAILED: a failed bsc --repl run was not reported as DRIFTED"
       failed=1 ;;
  esac
  if [ "$result_status" -eq 0 ]; then
    echo "SELF-TEST FAILED: a failed bsc --repl run exited 0"
    failed=1
  else
    echo "  ok red when bsc --repl cannot load its source"
  fi

  if ! judge "$README" "$HERE/examples/Shop" >/dev/null 2>&1; then
    echo "SELF-TEST FAILED: the committed README transcript was rejected"
    failed=1
  else
    echo "  ok green on the committed README transcript"
  fi
  [ "$failed" -eq 0 ] || exit 1
  echo "self-test: rejected a drifted README transcript and accepted the committed one"
  exit 0
fi

[ "${1:-}" = "" ] || { echo "usage: check-readme.sh [--self-test]"; exit 2; }

if ! judge "$README" "$HERE/examples/Shop"; then
  exit 1
fi
echo "  ok         README bindings transcript replays in bsc --repl without errors"
