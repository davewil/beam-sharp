#!/usr/bin/env bash
#
# A COUNT OF THE GATE SUITE, WRITTEN INTO PROSE NOTHING RECOUNTS.
#                                                     <!-- suite-count: exempt -->
# (That marker is this file quoting its own findings below. A document about this
#  class has to be able to name the numbers; excluding this file by NAME instead
#  would hide the leak rather than close it.)
#
# This is the most-repeated self-inflicted defect in the last hundred commits.
# Every one of these is a separate incident, and every one was found by a person
# reading rather than by any of the forty-odd gates:
#
#   80eb902  `.claude/end-session.md`'s gate count read TWENTY-FOUR and was wrong
#            by one for most of a day. "check-gates-wired.sh cannot see that: it
#            checks every gate is NAMED on each surface, and the name was there."
#   619b4b9  the same count went stale again inside one session — "a fifth
#            surface no gate reads" — and the commit that fixed it had to say
#            "counted rather than incremented, because incrementing is how the
#            number was wrong by one for most of 2026-08-27".
#   910ed93  F28's Status line and its README row both said "36 verify stages".
#            The verdict there is the rule this detector enforces: "The number
#            was true at landing and has been false since the next gate was
#            wired; THE TEST COUNT IS DATED BY THE STATUS IT SITS IN, BUT A STAGE
#            COUNT IS RE-STALED BY EVERY GATE ADDED. Deleted rather than updated."
#   6eee4e9  "the number is gone in favour of the dates, which do not stale."
#   c7c99be  "Replaced with a phrase rather than a corrected number, which would
#            only start the same drift again."
#
# The 2026-09-01 review filed the survivors as `ENG-290`, and they are still
# here: `stage.sh` and the audition README both say "stage 12 of 34" against a
# suite that has 41 stages today.
#
# ---------------------------------------------------------------------------
# WHY THIS IS THE STAGE COUNT AND NOT THE GATE COUNT.
#
# The first draft of this detector read every count of gates OR stages in every
# comment and every markdown file, and reported 48 lines of which 2 were the
# class. Most of the 44 were narrative — "two gates did not run and nothing said
# so", "editor/bin held TWO gates the workflow had never mentioned" — where the
# number is a fact about a dated incident and not a claim about the suite today.
# The rest were F-file `**Status**` lines: "492 tests, nineteen gate scripts".
#
# Measuring that told me the repository had already drawn a line I had not seen,
# and it draws it between the two words rather than around both:
#
#   A GATE COUNT IS CORRECTED. `80eb902` and `619b4b9` both recounted and fixed
#   the number in `.claude/end-session.md`, and `check-gates-wired.sh` keeps the
#   NAMES honest on four surfaces beside it. A dated `**Status**` line fixes its
#   count in time the same way it fixes its test count.
#
#   A STAGE COUNT IS DELETED. `910ed93`, in as many words: "The number was true
#   at landing and has been false since the next gate was wired; the test count
#   is dated by the Status it sits in, BUT A STAGE COUNT IS RE-STALED BY EVERY
#   GATE ADDED. Deleted rather than updated."
#
# The asymmetry is real rather than arbitrary. A gate count is a count of files
# a reader can list; a stage count is a property of one script whose stage list
# nobody reads, and `stage 12 of 34` in particular tells a reader how far through
# a suite a failure sat — which is exactly the fact that stops being true.
#
# So this detector owns the half with no owner. The gate count has
# `check-gates-wired.sh` and the dated-Status convention; the stage count has had
# nothing, which is why `ENG-290` is still open against `stage.sh`.
#
# WHY A DISAGREEING NUMBER IS NOT THE TEST, AND ANY NUMBER IS.
#
# The obvious detector recounts and reports a mismatch. That detector is green on
# the day a number is written and red later, which means the fix a session
# reaches for is to correct it — and a corrected number is the same defect with a
# fresh date on it. Four separate commits above reached the opposite conclusion
# independently, and none of them corrected the number: they deleted it, or
# replaced it with a date or a phrase.
#
# So the rule is the decided one. A count of VERIFY STAGES does not belong in
# prose at all. It is not a matter of taste: unlike a test count, which a dated
# `**Status**` line legitimately fixes in time, a stage count carries no way for
# a reader to know which suite it counted, and it is re-staled by the next gate
# anybody writes — including by this file's own arrival.
#
# CODE IS NOT PROSE, and the split is the whole of the false-positive control.
# `bin/verify.sh` asserts `All 2 stages passed` about a two-stage FIXTURE inside
# its own self-test, and `check-shell.sh` prints `$scanned gate scripts` from a
# variable it just counted. Both are counts that cannot go stale, because both
# are computed. Only comments and markdown prose are read here.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The surfaces a reader trusts. `reports/` and `wayfinder/` are deliberately out:
# a report states its own measurement date in its first line and says it will go
# stale, and `wayfinder/` is the design record, where what a document got wrong
# at the time is part of what the record is for.
SCAN_ROOTS=(".github/workflows" "bin" "compiler/bin" "compiler/features" "editor/bin"
            "handoff" "detectors" "README.md" "CLAUDE.md" "LANGUAGE.md" "TOUR.md"
            "PRELUDE.md" "CONTEXT.md" ".claude/end-session.md")

NUMWORD='one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|twenty-one|twenty-two|twenty-three|twenty-four|twenty-five|twenty-six|twenty-seven|twenty-eight|twenty-nine|thirty-one|thirty-two|thirty-three|thirty-four|thirty-five|thirty-six|thirty-seven|thirty-eight|thirty-nine|forty-one|forty-two'

# THE THREE SHAPES A VERIFY-SUITE SIZE IS WRITTEN IN, and nothing wider. A
# "three-stage chain of ordinary calls" (F14.2) and "`!` fails one stage earlier,
# in the lexer" (F27) are stages of something else entirely and must not fire, so
# the word `stage` alone is never enough: the match needs `verify`, or the
# `N of M` shape that only a suite position has, or an explicit `stages passed`.
COUNT_RE="(^|[^A-Za-z0-9_-])([0-9]{1,3}|${NUMWORD}|$(printf '%s' "$NUMWORD" | tr '[:lower:]' '[:upper:]'))[ -](verify stages?|stages? of the (verify )?suite)([^A-Za-z]|$)"
OFM_RE="(stages? [0-9]{1,3} of [0-9]{1,3}|[0-9]{1,3} of [0-9]{1,3} stages|[0-9]{1,3} stages (passed|green))"

# Prose lines only, JOINED INTO PARAGRAPHS. For a shell script or a workflow that
# is a comment block; for markdown, everything outside a fenced block.
#
# THE JOIN IS NOT TIDINESS. `handoff/audition-switch/stage.sh` wraps its sentence
# as "It is stage 12 of" / "34 and verify.sh stops at the first failure", so a
# line-at-a-time matcher sees `stage 12 of` with no number and `34` with no
# subject, and reports nothing on the very line ENG-290 was filed against. A
# reader reads the paragraph; so does this. The reported line number is the line
# the paragraph STARTS on, which is where a reader will look.
prose_lines() {
  local f="$1"
  case "$f" in
    *.md)
      awk '
        /^[[:space:]]*```/ { fence = !fence; if (para != "") { print start": "para; para="" } ; next }
        fence { next }
        /^[[:space:]]*$/ { if (para != "") { print start": "para; para="" } ; next }
        { if (para == "") { start = FNR; para = $0 } else { para = para " " $0 } }
        END { if (para != "") print start": "para }
      ' "$f"
      ;;
    *)
      awk '
        /^[[:space:]]*#/ {
          t = $0; sub(/^[[:space:]]*#[[:space:]]?/, "", t)
          if (para == "") { start = FNR; para = t } else { para = para " " t }
          next
        }
        { if (para != "") { print start": "para; para="" } }
        END { if (para != "") print start": "para }
      ' "$f"
      ;;
  esac
}

# A `suite-count: exempt` marker suppresses a paragraph. The escape hatch exists
# because a document ABOUT this class has to be able to quote a number - this
# file does, four times, and excluding this file by NAME instead would be the
# "a gate that scans its own directory cites itself" fix that hides the leak
# rather than closing it.
#
# RETURNS 0 WHEN THERE IS NOTHING TO REPORT, explicitly. Under `set -euo
# pipefail` a `grep` that matches nothing fails the pipeline, which fails the
# function, which killed this whole self-test silently while it was being
# written - every control unrun, reported as a pass. That is this repository's
# own most-repeated shape, met while building the detector for a neighbour.
suite_counts_in() {
  local f="$1" hits
  hits="$(prose_lines "$f" |
          grep -EI "$COUNT_RE|$OFM_RE" |
          grep -vE 'suite-count: exempt' || true)"
  [ -z "$hits" ] && return 0
  # Report the matched PHRASE, not the paragraph the join produced. The join is
  # how the match is found across a wrapped sentence; printing it back would put
  # a sixty-line comment block in the output for a four-word finding.
  printf '%s\n' "$hits" | while IFS= read -r hit; do
    ln="$(printf '%s' "$hit" | sed -E 's/:.*//')"
    phrase="$(printf '%s' "$hit" | grep -oEI "$COUNT_RE|$OFM_RE" | head -1 | sed -E 's/^[^A-Za-z0-9]+//')"
    printf '%s:%s: %s\n' "${f#"$ROOT"/}" "$ln" "$phrase"
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
#
# The two halves pull in opposite directions and the second is the one that
# earns the detector. Reporting a stale number is easy. Staying silent on a
# COMPUTED count — `printf '%d gates' "$n"` — is what separates this from a gate
# that fires on `bin/verify.sh` and `check-shell.sh` on every run and therefore
# gets deleted. A test count is the third control: it is dated by the Status line
# it sits in and is explicitly NOT this class, per 910ed93.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  printf '#!/usr/bin/env bash\n# the suite runs 34 verify stages end to end\ntrue\n' > "$CTL/verifystages.sh"
  printf '#!/usr/bin/env bash\n# it is stage 12 of 34 and verify stops there\ntrue\n'  > "$CTL/ofm.sh"
  printf '#!/usr/bin/env bash\n# the run reported 37 stages passed on both clones\ntrue\n' > "$CTL/passed.sh"

  # THE FOUR THAT MUST STAY GREEN, and each is a real line from this tree.
  # `stage` alone is never the anchor; without these the detector reports on
  # F14, F27, LANGUAGE.md and its own bin/verify.sh on every run.
  printf '| F14.2 | a three-stage chain of ordinary calls | ok |\n' > "$CTL/otherstage.md"
  printf '`!` fails one stage earlier, in the lexer.\n'            > "$CTL/lexer.md"
  printf '#!/usr/bin/env bash\nn=3\nprintf "%%d verify stages\\n" "$n"\n'  > "$CTL/computed.sh"
  printf '**Status** **done 2026-08-23** — 501 tests, twenty gate scripts.\n' > "$CTL/gatecount.md"
  printf 'A count of stages.\n\n```\nit is stage 12 of 34 here\n```\n'   > "$CTL/fenced.md"

  fail=0
  red() {
    if [ -z "$(suite_counts_in "$CTL/$1")" ]; then
      echo "SELF-TEST FAILED: $1 — $2"; fail=1
    fi
  }
  green() {
    local out; out="$(suite_counts_in "$CTL/$1")"
    if [ -n "$out" ]; then
      echo "SELF-TEST FAILED: $1 — $2"; printf '  reported: %s\n' "$out"; fail=1
    fi
  }

  red verifystages.sh "a count of verify stages in a comment was not reported"
  red ofm.sh          "\`stage N of M\` was not reported; M is the suite size, and it is the
                  shape ENG-290 still has open against handoff/audition-switch/stage.sh"
  red passed.sh       "\`N stages passed\` was not reported"

  green otherstage.md "a three-STAGE CHAIN was reported. That is F14.2, and stages of
                  something that is not the verify suite are not this class — which is
                  why the word \`stage\` alone is never the anchor"
  green lexer.md      "\"fails one stage earlier, in the lexer\" was reported. Same class of
                  false positive as F14.2, one construct down"
  green computed.sh   "a COUNTED number was reported. bin/verify.sh prints one on every
                  run; a detector that fires on it is red on a clean tree and gets deleted"
  green gatecount.md  "a GATE count in a dated Status line was reported. The repository
                  corrects those and deletes stage counts — 80eb902 and 619b4b9 recounted
                  and fixed the gate count; 910ed93 deleted the stage count. Firing here
                  reports 44 lines of accepted practice as defects"
  green fenced.md     "a count inside a fenced code block was reported; a fence is code"

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported a verify-stage count, a \`stage N of M\` and a \`stages passed\`;"
    echo "           stayed silent on stages of other things, a computed count, a dated gate"
    echo "           count and a fenced block — the detector discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-stale-suite-count.sh [--self-test]"; exit 2; }

scanned=0
findings=""
for r in "${SCAN_ROOTS[@]}"; do
  p="$ROOT/$r"
  if [ -f "$p" ]; then
    scanned=$((scanned + 1))
    out="$(suite_counts_in "$p")" && [ -n "$out" ] && findings+="$out"$'\n'
  elif [ -d "$p" ]; then
    while IFS= read -r f; do
      scanned=$((scanned + 1))
      out="$(suite_counts_in "$f")" && [ -n "$out" ] && findings+="$out"$'\n'
    done < <(find "$p" -type f \( -name '*.sh' -o -name '*.md' -o -name '*.yml' \) -not -path '*/node_modules/*')
  fi
done

if [ "$scanned" -eq 0 ]; then
  echo "no documents scanned — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "A count of verify stages is re-staled by the next gate anybody"
  echo "writes, and a reader has no way to tell which suite it counted. Four commits"
  echo "have already reached the same answer independently: delete it, or replace it"
  echo "with a date or a phrase. Correcting the number restarts the same drift."
  echo "If the line is ABOUT this class and must quote a number, mark it"
  echo "\`suite-count: exempt\`."
  exit 1
fi

echo "$scanned documents carry no hand-written count of the verify suite"
