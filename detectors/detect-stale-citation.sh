#!/usr/bin/env bash
#
# A DOCUMENT CITING A SOURCE LINE THAT MOVED.
#
# `9f4590c` (2026-08-29): "All eighteen of F29's source-line references had
# drifted, and several were wrong rather than merely stale: `subject` sits in
# `valve_on_infallible`, not the switch descriptor; `rejected` names two
# different diagnostics; the function called `pasteable/2` is `pasteable/3`."
# The fix there was to replace them with diagnostic tags and function names,
# "which do not drift" — and the commit measured, and deliberately did not touch,
# 22 more in eight other feature files.
#
# `cd61280` is the same class in the shipping document: three TOUR.md transcripts
# named `wire.bs:40` and `wire.bs:48` for lines the compiler reports at 42 and
# 50. "The prose sites were wrong by two and the term site by three, so they were
# captured at three separate times and none was re-read."
#
# Nothing has ever checked one. `check-links.sh` asks whether a cited PATH
# exists; the line number after the colon is not read by anything.
#
# WHAT THIS CAN AND CANNOT SEE, said plainly because the gap matters. A citation
# is checkable when the file has since SHRUNK past the line — `F16` cites
# `bsc.erl:1374` and that file is 932 lines — and not checkable when the line
# merely moved within a file that is still long enough. So this is a floor, not
# the whole class: it catches the drift that has gone furthest, and 9f4590c's
# remedy (cite a function or a tag, not a line) remains the actual fix.
#
# AMBIGUITY IS A SKIP, NOT A GUESS, and that is the false-positive control. The
# first draft resolved a bare `README.md:770` against the repo-root README and
# reported five stale citations in `reports/`, where every one meant
# `compiler/features/README.md` or the audition's README. Five tracked files are
# called `README.md`. A citation this detector cannot resolve to exactly one file
# is not a finding.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Every `path.ext:N` or `path.ext:N-M` inside a code span.
CITE_RE='`[A-Za-z0-9_][A-Za-z0-9_./-]*\.(erl|xrl|yrl|sh|py|md|yml|json|bs)\:[0-9]+(-[0-9]+)?`'

# Resolve a cited path against a tracked-file list. Prints the one file it names,
# or nothing when it names none or more than one. `tracked` is a parameter so
# --self-test drives this function over a fixture list.
resolve_cite() {
  local p="$1" from="$2" tracked="$3" d cands n
  # An anchored path (one that exists as written, from the citing file's
  # directory or any ancestor) wins outright.
  d="$(dirname "$from")"
  while :; do
    if [ -n "$d" ] && grep -qxF "${d#./}/$p" "$tracked" 2>/dev/null; then
      printf '%s\n' "${d#./}/$p"; return 0
    fi
    # NOT `[ a ] || [ b ] || [ c ] && break`. That is one compound command whose
    # status is the status of the test, so on the first iteration — where none of
    # the three holds — it returns 1, and `set -e` kills the function silently.
    # The self-test caught it as "the out-of-range citation was not reported",
    # which is the same symptom a broken regex would give. It is also exactly the
    # `A && B || C` shape `check-shell.sh` was written for, met while writing a
    # detector for a neighbouring class.
    if [ "$d" = "." ] || [ "$d" = "/" ] || [ -z "$d" ]; then
      break
    fi
    d="$(dirname "$d")"
  done
  # AMBIGUITY IS CHECKED BEFORE ANYTHING ELSE, INCLUDING BEFORE AN EXACT MATCH
  # AT THE REPO ROOT. `README.md:770` in reports/ means the audition README or
  # compiler/features/README.md; five tracked files carry that basename and one
  # of them happens to sit at the root, so a resolver that takes the exact match
  # first answers confidently and wrongly - which it did, five times, on this
  # detector's first real run.
  cands="$(grep -E "(^|/)$(printf '%s' "$p" | sed 's/[.[\*^$]/\\&/g')\$" "$tracked" || true)"
  n="$(printf '%s' "$cands" | grep -c . || true)"
  if [ "$n" != "1" ]; then
    return 0
  fi
  printf '%s\n' "$cands"
  return 0
}

# Report every citation in FILE whose target resolves and whose line is past the
# end of it.
# BASE is the directory the tracked paths are relative to. A parameter, so the
# self-test drives this exact function over a fixture tree rather than a copy of
# its logic - the reason every other gate here takes its inputs the same way.
stale_cites_in() {
  local f="$1" tracked="$2" base="${3:-$ROOT}" cite p nums end tgt total ln
  grep -noE "$CITE_RE" "$f" 2>/dev/null | while IFS= read -r hit; do
    ln="${hit%%:*}"
    cite="$(printf '%s' "$hit" | sed -E 's/^[0-9]+://; s/`//g')"
    p="${cite%%:*}"; nums="${cite#*:}"; end="${nums##*-}"
    tgt="$(resolve_cite "$p" "$f" "$tracked")"
    # `[ -z "$tgt" ] && continue` here aborted the whole function under `set -e`
    # when the call sat inside a command substitution inside another test, which
    # is exactly how --self-test calls it: the real run printed findings and the
    # self-test reported none, from one line written two ways.
    if [ -z "$tgt" ]; then
      continue
    fi
    if [ ! -f "$base/$tgt" ]; then
      continue
    fi
    total="$(wc -l < "$base/$tgt" | tr -d ' ')"
    if [ "$end" -gt "$total" ]; then
        printf '%s:%s: cites `%s`, and %s has %s lines\n' "${f#"$base"/}" "$ln" "$cite" "$tgt" "$total"
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/src" "$CTL/docs" "$CTL/a" "$CTL/b"
  seq 1 10 > "$CTL/src/short.erl"
  seq 1 10 > "$CTL/a/README.md"
  seq 1 10 > "$CTL/b/README.md"
  printf 'src/short.erl\na/README.md\nb/README.md\n' > "$CTL/tracked"

  printf 'see `src/short.erl:99` for the rule\n'  > "$CTL/docs/past.md"
  printf 'see `src/short.erl:4` for the rule\n'   > "$CTL/docs/inrange.md"
  printf 'see `README.md:900` for the rule\n'     > "$CTL/docs/ambiguous.md"
  printf 'see `stdlib-7.3/src/gen_server.erl:88`\n' > "$CTL/docs/external.md"

  fail=0
  red() { [ -z "$(stale_cites_in "$CTL/docs/$1" "$CTL/tracked" "$CTL")" ] && { echo "SELF-TEST FAILED: $1 — $2"; fail=1; }; return 0; }
  green() {
    local out; out="$(stale_cites_in "$CTL/docs/$1" "$CTL/tracked" "$CTL")"
    [ -n "$out" ] && { echo "SELF-TEST FAILED: $1 — $2"; printf '  reported: %s\n' "$out"; fail=1; }
    return 0
  }

  red past.md "a citation past the end of the file it names was not reported"
  green inrange.md "a citation inside the file was reported"
  green ambiguous.md \
    "an AMBIGUOUS basename was resolved and reported. Five tracked files are called
                  README.md; guessing one of them produced five false findings in reports/
                  on this detector's first run"
  green external.md \
    "a citation of another project's source tree was reported. wayfinder/research
                  is a citation index of upstream repositories and none of those paths are
                  here — reporting them is 40 findings and no defects"

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the out-of-range citation; stayed silent on an in-range one,"
    echo "           an ambiguous basename and an external path — the detector discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-stale-citation.sh [--self-test]"; exit 2; }

cd "$ROOT"
TRACKED="$(mktemp)"
trap 'rm -f "$TRACKED"' EXIT
"${GIT:-git}" ls-files > "$TRACKED"

scanned=0
findings=""
while IFS= read -r f; do
  case "$f" in
    wayfinder/research/*) continue ;;   # an index of other projects' files, by design
    _build/*|editor/node_modules/*) continue ;;
  esac
  scanned=$((scanned + 1))
  out="$(stale_cites_in "$ROOT/$f" "$TRACKED")"
  [ -n "$out" ] && findings+="$out"$'\n'
done < <(grep -E '\.md$' "$TRACKED")

if [ "$scanned" -eq 0 ]; then
  echo "no documents scanned — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "A line number in a document is re-staled by every edit above it, and nothing"
  echo "re-reads it. 9f4590c's remedy is the one that holds: cite a function name or"
  echo "a diagnostic tag, which do not drift."
  exit 1
fi

echo "$scanned documents cite no source line past the end of the file it names"
