#!/usr/bin/env python3
"""gen-decisions.py — assemble wayfinder/decisions.md from the tickets.

WHY THIS EXISTS (2026-09-04, ENG-310 stage 2)

ENG-310 chose derive-after-backfill. Stage 1 (`38acb27`) made every resolved
ticket carry a `## Answer`, so the ANSWER has a single spelling in a single
place. This is stage 2: `decisions.md` stops being hand-kept and becomes
assembled, so it cannot drift from the tickets it summarises.

WHAT MADE THIS HARDER THAN "GENERATE FROM THE ANSWER BLOCK". The obvious
derive — emit each ticket's answer, or the lead of it — does not work, and the
measurement that killed it is worth keeping:

  * Only 42% of decisions.md's 6-grams appear anywhere in their own ticket.
    Bimodal: twelve entries sit at 57-95% (stage 1 relocated those answers out
    of decisions.md, so the words are shared), and forty-five sit at 0-37% —
    prose that exists nowhere else in the repository. There is no source to
    generate those from.
  * Nor is the entry the answer's opening. Across the twelve high-overlap
    tickets the entry's words are spread through the whole answer — 25-45% in
    its first two fifths, 13-72% in the rest. The entry is a CONDENSATION of
    the answer, not a prefix of it, so it cannot be extracted by taking a lead.

So the entry is its own artefact and its home is the ticket. Each ticket owns
its entry verbatim in a `decisions-entry` fenced block, and this script emits
ONE LINE per entry — the headline and the first sentence — in the order
`decisions.order` records. The whole entry is read in the ticket.

WHY ONE LINE (2026-09-05). The first version of this script emitted every
block whole, and decisions.md stayed at 1,910 lines: generated, drift-proof,
and exactly as unreadable as before. ENG-310 exists because the corpus is too
big to read, and its acceptance test — "was X decided, and where" in a few
hundred lines — was the one thing two stages under that issue had not built.
David: "a massive fail of the goal." `bin/check-decisions-size.sh` is that test
now, and at one line per entry the file is ~80 lines. The file's own header
comment had promised "one line per closed ticket" since the 2026-08-15 split.

WHY VERBATIM, AND WHY FENCED. The entries are not uniform enough to hold as
fields — most open `- [Headline](issues/NN-slug.md) — …`, but ticket 16's two
amendments open `- **AMENDMENT <date> to [ticket 16](…)** — …` instead. Storing
a headline and a body and re-assembling the prefix would have to reproduce
three shapes exactly to stay byte-identical; storing the rendered line
reproduces them by construction. It is fenced because that `issues/…` link is
relative to decisions.md and would be wrong from inside `issues/` — a fence
makes it inert text rather than a broken link.

WHY AN ORDER FILE. decisions.md's order is curated, not numeric: it opens 00,
03, 19, 01, 21, 08. It is not map.md's order either — of the 59 subjects with an
entry here, map.md indexes 50 under "Decisions so far", files eight (63, 37, 49,
47, 67, 50, 56, 58) under "Not yet specified" although their decision is
written, and does not tag the walking skeleton at all. That curation is
information, so it is recorded rather than recomputed.

WHAT GUARDS THE MANIFEST, precisely, because a wrong sentence here is worse
than none. Three mechanisms with three exit codes:

  * a manifest line for a ticket whose entry block is missing — this script
    exits 2 naming the file, because it will not emit a short file quietly;
  * a manifest line deleted — the entry vanishes from decisions.md, which
    `check-decisions-derived.sh` sees as drift before regeneration and
    `check-decisions.sh`'s NOENTRY sees after it, since NOENTRY requires
    decisions.md to name every RESOLVED ticket;
  * a newly resolved ticket with neither block nor manifest line — NOENTRY,
    which reads the resolved set from Status rather than from this manifest.

The gap that leaves: `skeleton` is not a resolved ticket, so NOENTRY does not
guard it. Delete that one line after regenerating and nothing here objects.

Usage:
  bin/gen-decisions.py --check    exit 1 and print a diff if decisions.md has
                                  drifted from the tickets
  bin/gen-decisions.py --write    regenerate decisions.md in place
"""

import argparse
import difflib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BEGIN = '<!-- BEGIN GENERATED — bin/gen-decisions.py; edit the ticket, not this file -->'
END = '<!-- END GENERATED -->'

# The one entry whose subject is not a ticket. The walking skeleton is tracked
# on the map as `#skeleton` and has no file in issues/, so its entry lives in
# the file it links to. Every other key in the manifest is a ticket number.
NAMED_SOURCES = {'skeleton': 'compiler/README.md'}

FENCE_OPEN = re.compile(r'^```decisions-entry\s*$')
FENCE_CLOSE = re.compile(r'^```\s*$')


def die(msg):
    print('gen-decisions: %s' % msg, file=sys.stderr)
    sys.exit(2)


def ticket_paths(wayfinder):
    """number -> path, for every ticket file in issues/."""
    issues = os.path.join(wayfinder, 'issues')
    out = {}
    for fn in sorted(os.listdir(issues)):
        m = re.match(r'(\d+)-', fn)
        if fn.endswith('.md') and m:
            out[m.group(1)] = os.path.join(issues, fn)
    return out


def entry_blocks(path):
    """Every `decisions-entry` fenced block in a file, in file order.

    Returns a list of block bodies, each a list of lines with the fence
    removed and nothing else touched."""
    if not os.path.exists(path):
        return []
    lines = open(path).read().split('\n')
    blocks, cur = [], None
    for line in lines:
        if cur is None:
            if FENCE_OPEN.match(line):
                cur = []
        else:
            if FENCE_CLOSE.match(line):
                blocks.append(cur)
                cur = None
            else:
                cur.append(line)
    if cur is not None:
        die('%s: an unterminated ```decisions-entry block' % path)
    return blocks


def read_manifest(wayfinder):
    """The curated order, as a list of (key, slot) pairs."""
    path = os.path.join(wayfinder, 'decisions.order')
    if not os.path.exists(path):
        die('no decisions.order at %s' % path)
    out = []
    for raw in open(path):
        line = raw.split('#', 1)[0].strip()
        if not line:
            continue
        if ':' in line:
            key, slot = line.split(':', 1)
            if not slot.isdigit():
                die('decisions.order: bad slot in %r' % line)
            out.append((key.strip(), int(slot)))
        else:
            out.append((line, 1))
    return out


def assemble(wayfinder):
    """The generated region of decisions.md, as a list of lines."""
    manifest = read_manifest(wayfinder)
    tickets = ticket_paths(wayfinder)
    # Sibling of the wayfinder directory, not the repository root, so the
    # --self-test can drive this over a copied tree rather than over a second
    # copy of this logic.
    base = os.path.dirname(os.path.abspath(wayfinder))
    cache = {}
    body = []
    for key, slot in manifest:
        if key in NAMED_SOURCES:
            path = os.path.join(base, NAMED_SOURCES[key])
        elif key in tickets:
            path = tickets[key]
        else:
            die('decisions.order names %r, which has no ticket file' % key)
        if path not in cache:
            cache[path] = entry_blocks(path)
        blocks = cache[path]
        if len(blocks) < slot:
            rel = os.path.relpath(path, base)
            die('%s has %d decisions-entry block(s); decisions.order asks for #%d'
                % (rel, len(blocks), slot))
        block = list(blocks[slot - 1])
        while block and not block[-1].strip():
            block.pop()
        if not block:
            die('%s: decisions-entry block #%d is empty' % (path, slot))
        body.append(lead(block, path, slot))
    return body


# The lead is the headline plus the first sentence of the body. A sentence ends
# at `.`, `!` or `?` followed by whitespace and something that starts a new
# one — a capital, an opening bracket, emphasis or code. That last clause is
# what stops `e.g. the` and `OTP 28. five` splitting early; it is a heuristic,
# and an entry whose first sentence reads badly is fixed by editing its block
# in the ticket, not by teaching this function more grammar.
HEADLINE = re.compile(r'^- (\[[^\]]*\]\([^)]*\)|\*\*.*?\*\*)\s*[—–-]+\s*(.*)$', re.S)
SENTENCE_END = re.compile(r'[.!?][)*_`]*(?=\s+[A-Z(\[*_`"])')


def lead(block, path, slot):
    """`- [Headline](link) — first sentence.` on one line."""
    para = ' '.join(l.strip() for l in block if l.strip())
    m = HEADLINE.match(para)
    if not m:
        die('%s: decisions-entry block #%d does not open `- [headline](link) — `'
            ' or `- **headline** — `' % (path, slot))
    head, rest = m.group(1), m.group(2)
    end = SENTENCE_END.search(rest)
    first = rest[:end.end()] if end else rest
    return '- %s — %s' % (head, first.strip())


def current(decisions):
    """(preamble, generated-region, tail) of the committed decisions.md."""
    lines = open(decisions).read().split('\n')
    try:
        b = lines.index(BEGIN)
        e = lines.index(END)
    except ValueError:
        return None, None, None
    return lines[:b + 1], lines[b + 1:e], lines[e:]


def render(decisions, wayfinder):
    head, _, tail = current(decisions)
    if head is None:
        die('decisions.md carries no BEGIN/END GENERATED markers — this file '
            'assembles that region and will not guess where it starts')
    return '\n'.join(head + assemble(wayfinder) + tail)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--wayfinder', default=os.path.join(ROOT, 'wayfinder'))
    args = ap.parse_args()
    if args.check == args.write:
        die('pass exactly one of --check or --write')

    decisions = os.path.join(args.wayfinder, 'decisions.md')
    if not os.path.exists(decisions):
        die('no decisions.md at %s' % decisions)

    want = render(decisions, args.wayfinder)
    have = open(decisions).read()

    if args.write:
        if want != have:
            open(decisions, 'w').write(want)
            print('gen-decisions: rewrote %s' % os.path.relpath(decisions, ROOT))
        else:
            print('gen-decisions: %s already current' % os.path.relpath(decisions, ROOT))
        return

    if want == have:
        n = len(read_manifest(args.wayfinder))
        print('  %-11s decisions.md is exactly its %d entries, assembled' % ('ok', n))
        return

    diff = list(difflib.unified_diff(
        have.split('\n'), want.split('\n'),
        fromfile='wayfinder/decisions.md (committed)',
        tofile='wayfinder/decisions.md (assembled from the tickets)',
        lineterm='', n=1))
    print('  %-11s %s' % ('DRIFT', 'decisions.md is not what the tickets say it should be:'))
    for line in diff[:60]:
        print('              ' + line)
    if len(diff) > 60:
        print('              … %d more diff lines' % (len(diff) - 60))
    print()
    print('  decisions.md is GENERATED. Edit the entry in its ticket and run')
    print('  bin/gen-decisions.py --write. See ENG-310.')
    sys.exit(1)


if __name__ == '__main__':
    main()
