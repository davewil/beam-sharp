#!/usr/bin/env bash
#
# check-decisions.sh — a resolved ticket must carry its own answer, and
# decisions.md must not be the only place that answer exists.
#
# WHY THIS EXISTS (2026-09-04, ENG-310)
#
# David, reading wayfinder/ directly: "these files are all huge, and your
# context can't possibly take it all in at once." The audit that followed found
# the size was a symptom and the cause was structural — the ANSWER and the
# WORKING had fused, and where a ticket never wrote its answer down, the answer
# migrated into decisions.md instead. Measured at e4f3e84 across 58 resolved
# tickets:
#
#   * 14 resolved tickets had NO answer section at all — 16, 17, 18, 20, 26, 27,
#     28, 30, 35, 40, 46, 47, 58, 63 — and they are the largest files in the
#     tree. Their answers existed only as decisions.md prose.
#   * 5 more used a heading nothing else used: `## DECIDED` (48, 49, 50),
#     `## The answer` (56), and a level-3 `### Answer the cheap question first`
#     (41). Nineteen spellings of one field is not a field.
#   * 6 resolved tickets had no decisions.md entry at all — 35, 36, 48, 50, 56,
#     58 — so the file whose own header promises "one entry per closed ticket"
#     was missing six of them.
#   * Ticket 63's Status line said "Answer and full reasoning in decisions.md"
#     while decisions.md's header said "the ticket itself is where the full
#     reasoning lives". Each pointed at the other and neither held the answer.
#
# THE POINT IS STAGE 2. ENG-310's plan is derive-after-backfill: decisions.md
# becomes generated rather than hand-kept, so it cannot drift. A generator needs
# one field in one spelling in every ticket, and this gate is what makes that
# field exist and keeps it existing. Until it is green there is nothing to
# generate from. After it is green, the backfill cannot rot back.
#
# WHY NOT JUST GENERATE NOW. Because 37 of 56 entries carry cross-ticket
# synthesis — "retracts a ticket 03 claim", "superseded in part by #19" — that
# no per-ticket answer block contains. Check D is the beginning of capturing
# that as data (`Amends:`) rather than prose. Deriving before it exists would
# have silently dropped three entries in five.
#
# WHAT IT CHECKS
#   A. NOANSWER  every resolved ticket has a `## Answer` heading.
#   B. THIN      that block says something — 40 words is the floor.
#   C. DELEGATED no ticket's Status sends the reader to decisions.md instead.
#   D. NOENTRY   every resolved ticket is named by a decisions.md entry.
#   E. DANGLING  every `Amends:` relation resolves to a ticket that exists.
#   F. UNKNOWN   every ticket's Status is a word this gate recognises.
#
# CHECK F IS WHY THE OTHERS CAN BE BELIEVED. Every check above selects the
# tickets it examines by reading Status, so an unrecognised Status does not fail
# them — it EXEMPTS the ticket from all of them, silently. Ticket 11 sat at
# `Status: closed` and was invisible to A through E while the map indexed it
# under decisions and ticket 12 cited it as "resolved 2026-08-12". That is the
# same vacuous-skip ENG-320 fixed in `prelude_entries()`, arriving here.
#
# Usage:  bin/check-decisions.sh [--self-test]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `CHECK_DECISIONS_DIR` exists for the self-test below, which points this gate
# at mutated COPIES of the real wayfinder directory. Nothing else sets it. The
# copies are the real files with one defect introduced, so a control cannot pass
# by being simpler than the thing it stands in for.
WAYFINDER="${CHECK_DECISIONS_DIR:-$ROOT/wayfinder}"

# The floor for check B. The smallest answer block in the corpus at e4f3e84 was
# 208 words (ticket 04), so 40 is far below anything real and fires only on a
# block that was created to satisfy check A without being written. Raising it
# toward 208 would be a style rule, which this gate is not.
WORD_FLOOR=40

[ -d "$WAYFINDER/issues" ] || { echo "no issues/ at $WAYFINDER" >&2; exit 2; }
[ -f "$WAYFINDER/decisions.md" ] || { echo "no decisions.md at $WAYFINDER" >&2; exit 2; }

# ---------------------------------------------------------------------------
# --self-test
#
# FIVE CHECKS, FIVE POSITIVE CONTROLS, each required to carry its own marker.
# Any one of them satisfies a bare "did it exit non-zero", and a gate that is
# right by coincidence is worth nothing.
#
# Check D is the one that most needs a control. A tree where every ticket is
# beautifully answered and decisions.md never mentions six of them passes A, B,
# C and E — which is the exact state this gate was written to end.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Output is CAPTURED, not piped: `set -o pipefail` is on and a control run
    # is supposed to exit 1, so `control … | grep` would report the failing
    # left-hand status even when the marker was found.
    control() {
        CHECK_DECISIONS_DIR="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }
    fresh() {
        rm -rf "$1"; mkdir -p "$1/issues"
        cp "$WAYFINDER/decisions.md" "$1/"
        cp "$WAYFINDER"/issues/*.md "$1/issues/"
    }

    st_fail=0
    expect() {   # expect <marker> <dir> <what the control built>
        case "$(control "$2")" in
            *"$1"*) ;;
            *) echo "SELF-TEST FAILED: $3 was not reported — the $1 check cannot fire"
               st_fail=1 ;;
        esac
    }

    # A ticket that is resolved and well-formed, used as the raw material for
    # controls A, B and C. Ticket 04 is chosen because its answer block is the
    # SMALLEST in the corpus — a control built from the most generous case would
    # not prove the check reaches the tightest one.
    victim() {
        # A glob rather than `ls`, so a filename is never re-split — the gate
        # that decides whether everything else is correct does not get to have
        # a quoting bug.
        set -- "$1"/issues/04-*.md
        printf '%s' "$1"
    }

    # CONTROL A — a resolved ticket whose answer heading is gone. The heading is
    # renamed rather than deleted so the ticket keeps its prose: this is exactly
    # the shape of the 14, which discuss their answer at length under some other
    # heading and never label it.
    fresh "$CTL/noanswer"
    sed -i.bak 's/^## Answer$/## Where this landed/' "$(victim "$CTL/noanswer")"
    expect NOANSWER "$CTL/noanswer" "a resolved ticket with no answer heading"

    # CONTROL B — an answer heading with nothing under it. This is the failure
    # mode of the backfill itself: satisfying check A by typing a heading.
    fresh "$CTL/thin"
    python3 - "$(victim "$CTL/thin")" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
i = t.index('\n## Answer')
j = t.index('\n## ', i + 5)
open(p, 'w').write(t[:i] + '\n## Answer\n\nSee the ticket.\n' + t[j:])
PY
    expect THIN "$CTL/thin" "an answer heading with nothing written under it"

    # CONTROL C — a ticket that sends the reader to decisions.md for its answer.
    # Ticket 63 shipped in exactly this state.
    fresh "$CTL/delegated"
    sed -i.bak 's/^Status: \(.*\)$/Status: \1 Answer in [`decisions.md`](..\/decisions.md)./' \
        "$(victim "$CTL/delegated")"
    expect DELEGATED "$CTL/delegated" "a ticket delegating its answer to decisions.md"

    # CONTROL D — a resolved ticket that decisions.md never names. Removing the
    # ENTRY rather than the ticket is the point: the ticket is perfect and the
    # index has lost it, which is the state six tickets were actually in.
    fresh "$CTL/noentry"
    python3 - "$CTL/noentry/decisions.md" <<'PY'
import sys
p = sys.argv[1]
L = open(p).read().split('\n')
idx = [i for i, l in enumerate(L) if l.startswith('- ')]
tgt = next(k for k, i in enumerate(idx) if 'issues/04-' in '\n'.join(
    L[i:(idx[k + 1] if k + 1 < len(idx) else len(L))]))
end = idx[tgt + 1] if tgt + 1 < len(idx) else len(L)
open(p, 'w').write('\n'.join(L[:idx[tgt]] + L[end:]))
PY
    expect NOENTRY "$CTL/noentry" "a resolved ticket with no decisions.md entry"

    # CONTROL E — an Amends: pointing at a ticket that does not exist. The
    # relation is the field stage 2 will consume, so a broken one must be loud
    # now rather than at generation time.
    fresh "$CTL/dangling"
    sed -i.bak 's/^Type: /Amends: ticket 99 (no such ticket)\
Type: /' "$(victim "$CTL/dangling")"
    expect DANGLING "$CTL/dangling" "an Amends: naming a ticket that does not exist"

    # CONTROL F — a ticket whose Status is outside the vocabulary. This control
    # is checked twice: the marker must appear, AND the NOANSWER check must stop
    # reporting the same ticket, because that is the proof the unknown Status
    # really did exempt it from everything rather than merely annoy the parser.
    fresh "$CTL/unknown"
    v="$(victim "$CTL/unknown")"
    sed -i.bak 's/^Status: .*$/Status: mothballed/' "$v"
    sed -i.bak2 's/^## Answer$/## Where this landed/' "$v"
    expect UNKNOWN "$CTL/unknown" "a ticket whose Status no check recognises"
    case "$(control "$CTL/unknown")" in
        *"04-"*"never write their answer"*)
            echo "SELF-TEST FAILED: the answerless ticket was still reported under NOANSWER,"
            echo "                  so this control did not build the exemption it claims to"
            st_fail=1 ;;
    esac

    # CONTROL G — a ticket answered twice. The second heading is added at LEVEL
    # ONE, because that is the form the defect actually took: twelve tickets had
    # a level-1 `# Answer` that check A does not look at, so the ENG-310 backfill
    # wrote them a second one and the gate went green over the duplication it
    # exists to remove.
    fresh "$CTL/double"
    printf '\n# Answer — resolved 2026-08-12\n\nA second answer, at the level check A does not read.\n' \
        >> "$(victim "$CTL/double")"
    expect DOUBLE "$CTL/double" "a ticket carrying two answer sections"

    # NEGATIVE CONTROL — the wayfinder directory as committed. A gate whose
    # controls all fire but which also rejects the real tree would be reverted
    # on its first run, so this half is not optional.
    fresh "$CTL/clean"
    if CHECK_DECISIONS_DIR="$CTL/clean" "${BASH_SOURCE[0]}" > /dev/null 2>&1; then :; else
        echo "SELF-TEST FAILED: the wayfinder tree as committed was rejected, so this"
        echo "                  gate would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the unanswered ticket, the empty answer, the delegated"
        echo "           answer, the unindexed ticket, the dangling amendment, the"
        echo "           unreadable Status and the twice-answered ticket; accepted the"
        echo "           committed tree — it discriminates"
        exit 0
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# The checks. Parsing lives in python3 because the units are markdown heading
# levels and top-level list-item extents, which awk can be made to do and
# cannot be made to do readably. `bin/check-toolchain.sh` set the precedent.
# ---------------------------------------------------------------------------
python3 - "$WAYFINDER" "$WORD_FLOOR" <<'PY'
import os, re, sys

wayfinder, floor = sys.argv[1], int(sys.argv[2])
issues = os.path.join(wayfinder, 'issues')

# --- read the tickets ------------------------------------------------------
tickets = {}                       # number -> (filename, text)
for fn in sorted(os.listdir(issues)):
    if not fn.endswith('.md'):
        continue
    m = re.match(r'(\d+)-', fn)
    if m:
        tickets[m.group(1)] = (fn, open(os.path.join(issues, fn)).read())

def status_para(text):
    """The Status: line and any continuation up to the next blank line."""
    lines = text.split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^\s*(?:\*\*)?Status(?:\*\*)?\s*:', l):
            out = [l]
            for nxt in lines[i + 1:]:
                if not nxt.strip():
                    break
                if re.match(r'^\s*(?:\*\*)?[A-Z][A-Za-z ]{2,24}(?:\*\*)?\s*:', nxt):
                    break
                out.append(nxt)
            return '\n'.join(out)
    return ''

resolved = {n: v for n, v in tickets.items()
            if re.search(r'resolved', status_para(v[1]), re.I)}

def answer_block(text):
    """(heading, body-lines) for the first level-2 heading that IS `## Answer`.

    The heading may carry a trailing gloss after an em-dash — 14 tickets date
    it that way and the date is real information — but the field is the first
    word, and a level-3 heading is a sub-heading of some other section rather
    than the answer itself."""
    lines = text.split('\n')
    for i, l in enumerate(lines):
        if re.match(r'^##[ \t]+answer\s*($|[—\-(:])', l.strip(), re.I):
            body = []
            for nxt in lines[i + 1:]:
                if re.match(r'^#{1,2}[ \t]', nxt):
                    break
                body.append(nxt)
            return l.strip(), body
    return None, None

# --- decisions.md entries --------------------------------------------------
dec = open(os.path.join(wayfinder, 'decisions.md')).read().split('\n')
starts = [i for i, l in enumerate(dec) if l.startswith('- ')]
named = set()
for k, i in enumerate(starts):
    end = starts[k + 1] if k + 1 < len(starts) else len(dec)
    body = '\n'.join(dec[i:end])
    m = re.search(r'issues/(\d+)-', body)
    if m:
        named.add(m.group(1))

fail = 0

def report(marker, ok_msg, rows, hint):
    global fail
    if not rows:
        print('  %-11s %s' % ('ok', ok_msg))
        return
    print('  %-11s %s' % (marker, hint))
    for r in rows:
        print('              ' + r)
    fail = 1

# --- A. every resolved ticket has an answer heading ------------------------
no_answer, thin = [], []
for n, (fn, text) in sorted(resolved.items(), key=lambda x: int(x[0])):
    head, body = answer_block(text)
    if head is None:
        no_answer.append('%-5s %s' % ('#' + n, fn))
        continue
    words = len(' '.join(body).split())
    if words < floor:
        thin.append('%-5s %s — %d words under %s' % ('#' + n, fn, words, head))

report('NOANSWER', 'every resolved ticket carries a `## Answer` heading',
       no_answer,
       'these resolved tickets never write their answer down:')

# --- B. and it says something ----------------------------------------------
report('THIN', 'every answer block is over the %d-word floor' % floor, thin,
       'these answer headings have (almost) nothing under them:')

# --- C. no ticket delegates its answer to decisions.md ---------------------
delegated = []
for n, (fn, text) in sorted(resolved.items(), key=lambda x: int(x[0])):
    if re.search(r'decisions\.md', status_para(text)):
        delegated.append('%-5s %s' % ('#' + n, fn))

report('DELEGATED', 'no ticket sends its reader to decisions.md for the answer',
       delegated,
       'these tickets delegate their own answer to decisions.md:')

# --- D. decisions.md names every resolved ticket ---------------------------
missing = ['%-5s %s' % ('#' + n, resolved[n][0])
           for n in sorted(set(resolved) - named, key=int)]
report('NOENTRY', 'decisions.md names every resolved ticket', missing,
       'decisions.md has no entry for these resolved tickets:')

# --- E. every Amends: relation resolves ------------------------------------
dangling = []
for n, (fn, text) in sorted(tickets.items(), key=lambda x: int(x[0])):
    for line in re.findall(r'^Amends:.*$', text, re.M):
        for t in re.findall(r'\b(\d{1,3})\b', line):
            if t not in tickets:
                dangling.append('%-5s %s — Amends: ticket %s, which has no file'
                                % ('#' + n, fn, t))

report('DANGLING', 'every `Amends:` relation resolves to a ticket that exists',
       dangling,
       'these amendment relations point at nothing:')

# --- F. every Status is a word the checks above recognise ------------------
# Selection by Status means an unrecognised word is an EXEMPTION, not a
# failure. This check is what stops the five above from passing on a ticket
# they never looked at.
VOCAB = ('resolved', 'open', 'claimed')
unknown = []
for n, (fn, text) in sorted(tickets.items(), key=lambda x: int(x[0])):
    para = status_para(text)
    if not para:
        unknown.append('%-5s %s — no Status line at all' % ('#' + n, fn))
    elif not any(re.search(w, para, re.I) for w in VOCAB):
        first = para.split('\n')[0].strip()
        unknown.append('%-5s %s — %s' % ('#' + n, fn, first[:58]))

report('UNKNOWN', 'every ticket Status is one of: %s' % ', '.join(VOCAB), unknown,
       'these tickets carry a Status no check recognises, so nothing examined them:')

# --- G. exactly one answer heading, counting level 1 too -------------------
# Check A looks for a LEVEL-2 heading, so a ticket answered under a level-1
# `# Answer` reads as unanswered — which is how the ENG-310 backfill came to
# add a second answer section to twelve tickets that already had one. Two
# answer sections is the duplication this whole issue exists to remove, and it
# is invisible to a check that stops at the first match.
ANY_ANSWER = re.compile(r'^#{1,2}[ \t]+answer\s*($|[—\-(:])', re.I)
doubled = []
for n, (fn, text) in sorted(resolved.items(), key=lambda x: int(x[0])):
    hits = [l.strip() for l in text.split('\n') if ANY_ANSWER.match(l.strip())]
    if len(hits) > 1:
        doubled.append('%-5s %s — %d answer headings: %s'
                       % ('#' + n, fn, len(hits),
                          ' / '.join(h[:34] for h in hits)))

report('DOUBLE', 'no ticket carries a second answer section', doubled,
       'these tickets answer themselves twice:')

if fail:
    print()
    print('  A resolved ticket owns its answer. decisions.md is the cross-ticket')
    print('  view of those answers, not the only copy of any of them — see ENG-310.')
    sys.exit(1)

print('  %d resolved tickets, each with its own answer and an entry that names it'
      % len(resolved))
PY
