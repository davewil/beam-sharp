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
#
# THE REPOSITORY README'S HEADLINE IS THE SAME KIND OF PROMISE, AND THE FIRST
# ONE A READER MEETS: a program, then what the compiler says about it.  Its
# first fence is compiled through `bsc` at the path its second fence names, and
# the two must agree byte for byte.  The transcript drifted once already — the
# column arrived on 2026-09-05 and the README went on printing `demo.bs:5:` —
# and nothing read it (ENG-264).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
README="$HERE/README.md"
# The repository README, whose opening program and transcript are the headline.
HEADLINE="$REPO/README.md"

[ -x "$BSC" ] || {
  echo "no built bsc at ${BSC#"$REPO"/} — run rebar3 escriptize"
  exit 2
}
[ -f "$README" ] || { echo "no compiler README at $README"; exit 2; }
[ -f "$HEADLINE" ] || { echo "no repository README at $HEADLINE"; exit 2; }

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

# The Nth BARE fence of a document, without its fence lines. A tagged fence
# (```sh) is walked past and not counted, so one added above the headline does
# not put the count out of phase with the blocks.
fence() {
  awk -v want="$2" '
    /^```/ {
      if (inside) { inside = 0; if (bare && n == want) exit; next }
      inside = 1; bare = ($0 == "```"); if (bare) n++
      next
    }
    inside && bare && n == want { print }
  ' "$1"
}

# A subshell, so its cleanup is its own: `judge`'s RETURN trap outlives the
# call that set it and would fire again here over a `work` that is not ours.
judge_headline() (
  doc="$1"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT

  fence "$doc" 1 > "$work/program"
  fence "$doc" 2 > "$work/expected"
  if ! grep -q '^module ' "$work/program"; then
    echo "DRIFTED: the first fence of ${doc#"$REPO"/} is not a program"
    return 1
  fi

  # The transcript says where the file is, so that is where it is put: the
  # position prefix is part of what the reader is shown.
  path="$(sed -n '1s/^\([A-Za-z0-9_][A-Za-z0-9_/]*\.bs\):[0-9].*$/\1/p' "$work/expected")"
  module="$(dirname "$path")"
  if [ -z "$path" ] || [ "$module" = "." ]; then
    echo "DRIFTED: the second fence of ${doc#"$REPO"/} does not open with Module/file.bs:LINE"
    return 1
  fi

  mkdir -p "$work/src/$module"
  cp "$work/program" "$work/src/$path"
  # A refused program exits 1, which is what the headline shows; the output is
  # the measurement, and a crash or a usage message differs from it.
  (cd "$work/src" && "$BSC" --src-root . "$module" > "$work/actual" 2>&1) || true

  if ! cmp -s "$work/expected" "$work/actual"; then
    echo "DRIFTED: ${doc#"$REPO"/} shows one transcript for its headline program and bsc prints another"
    diff "$work/expected" "$work/actual" | sed 's/^/    /' || true
    return 1
  fi
)

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

  # expect_headline_red WHY FILE LABEL: FILE must differ from the committed
  # README, and must be refused for the reason WHY names. A control that goes
  # red for some other reason proves nothing about the check it was built for.
  expect_headline_red() {
    local why="$1" doc="$2" label="$3" out status
    if cmp -s "$HEADLINE" "$doc"; then
      echo "SELF-TEST FAILED: the control for $label changed nothing in the committed README"
      failed=1
      return
    fi
    set +e
    out="$(judge_headline "$doc" 2>&1)"
    status=$?
    set -e
    if [ "$status" -eq 0 ]; then
      echo "SELF-TEST FAILED: $label was accepted"
      failed=1
    elif ! printf '%s\n' "$out" | grep '^DRIFTED: ' | grep -qF "$why"; then
      echo "SELF-TEST FAILED: $label was refused, but not for \"$why\":"
      printf '%s\n' "$out" | sed 's/^/    /'
      failed=1
    else
      echo "  ok red on $label"
    fi
  }
  differs='shows one transcript for its headline program and bsc prints another'

  # The drift this gate was written for, as it stood in the README until
  # 2026-10-08: no module directory and no column.
  sed 's/^[A-Za-z0-9_/]*\(demo\.bs:[0-9]*\):[0-9]*: error:/\1: error:/' "$HEADLINE" > "$ctl/old-position.md"
  expect_headline_red "does not open with Module/file.bs:LINE" \
    "$ctl/old-position.md" "the headline position as it had drifted, \`demo.bs:5:\`"

  # The column alone, which leaves a path to compile at and so reaches the
  # comparison.
  sed 's/^\([A-Za-z0-9_/]*\.bs:[0-9]*\):[0-9]*: error:/\1: error:/' "$HEADLINE" > "$ctl/no-column.md"
  expect_headline_red "$differs" "$ctl/no-column.md" "a headline transcript without its column"

  # One character of the residual, so the comparison is of the whole transcript.
  sed 's/^    Classify(<= 199) -> \.\.\.$/    Classify(<= 198) -> .../' "$HEADLINE" > "$ctl/residual.md"
  expect_headline_red "$differs" "$ctl/residual.md" "a headline transcript with a perturbed residual"

  # The program moved and the transcript left standing.
  sed 's/^Classify(>= 500)  /Classify(>= 600)  /' "$HEADLINE" > "$ctl/program.md"
  expect_headline_red "$differs" "$ctl/program.md" "a headline program its transcript no longer describes"

  sed '/^```$/d' "$HEADLINE" > "$ctl/no-fences.md"
  expect_headline_red "is not a program" "$ctl/no-fences.md" "a README with no headline fences"

  # A tagged fence above the headline must not be counted as the program.
  { printf '```sh\necho not the program\n```\n\n'; cat "$HEADLINE"; } > "$ctl/tagged-above.md"
  if ! judge_headline "$ctl/tagged-above.md" >/dev/null 2>&1; then
    echo "SELF-TEST FAILED: a tagged fence above the headline put the bare fences out of phase"
    failed=1
  else
    echo "  ok green with a tagged fence above the headline"
  fi

  if ! judge_headline "$HEADLINE" >/dev/null 2>&1; then
    echo "SELF-TEST FAILED: the committed README headline was rejected"
    failed=1
  else
    echo "  ok green on the committed README headline"
  fi

  [ "$failed" -eq 0 ] || exit 1
  echo "self-test: rejected a drifted REPL transcript and a drifted headline, and accepted the committed READMEs"
  exit 0
fi

[ "${1:-}" = "" ] || { echo "usage: check-readme.sh [--self-test]"; exit 2; }

if ! judge "$README" "$HERE/examples/Shop"; then
  exit 1
fi
echo "  ok         README bindings transcript replays in bsc --repl without errors"

if ! judge_headline "$HEADLINE"; then
  exit 1
fi
echo "  ok         README headline program prints its transcript, byte for byte"
