#!/usr/bin/env bash
#
# TOUR.md quotes the corpus. This proves it still does.
#
# WHY THIS EXISTS
# `bin/check-language.sh` compiles LANGUAGE.md's blocks, so that document cannot
# drift from the compiler. TOUR.md's blocks are EXCERPTS — a handful of clauses
# lifted out of a file, without the signature or the module line above them — so
# they do not compile on their own and that gate cannot reach them. The failure
# mode is therefore different and quieter: not a block that stops compiling, but
# a block that still reads plausibly while the file it claims to quote has moved
# on. A tour whose code is nearly the corpus is worse than no tour, because a
# reader has no way to tell which lines are the stale ones.
#
# WHAT IT CHECKS
# Every non-blank, non-comment, non-elision line inside a fenced block in TOUR.md
# appears VERBATIM somewhere under `compiler/examples/`. Shell transcripts
# (blocks whose first line starts with `$ `) and non-B# fences are skipped.
#
# WHAT IT DOES NOT CHECK
# That a line was quoted from the file the prose NAMES, or that the lines of a
# block are contiguous, or in order. `bin/check-links.sh` covers the paths
# themselves. A line moving from one example to another passes here — the same
# tolerance `check-tokens.sh` has, and for the same reason: this gate proves the
# text is real, never that the sentence around it is right.
#
# THE ONE TOLERANCE, and it was earned on this gate's first run. A corpus
# COMMENT counts as corpus text: the `//` and its indent are stripped before
# matching. Without that the two prelude aliases the tour shows —
# `type option<T> = T | :nothing` and its `result` sibling — were reported as
# invented, and they are not. They are written out verbatim in `parcel.bs`'s
# header, because the prelude is the one part of the language that is real code
# a user could have written and yet appears in no `.bs` file as code. The
# alternative was to let that block go untagged and ungated, which is the exact
# hole this script exists to close.
#
# Usage:  compiler/bin/check-tour.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# `TOUR_DOC` exists for the self-test below, which points this gate at mutated
# copies of the document. Nothing else sets it, and the real run reads the real
# file — the corpus and the roster are always the ones in the tree, so a control
# cannot fake the thing it is being checked against.
DOC="${TOUR_DOC:-$REPO/TOUR.md}"
CORPUS="$REPO/compiler/examples"
# `TOUR_STAMP` is the self-test's hook into part 4, the same way `TOUR_DOC` is
# into parts 1-3. Nothing else sets either.
STAMP="${TOUR_STAMP:-$REPO/TOUR.published}"

[ -f "$DOC" ] || { echo "no TOUR.md at $DOC" >&2; exit 2; }
[ -d "$CORPUS" ] || { echo "no corpus at $CORPUS" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --self-test
#
# THREE PARTS, THREE POSITIVE CONTROLS, AND ONE NEGATIVE CONTROL, because this
# gate makes three different claims and a check that fires on everything passes
# the "was it ever red" half while proving nothing.
#
# Each control is the real defect the part names, not a stand-in: a quoted
# clause the corpus does not contain, an appendix that has stopped naming a
# capability the compiler gate names, and a transcript whose pasted output is
# one digit away from what `bsc` prints. The negative control is the document
# as it stands, which must stay green — a gate that rejects the correct form
# fails every clean tree and gets switched off.
#
# Each red is required to come from the RIGHT part. All three defects would
# otherwise be satisfied by any non-zero exit, and a gate that is right by
# coincidence is what ticket 15 lost a session to.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  [ -x "$REPO/compiler/_build/default/bin/bsc" ] || {
    echo "SELF-TEST CANNOT RUN: no escript at compiler/_build/default/bin/bsc"
    echo "  rebar3 escriptize   (in compiler/, as ci.yml does before this step)"
    exit 1
  }

  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # ------------------------------------------------------------------
  # THE CONTROLS RUN AT ONCE, AND EACH VERDICT IS READ FROM ITS OWN FILE
  # (ENG-315, 2026-09-03).
  #
  # A control is this whole gate over the whole document, and part 3 booted
  # one VM per transcript until ENG-314 landed the same day, so thirteen
  # controls over fifty-odd transcripts ran for 332s on the CI runner — with
  # check-language.sh's, 65% of the job. Part 3 is one `bsc --batch` per run
  # now, and the controls still run at once because thirteen sequential
  # boots are still thirteen. The controls share nothing: each reads its own copy of the
  # document under $CTL, and the gate writes under a scratch of its own.
  # So a control is built here, launched in the background by `launch`,
  # and only QUEUED for judgement by `expect` or `accept`; after `wait`
  # the loop at the end reads every control's captured output and exit
  # status back from `$CTL/<name>.out` and `.status`. A control that never
  # wrote its status is red, never green.
  #
  # THE VERDICT COMES FROM THE FILES, NOT FROM THE LAUNCHER. A control run
  # must not see the self-test flag again, or it recurses; and its output
  # used to be captured through a helper ending in `|| true`, so a failing
  # run's text could be read under `pipefail` — which meant the negative
  # control, which is about the EXIT STATUS, passed for as long as it was
  # written through that helper (found 2026-09-02, over a stale stamp part
  # 4 was correctly rejecting). Here nothing reads a launcher's status.
  #
  # Bash 3.2 as well as 5: `wait -n` is 4.3+, so a bare `wait` collects
  # every job and the files carry the results.
  #
  # EACH RUN GETS ITS OWN TMPDIR, AND THAT IS THE RACE. Part 3's plain
  # replays run `bsc` with no `-o`, and `bsc` then names its scratch
  # directory under $TMPDIR from `erlang:unique_integer` — unique within
  # one VM, repeated across VMs: 12 distinct values from 30 fresh VMs when
  # measured on 2026-09-03. Two concurrent runs of this gate would share
  # one `Fib.beam` path. The batch form changes the count, not the race:
  # one run's replays now share a VM and cannot collide with each other,
  # while two runs are still two VMs. `bsc` reads TMPDIR itself, so a private one per
  # control keeps their scratch apart; `mktemp -d` honours it on Linux and
  # ignores it on macOS, which is why control 12 below opts out.
  # ------------------------------------------------------------------
  launch() {   # launch [--inherit-tmpdir] <name> [VAR=value ...] — this gate, in the background
    local tmp name
    if [ "$1" = "--inherit-tmpdir" ]; then
      tmp="${TMPDIR:-/tmp}"; shift
    else
      tmp="$CTL/$1.tmp"; mkdir -p "$tmp"
    fi
    name="$1"; shift
    (
      rc=0
      env TMPDIR="$tmp" "$@" "${BASH_SOURCE[0]}" > "$CTL/$name.out" 2>&1 || rc=$?
      echo "$rc" > "$CTL/$name.status"
    ) &
  }

  queued=0
  expect() {   # expect <marker> <name> <message if absent> — judged after wait
    MARK[$queued]="$1"; NAME[$queued]="$2"; WHAT[$queued]="$3"
    queued=$((queued + 1))
  }
  accept() {   # accept <name> <message if rejected> — must exit 0
    MARK[$queued]=""; NAME[$queued]="$1"; WHAT[$queued]="$2"
    queued=$((queued + 1))
  }

  st_fail=0

  # POSITIVE CONTROL 1 — a quoted line the corpus does not contain. `module
  # Readings` is quoted in chapter 1; the corpus has no `module ReadingsX`.
  sed 's/^module Readings$/module ReadingsX/' "$DOC" > "$CTL/1.md"
  launch 1 TOUR_DOC="$CTL/1.md"
  expect 'NOT IN CORPUS' 1 "an invented clause was not reported — part 1 cannot fire"

  # POSITIVE CONTROL 2 — an appendix that no longer names a shipped capability.
  sed 's/^| a valve into a call |/| a valve into a callX |/' "$DOC" > "$CTL/2.md"
  launch 2 TOUR_DOC="$CTL/2.md"
  expect 'NOT IN TOUR' 2 "a dropped capability was not reported — part 2 cannot fire"

  # POSITIVE CONTROL 3 — a transcript one digit away from what `bsc` prints.
  sed 's/^\[0, 1, 1, 2, 3, 5, 8, 13, 21, 34\]$/[0, 1, 1, 2, 3, 5, 8, 13, 21, 35]/' \
      "$DOC" > "$CTL/3.md"
  launch 3 TOUR_DOC="$CTL/3.md"
  expect DRIFTED 3 "a wrong pasted output was not reported — part 3 cannot fire"

  # POSITIVE CONTROL 4 — the injection this gate's `eval` once allowed. The
  # command must reach `bsc` as arguments and NOT run, which is checked by the
  # side effect it would have had rather than by reading the code — so it is
  # launched here and judged by hand after `wait`.
  #
  # THE SENTINEL IS UNDER $CTL, not /tmp: parallel runs share /tmp, and a stale
  # file from a previous run would make this control pass without firing.
  printf '\n```\n$ bsc --src-root examples examples/Fib Fib 10; touch %s/pwned\n[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]\n```\n' \
      "$CTL" >> "$CTL/4.md.tmp"
  cat "$DOC" "$CTL/4.md.tmp" > "$CTL/4.md"
  launch 4 TOUR_DOC="$CTL/4.md"

  # POSITIVE CONTROL 5 — the tour edited since the page was published. This is
  # the whole point of part 4, and to a comparison that cannot see the page an
  # edited TOUR.md and a wrong stamp are the same thing.
  #
  # A FIXED BOGUS HASH, NOT A CLEVER MUTATION OF THE REAL ONE. The first draft
  # flipped the last hex digit with two `sed` expressions — and they ran in
  # sequence, so the second turned the first one's change straight back. The
  # control produced the real stamp and reported that part 4 could not fire.
  sed 's/^sha256.*/sha256    0000000000000000000000000000000000000000000000000000000000000000/' \
      "$REPO/TOUR.published" > "$CTL/stale.published"
  launch 5 TOUR_STAMP="$CTL/stale.published"
  expect UNPUBLISHED 5 "a tour edited since publication was not reported —
                  the page can go stale with the build green"

  # POSITIVE CONTROL 6 — the stamp deleted. A check you can silence by removing
  # a file is a suggestion, so its absence has to be the loud case.
  launch 6 TOUR_STAMP="$CTL/not-here.published"
  expect "NO STAMP" 6 "a missing stamp was accepted — part 4 can be turned
                  off by deleting one file"

  # ------------------------------------------------------------------
  # CONTROLS 7-12 — the `expect-after` directive (ENG-263, 2026-09-02).
  #
  # A transcript replayed under an edit can be wrong in more ways than a plain
  # one, and each way below was either the defect cd61280 fixed by hand or the
  # way this directive could quietly stop meaning anything. Every control
  # mutates the real document's FIRST directive, so a control that finds
  # nothing to mutate is itself red: the `sed` is checked to have changed the
  # file, rather than trusted.
  # ------------------------------------------------------------------
  D1='<!-- expect-after: delete Classify(>= 4 and <= 7) -->'
  mutate() {  # mutate OUT SED-EXPRESSION — a copy of the document, changed, provably
    sed "$2" "$DOC" > "$1"
    if cmp -s "$1" "$DOC"; then
      echo "SELF-TEST FAILED: control $1 changed nothing — the document no longer holds"
      echo "                  the line the control edits, so the control is decorative"
      st_fail=1
    fi
  }
  # `sed` needs the directive's `(`, `)`, `>` and `<` taken literally, which in
  # a basic regex they already are; only `/` would need care, and there is none.

  # 7 — a diagnostic transcript whose directive has been removed. The state the
  # document was in for eighteen days, and the state the next hand-pasted
  # transcript arrives in.
  mutate "$CTL/7.md" "/^$D1\$/d"
  launch 7 TOUR_DOC="$CTL/7.md"
  expect 'NO DIRECTIVE' 7 "a diagnostic transcript with no directive was not reported —
                  it would be replayed against clean sources or skipped"

  # 8 — a directive naming a clause the corpus no longer has. This is the
  # instruction TOUR.md carried until cd61280: delete "the 4..7 clause", when
  # F29 had respelled it and there was nothing of that name to delete.
  mutate "$CTL/8.md" "s/^$D1\$/<!-- expect-after: delete Classify(>= 4 and <= 6) -->/"
  launch 8 TOUR_DOC="$CTL/8.md"
  expect 'NO SUCH LINE' 8 "an edit naming a line the corpus does not have was not
                  reported — a stale instruction would replay as a drift"

  # 9 — a prefix that names two lines. A reader could not follow it either.
  mutate "$CTL/9.md" "s/^$D1\$/<!-- expect-after: delete Classify( -->/"
  launch 9 TOUR_DOC="$CTL/9.md"
  expect AMBIGUOUS 9 "an edit matching two lines was not reported — the gate
                  would silently pick one"

  # 10 — the output under a directive one line number off. The exact defect:
  # `wire.bs:40` sat in this transcript while the compiler said 42.
  mutate "$CTL/10.md" 's/^examples\/Wire\/wire.bs:42: error: Classify is not exhaustive$/examples\/Wire\/wire.bs:40: error: Classify is not exhaustive/'
  launch 10 TOUR_DOC="$CTL/10.md"
  expect DRIFTED 10 "a stale line number under a directive was not reported —
                  the edited replay is not being compared"

  # 11 — a directive with no transcript under it. A check that never looked.
  printf '\n<!-- expect-after: delete Classify(1) -->\n```\n$ rebar3 escriptize\n```\n' \
      > "$CTL/11.md.tmp"
  cat "$DOC" "$CTL/11.md.tmp" > "$CTL/11.md"
  launch 11 TOUR_DOC="$CTL/11.md"
  expect DANGLING 11 "a directive over a fence with no bsc transcript was
                  accepted — it asserts nothing and reads as if it did"

  # 12 — the command's final argument is document-controlled, so it must not
  # escape the per-replay corpus and turn the edit vocabulary into a file
  # writer. Both mktemp calls create siblings; two `..` components therefore
  # reach this sentinel from `$SCRATCH/<replay>/` on macOS and Linux.
  #
  # THIS ONE INHERITS THE SELF-TEST'S TMPDIR. The sibling relation is between
  # $CTL and the gate's $SCRATCH, both from `mktemp -d`; under a private TMPDIR
  # the gate's would move on Linux and stay put on macOS, and the sentinel
  # would be reachable on one platform and decorative on the other. It is the
  # only control whose TMPDIR is the ambient one, so no other control's `bsc`
  # writes scratch beside its replays while they all run together.
  CTL_BASE="$(basename "$CTL")"
  printf 'module Sentinel\npublic atom Keep()\nKeep() -> :yes\n' > "$CTL/sentinel.bs"
  cp "$CTL/sentinel.bs" "$CTL/sentinel.want"
  cp "$DOC" "$CTL/12.md"
  {
    printf '\n<!-- expect-after: delete Keep() -->\n'
    printf '```\n'
    printf '$ bsc --src-root examples ../../%s/sentinel.bs\n' "$CTL_BASE"
    printf 'irrelevant: this command must be rejected before it runs\n'
    printf '```\n'
  } >> "$CTL/12.md"
  launch --inherit-tmpdir 12 TOUR_DOC="$CTL/12.md"
  expect 'BAD TARGET' 12 "an expect-after target outside its scratch corpus
                  was not rejected — document text can name another file"

  # NEGATIVE CONTROL — the document and the stamp as they stand. Judged on its
  # exit status, which is why `accept` reads `.status` and nothing else.
  launch committed TOUR_DOC="$DOC"
  accept committed "the document as committed was rejected, so this gate
                  would fail every clean tree and be removed"

  # ------------------------------------------------------------------
  # Every control is running. Collect them all, then judge each from what
  # it wrote. Nothing below reads `$?` of a run.
  # ------------------------------------------------------------------
  wait

  i=0
  while [ "$i" -lt "$queued" ]; do
    out="$(cat "$CTL/${NAME[$i]}.out" 2>/dev/null || true)"
    status="$(cat "$CTL/${NAME[$i]}.status" 2>/dev/null || echo "never wrote one")"
    if [ -n "${MARK[$i]}" ]; then
      case "$out" in
        *"${MARK[$i]}"*) ;;
        *) echo "SELF-TEST FAILED: ${WHAT[$i]}"
           st_fail=1 ;;
      esac
    elif [ "$status" != "0" ]; then
      echo "SELF-TEST FAILED: ${WHAT[$i]}"
      echo "                  (exit status: $status)"
      st_fail=1
    fi
    i=$((i + 1))
  done

  # Control 4, by its side effect — and first by having run at all. Nothing
  # queued a judgement on its output, so a launch that never reached the gate
  # would leave no sentinel and read as the gate refusing to execute.
  if [ ! -f "$CTL/4.status" ]; then
    echo "SELF-TEST FAILED: the injection control never ran, so an absent sentinel"
    echo "                  proves nothing about whether the gate runs a shell"
    st_fail=1
  fi
  if [ -e "$CTL/pwned" ]; then
    echo "SELF-TEST FAILED: a command in TOUR.md executed — the gate runs a shell"
    st_fail=1
  fi

  # Control 12, by its side effect.
  if ! cmp -s "$CTL/sentinel.bs" "$CTL/sentinel.want"; then
    echo "SELF-TEST FAILED: an expect-after target escaped its scratch corpus and"
    echo "                  modified an external sentinel"
    st_fail=1
  fi

  if [ "$st_fail" -eq 0 ]; then
    echo "self-test: reported the invented clause, the dropped capability, the wrong"
    echo "           output, the unpublished edit and the missing stamp; refused to"
    echo "           execute a command in the document; reported the diagnostic with"
    echo "           no directive, the edit naming no line, the edit naming two, the"
    echo "           stale number under an edit, the directive over nothing and an"
    echo "           edit target outside its scratch corpus;"
    echo "           accepted the committed one — the gate discriminates"
    exit 0
  fi
  exit 1
fi

# One flattened copy of every example, so a line is checked with one grep.
ALL="$(mktemp)"
RAW="$(mktemp)"
# Part 3 copies the corpus here before applying an `expect-after` edit, so the
# tree is never touched. One copy per edited transcript, numbered.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$ALL" "$RAW" "$SCRATCH"' EXIT
find "$CORPUS" -name '*.bs' -exec cat {} + > "$RAW"
# Comment text counts — see the tolerance above. Both spellings of a commented
# line go into the haystack, so a quote matches whichever way it was written.
# Two files rather than one appended to itself: reading and writing the same
# path in one pipeline is undefined, and shellcheck says so at `info`, which is
# the level `bin/check-shell.sh` runs these at.
cat "$RAW" > "$ALL"
sed -n 's|^ *// \{0,3\}||p' "$RAW" >> "$ALL"

echo
echo "lines TOUR.md quotes from the corpus"
echo

fail=0
checked=0

# `in_block` tracks the fence; `skip` marks a transcript or a non-B# fence.
in_block=0
skip=0
lineno=0

while IFS= read -r line; do
    lineno=$((lineno + 1))

    case "$line" in
        '```'*)
            if [ "$in_block" -eq 1 ]; then
                in_block=0; skip=0
            else
                in_block=1; skip=0
                # A fence with a language tag is prose, not corpus.
                [ "$line" != '```' ] && skip=1
            fi
            continue
            ;;
    esac

    [ "$in_block" -eq 1 ] || continue
    [ "$skip" -eq 1 ] && continue

    # A transcript line, and everything after it in this block, is output.
    case "$line" in
        '$ '*) skip=1; continue ;;
    esac

    # Blank, comment, and the elision marker prose uses between clauses.
    [ -n "${line// /}" ] || continue
    case "$line" in
        '//'*|' '*'//'*) continue ;;
        '...'|'…') continue ;;
    esac

    checked=$((checked + 1))
    if ! grep -qxF "$line" "$ALL"; then
        echo "  NOT IN CORPUS  TOUR.md:$lineno"
        echo "                 $line"
        fail=1
    fi
done < "$DOC"

if [ "$fail" -eq 0 ]; then
    printf '  %-9s %d lines, every one verbatim in compiler/examples/\n' "ok" "$checked"
else
    echo
    echo "TOUR.md quotes lines the corpus does not contain."
fi

# --- 2: the tour meets every capability the corpus gate names ----------------
#
# `corpus_tests:demonstrated_surface/0` is the list of capabilities that owe an
# example, and it fails BY NAME when a shipped form has nothing to look at. The
# tour claims to walk all of them, so the two lists are diffed here rather than
# by eye — and the appendix carries the gate's own wording so that a diff is
# possible at all.
#
# This is the check that makes "every construct" a proven claim. Without it the
# appendix is a promise, and the next capability added to the roster ships with
# the tour silently one short.
ROSTER="$REPO/compiler/test/corpus_tests.erl"

echo
echo "capabilities the corpus gate names, and the tour's appendix"
echo

missing=0
named=0
while IFS= read -r cap; do
    [ -n "$cap" ] || continue
    named=$((named + 1))
    if ! grep -qF "| $cap |" "$DOC"; then
        echo "  NOT IN TOUR    $cap"
        missing=1; fail=1
    fi
done < <(awk '/^demonstrated_surface\(\) ->/,/^\]\./' "$ROSTER" |
         grep -oE '\{"[^"]*"' | sed 's/[{"]//g')

if [ "$named" -eq 0 ]; then
    echo "  read no capabilities from $ROSTER — the roster moved" >&2
    exit 2
fi
[ "$missing" -eq 0 ] &&
    printf '  %-9s all %d appear in the appendix\n' "ok" "$named"

# --- 3: the transcripts still print what they say they print -----------------
#
# Part 1 covers the B#; this covers the shell. Roughly forty `$ bsc …` lines
# carry pasted output, and without this they are the ungated half of a document
# whose whole pitch is that it cannot drift.
#
# A transcript showing a DIAGNOSTIC was produced by editing a corpus file in
# place, so replaying its command against clean sources would correctly print
# nothing. Until 2026-09-02 those four were SKIPPED, and the skip was named in
# the output rather than silent — which was honest, and still left the
# transcripts whose whole point is the diagnostic under no check at all. Three
# stale line numbers and one instruction naming a clause that no longer existed
# sat in them for days, found by a reader and fixed by hand in `cd61280`, whose
# own message said the numbers would drift again (ENG-263).
#
# THE EDIT IS NOW WRITTEN ABOVE THE FENCE, WHERE THIS GATE CAN READ IT:
#
#   <!-- expect-after: delete Classify(>= 4 and <= 7) -->
#   ```
#   $ bsc --src-root examples examples/Wire
#   examples/Wire/wire.bs:42: error: Classify is not exhaustive
#   ...
#
# The corpus is copied, the edit applied to the copy under the path the command
# names last, and the command replayed from there — so the output, paths and
# line numbers included, is compared byte for byte like every other transcript.
# Two edits exist, and several may be joined with `;`:
#
#   delete <prefix>                 remove the one line that starts with <prefix>
#   replace <prefix> with <text>    rewrite that line's <prefix> as <text>
#
# A prefix is matched with runs of whitespace collapsed, so a clause the file
# aligns with spaces is named without them, and it must match EXACTLY ONE line:
# zero is an instruction that has gone stale, two is one a reader could not
# follow either, and both are red. A diagnostic transcript with no directive is
# red as well, rather than skipped — the next transcript pasted in from an edit
# made by hand would otherwise start the same rot over again.
#
# The directive never reaches a shell. It is cut on `;` and ` with ` in bash and
# the pieces go to awk as values, for the reason `split_command` below exists.
BSC="$REPO/compiler/_build/default/bin/bsc"
[ -x "$BSC" ] || {
    echo "no escript at $BSC — run \`rebar3 escriptize\` in compiler/ first" >&2
    exit 2
}

echo
echo "transcripts TOUR.md pastes"
echo

replayed=0
drifted=0
mutated=0
cmd=""
want=""
edits=""
block_cmds=0
in_block=0
queued_cmds=0
MANIFEST="$SCRATCH/manifest"
RESULTS="$SCRATCH/results"
# The document carried four transcripts under an edit on the day this landed.
# Fewer is a directive that stopped being read, not a document that got
# shorter — the diagnostic-shape test in `replay` is the other half of this
# floor, and a change that blinds both at once is what the number is for.
EXPECT_AFTER_FLOOR=4

# apply_edits ROOT TARGET EDITS — the directive, applied to a copy of the corpus.
#
# TARGET is the path the command names, relative to ROOT; a directory means
# every `.bs` beneath it. Prints one line naming the reason and returns 1 when
# an edit does not name exactly one line, or is not an edit this gate knows.
apply_edits() {
    local root="$1" target="$2" edits="$3" edit mode prefix text files f n total hit
    local path examples_root resolved parent
    # TARGET comes from the transcript's final argument. Keep it inside the
    # copied corpus before either awk or mv sees it: `../` here would otherwise
    # turn a documentation edit into a write anywhere reachable from SCRATCH.
    case "$target" in
        examples|examples/*) ;;
        *) echo "BAD TARGET  '$target' — expect-after may edit only compiler example paths"
           return 1 ;;
    esac
    case "/$target/" in
        *'/../'*|*'/./'*|*'//'*)
            echo "BAD TARGET  '$target' — expect-after paths must be canonical"
            return 1 ;;
    esac
    path="$root/$target"
    examples_root="$(cd "$root/examples" && pwd -P)"
    if [ -d "$path" ]; then
        resolved="$(cd "$path" 2>/dev/null && pwd -P)" || {
            echo "BAD TARGET  '$target' — expect-after could not resolve that path"
            return 1
        }
        case "$resolved" in
            "$examples_root"|"$examples_root"/*) ;;
            *) echo "BAD TARGET  '$target' — expect-after resolved outside compiler examples"
               return 1 ;;
        esac
        files="$(find "$resolved" -name '*.bs' | sort)"
    else
        case "$target" in
            *.bs) ;;
            *) echo "BAD TARGET  '$target' — expect-after files must end in .bs"
               return 1 ;;
        esac
        if [ ! -f "$path" ] || [ -L "$path" ]; then
            echo "BAD TARGET  '$target' — expect-after files must be regular .bs files"
            return 1
        fi
        parent="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)" || {
            echo "BAD TARGET  '$target' — expect-after could not resolve that path"
            return 1
        }
        resolved="$parent/$(basename "$path")"
        case "$resolved" in
            "$examples_root"/*) files="$resolved" ;;
            *) echo "BAD TARGET  '$target' — expect-after resolved outside compiler examples"
               return 1 ;;
        esac
    fi
    while IFS= read -r edit; do
        edit="$(printf '%s' "$edit" | sed 's/^ *//; s/ *$//')"
        [ -n "$edit" ] || continue
        case "$edit" in
            'delete '*)
                mode=delete; prefix="${edit#delete }"; text="" ;;
            'replace '*)
                mode=replace; prefix="${edit#replace }"
                case "$prefix" in
                    *' with '*) text="${prefix##* with }"; prefix="${prefix% with *}" ;;
                    *) echo "BAD EDIT  '$edit' — replace needs 'with'"; return 1 ;;
                esac ;;
            *)  echo "BAD EDIT  '$edit' — only 'delete <prefix>' and 'replace <prefix> with <text>' exist"
                return 1 ;;
        esac
        prefix="$(printf '%s' "$prefix" | tr -s '[:blank:]' ' ')"
        total=0; hit=""
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            n="$(awk -v p="$prefix" 'BEGIN { c = 0 }
                { l = $0; gsub(/[ \t]+/, " ", l); sub(/^ /, "", l); if (index(l, p) == 1) c++ }
                END { print c }' "$f")"
            if [ "$n" -gt 0 ]; then total=$((total + n)); hit="$f"; fi
        done <<< "$files"
        if [ "$total" -eq 0 ]; then
            echo "NO SUCH LINE  '$edit' — nothing under $target starts with '$prefix'"
            return 1
        elif [ "$total" -gt 1 ]; then
            echo "AMBIGUOUS  '$edit' — $total lines under $target start with '$prefix'"
            return 1
        fi
        awk -v p="$prefix" -v r="$text" -v m="$mode" '
            { l = $0; gsub(/[ \t]+/, " ", l); sub(/^ /, "", l)
              if (index(l, p) == 1) {
                  if (m == "delete") next
                  print r substr(l, length(p) + 1); next
              }
              print }' "$hit" > "$hit.tmp" && mv "$hit.tmp" "$hit"
    done <<< "$(printf '%s' "$edits" | tr ';' '\n')"
    return 0
}

# SPLITTING A COMMAND LINE WITHOUT A SHELL, AND WHY IT IS WORTH THE LINES.
#
# The first draft ran `eval` on the command string it had just read out of
# TOUR.md, because the arguments carry quotes — `Classify '(:ok, 5)'` — and
# `eval` is the one-liner that honours them. It is also arbitrary code
# execution from a file in the repository, and this workflow runs on
# `pull_request`, so a line added to a markdown document would have executed in
# CI. A security review of the pushed commits caught it.
#
# So the quotes are honoured here instead, by a reader that understands exactly
# two things — single quotes, and double quotes with backslash escapes — and
# performs no expansion of any kind. A `;` or a `$(…)` in TOUR.md now reaches
# `bsc` as an ordinary argument, which is the correct outcome: the gate is
# meant to run the compiler, and nothing else.
#
# Fills the global `ARGV`. An empty quoted argument would be dropped; nothing
# in the document has one, and adding the flag to track it would be the only
# state this reader needs beyond the character it is looking at.
split_command() {
    local s="$1" tok="" quote="" c esc=0 i
    ARGV=()
    for (( i = 0; i < ${#s}; i++ )); do
        c="${s:i:1}"
        if [ "$esc" -eq 1 ]; then
            tok+="$c"; esc=0
        elif [ "$quote" = '"' ] && [ "$c" = '\' ]; then
            esc=1
        elif [ -n "$quote" ]; then
            if [ "$c" = "$quote" ]; then quote=""; else tok+="$c"; fi
        elif [ "$c" = "'" ] || [ "$c" = '"' ]; then
            quote="$c"
        elif [ "$c" = " " ]; then
            [ -n "$tok" ] && { ARGV+=("$tok"); tok=""; }
        else
            tok+="$c"
        fi
    done
    [ -n "$tok" ] && ARGV+=("$tok")
    [ -z "$quote" ]
}

replay() {
    [ -n "$cmd" ] || return 0
    replayed=$((replayed + 1))
    block_cmds=$((block_cmds + 1))

    if ! split_command "$cmd"; then
        echo "  UNBALANCED QUOTE  \$ $cmd"
        drifted=1; fail=1
        return 0
    fi

    local root last reason where a
    # ARGV[0] is the literal `bsc` the document writes; the escript is under
    # _build. Everything after it is passed as an argument vector, never as a
    # string a shell gets to look at again.
    if [ -n "$edits" ]; then
        # The transcript came from an edited corpus. Rebuild that corpus in a
        # scratch copy — never the tree — and replay from there, so `examples/…`
        # in the command and in the output resolve exactly as they do in the
        # document.
        mutated=$((mutated + 1))
        root="$SCRATCH/$mutated"
        rm -rf "$root"; mkdir -p "$root"
        cp -R "$CORPUS" "$root/examples"
        last="${ARGV[$((${#ARGV[@]} - 1))]}"
        if ! reason="$(apply_edits "$root" "$last" "$edits")"; then
            echo "  $reason"
            echo "    under:   <!-- expect-after: $edits -->"
            echo "    \$ $cmd"
            drifted=1; fail=1
            return 0
        fi
        where="$root"
    else
        # A diagnostic transcript needs the edit that produced it; see above.
        case "$want" in
            examples/*:[0-9]*|'#{'*|'error: '*)
                echo "  NO DIRECTIVE  \$ $cmd"
                echo "    the pasted output is a diagnostic, so it came from an edited corpus."
                echo "    Say which edit, above the fence: <!-- expect-after: delete <clause> -->"
                drifted=1; fail=1
                return 0 ;;
        esac
        where="$REPO/compiler"
    fi

    # QUEUED, NOT RUN (ENG-314, 2026-09-03). Every transcript used to be its own
    # `bsc` process here, and a process is a VM boot: fifty-odd of them, times
    # the thirteen controls in the self-test, was 332s on the CI runner. The
    # invocation goes into one manifest instead — its working directory, then
    # ONE `arg` LINE PER ELEMENT OF ARGV — and `bsc --batch` runs the whole
    # document in one VM after the scan. The argument vector `split_command`
    # built is preserved exactly: a newline is the boundary, nothing is quoted
    # and nothing downstream re-parses a command line, so the `; touch pwned`
    # control still reaches the compiler as arguments and never a shell. The
    # verdict is read from `<id>.output` after the batch, in `judge_replays`.
    # The four lines are `check-language.sh`'s `manifest_entry`, written here
    # rather than sourced for the reason `apply_edits` above gives.
    queued_cmds=$((queued_cmds + 1))
    {
        printf 'entry t%d\n' "$queued_cmds"
        printf 'cwd %s\n' "$where"
        for a in "${ARGV[@]:1}"; do printf 'arg %s\n' "$a"; done
        printf 'end\n\n'
    } >> "$MANIFEST"
    printf '%s' "$cmd"   > "$SCRATCH/t$queued_cmds.cmd"
    printf '%s' "$want"  > "$SCRATCH/t$queued_cmds.want"
    printf '%s' "$edits" > "$SCRATCH/t$queued_cmds.edits"
}

# One VM over every queued transcript, then each verdict from its own files.
# The merged stream is what `2>&1` delivered before, and `$(cat …)` strips the
# trailing newline exactly as the command substitution around the old
# per-process run did, so the comparison is the same comparison.
#
# A BATCH THAT CANNOT RUN IS RED ONCE, NOT FIFTY TIMES: nothing below it is
# judged, and a transcript with no status file is reported rather than skipped.
judge_replays() {
    local n=1 got
    [ "$queued_cmds" -gt 0 ] || return 0
    if ! "$BSC" --batch "$MANIFEST" "$RESULTS" > "$SCRATCH/batch.log" 2>&1; then
        echo "  BATCH FAILED  bsc --batch could not replay the transcripts; none was judged"
        sed 's/^/                /' "$SCRATCH/batch.log"
        drifted=1; fail=1
        return 0
    fi
    while [ "$n" -le "$queued_cmds" ]; do
        cmd="$(cat "$SCRATCH/t$n.cmd")"
        want="$(cat "$SCRATCH/t$n.want")"
        edits="$(cat "$SCRATCH/t$n.edits")"
        if [ ! -f "$RESULTS/t$n.status" ]; then
            echo "  NO RESULT  \$ $cmd"
            echo "    the batch wrote no verdict for this transcript"
            drifted=1; fail=1
        else
            got="$(cat "$RESULTS/t$n.output")"
            if [ "$got" != "$want" ]; then
                echo "  DRIFTED   \$ $cmd"
                [ -z "$edits" ] || echo "    after:   $edits"
                echo "    pasted:  $want"
                echo "    prints:  $got"
                drifted=1; fail=1
            fi
        fi
        n=$((n + 1))
    done
}

while IFS= read -r line; do
    case "$line" in
        '```'*)
            if [ "$in_block" -eq 1 ]; then
                replay; cmd=""; want=""
                # A directive with nothing under it to replay is a check that
                # never looked. Loud, for the same reason the roster floors are.
                if [ -n "$edits" ] && [ "$block_cmds" -eq 0 ]; then
                    echo "  DANGLING  <!-- expect-after: $edits -->"
                    echo "    no \`\$ bsc\` transcript follows it in the next fence"
                    drifted=1; fail=1
                fi
                edits=""; block_cmds=0
            fi
            in_block=$((1 - in_block))
            continue
            ;;
    esac
    if [ "$in_block" -eq 0 ]; then
        # The directive binds to the next fence. Inside a fence the same text
        # would be output, which is why this is read only between blocks.
        case "$line" in
            '<!-- expect-after:'*)
                edits="${line#<!-- expect-after:}"
                edits="${edits%-->}"
                edits="$(printf '%s' "$edits" | sed 's/^ *//; s/ *$//')" ;;
        esac
        continue
    fi

    case "$line" in
        '$ bsc '*)
            replay
            cmd="${line#$ }"; want=""
            ;;
        '$ '*)
            # Some other command — `cd`, `rebar3`, the `erl` spec dump. Not this
            # gate's business, and it ends whatever transcript preceded it.
            replay; cmd=""; want=""
            ;;
        *)
            [ -n "$cmd" ] || continue
            if [ -z "$want" ]; then want="$line"; else want="$want
$line"; fi
            ;;
    esac
done < "$DOC"
replay
judge_replays

# The verdict word is computed, not written. An earlier draft printed `ok`
# unconditionally under the DRIFTED lines it had just emitted, which is the
# same class of defect as a gate that returns success for work it did not do.
if [ "$drifted" -eq 0 ] && [ "$mutated" -lt "$EXPECT_AFTER_FLOOR" ]; then
    echo "  TOO FEW   $mutated transcripts replayed under an edit; the document had $EXPECT_AFTER_FLOOR"
    echo "            on 2026-09-02. A directive stopped being read, or a transcript"
    echo "            lost its edit — lower the floor only if one was removed on purpose."
    drifted=1; fail=1
fi
if [ "$drifted" -eq 0 ]; then
    printf '  %-9s %d commands replayed, %d of them after an edit the document names\n' \
        "ok" "$replayed" "$mutated"
else
    echo
    echo "TOUR.md pastes output the compiler no longer produces."
fi

# --- 4: the published page is not older than the file -----------------------
#
# TOUR.md is also published as an artifact, and that page is a SNAPSHOT — it
# does not track the repository. Parts 1-3 keep the file honest against the
# compiler; nothing kept the page honest against the file, so it could go stale
# silently and mislead a reader who had only ever seen the link.
#
# THE CHECK IS A STAMP, NOT A FETCH, AND THE REASON IS IN `TOUR.published`.
# The artifact is private: readable through the owner's claude.ai login, and
# `curl` gets the single-page-app shell or a Cloudflare 403. A CI runner has
# neither, so a gate that fetched would be red on every run for reasons
# unrelated to staleness. Putting a session token in a repository secret was
# rejected — a personal credential with far more reach than this needs.
#
# So the stamp records TOUR.md's hash at the moment the page was published, and
# this compares it to the file. Editing the tour without republishing goes red.
# What it cannot prove is that the page holds those bytes: bumping the stamp
# without republishing satisfies it. Republish and stamp in the same commit.
echo
echo "the published page against the file"
echo

if [ ! -f "$STAMP" ]; then
    # Deleting the stamp must not be a way to silence this. A gate you can turn
    # off by removing a file is a suggestion.
    echo "  NO STAMP  $STAMP is missing"
    echo "            it records which version of TOUR.md is on the published"
    echo "            page; without it nothing knows whether the page is current."
    fail=1
else
    want="$(sed -n 's/^sha256[[:space:]]*//p' "$STAMP" | tr -d '[:space:]')"
    have="$(shasum -a 256 "$DOC" | cut -d' ' -f1)"
    if [ -z "$want" ]; then
        echo "  NO STAMP  $STAMP names no sha256"
        fail=1
    elif [ "$want" = "$have" ]; then
        printf '  %-9s the page was published from this exact file\n' "ok"
    else
        echo "  UNPUBLISHED  TOUR.md has changed since the page was published"
        echo "            file:   $have"
        echo "            page:   $want"
        echo
        echo "            Republish the artifact from TOUR.md — same URL, which is"
        echo "            in $(basename "$STAMP") — then update the sha256 there in the"
        echo "            same commit. A reader with only the link sees the old one"
        echo "            until you do."
        fail=1
    fi
fi

echo
exit "$fail"
