#!/usr/bin/env python3
"""Regenerate PACKET.md from LANGUAGE.md.

The packet is BUILT rather than maintained, for the same reason `expected/` is
recorded rather than typed: a hand-edited copy of the specification drifts from
the specification, and the whole exercise is a test of the specification.

Run from anywhere:  python3 handoff/audition-switch/build-packet.py
"""

import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

lang = io.open(os.path.join(REPO, "LANGUAGE.md"), encoding="utf-8").read().splitlines()


def section(n):
    """Extract '## n. ...' up to the next '## ', verbatim."""
    start = None
    for i, line in enumerate(lang):
        if re.match(r"^## %d\. " % n, line):
            start = i
            break
    if start is None:
        raise SystemExit("LANGUAGE.md has no section %d — the packet cannot be built" % n)
    for j in range(start + 1, len(lang)):
        if lang[j].startswith("## "):
            return "\n".join(lang[start:j]).rstrip()
    return "\n".join(lang[start:]).rstrip()


# THE TAG LIST NAMES THE TAGS AND DOES NOT DEFINE THEM.
#
# The first version of this packet carried a table explaining what each tag
# meant — "an arm's pattern binds a name that is already bound in the enclosing
# clause" and so on. That is the RULE, and putting the rule in the marking
# scheme let a candidate read the answer off the mark sheet instead of deriving
# it from the specification. The audition measures whether the specification is
# sufficient; anything the specification is supposed to convey must not be
# restated here.
#
# The names are still given, because the comparison is machine-made and needs a
# shared vocabulary. A name is not a definition.
BRIEF = """# Audition packet — the exhaustiveness checker

You are implementing one piece of a programming language toolchain FROM ITS
SPECIFICATION ALONE. This is a clean-room exercise: a reference implementation
exists, and you must not look at it.

## Hard rules

- **Do not read, search for, or open any file outside this packet directory.**
  A reference implementation of this language exists elsewhere on this machine,
  as does a directory of design notes. Both are off limits. If you find
  yourself looking for either, stop.
- Do not modify anything under `cases/`.
- Work only inside your own working directory.
- Work autonomously. There is nobody to answer questions.

## What you are building

A command-line program that decides whether a `switch` is well-formed and
reports the problems it finds.

Deliverable: an executable file named `switchcheck` in your working directory:

    ./switchcheck <path-to-.bs-file>

Any language available on the machine is fine, provided `./switchcheck` runs
directly via a shebang. No network access, no package installs.

## Output contract

For the file it is given, `switchcheck` prints **one lowercase tag per line** on
stdout and nothing else — no prose, no filenames, no line numbers. A well-formed
program prints **nothing at all**.

These are the only tags you may print:

    switch_inexhaustive
    unreachable_arm
    rebinding
    return_not_declared

**What each of those means is for you to determine from the specification
below.** The names are listed so that your output can be compared
mechanically — they are a vocabulary, not a definition of the rules.

The specification describes **more diagnostics than this exercise marks**. It is
the language reference, not a task sheet, and it is given to you whole rather
than filtered so that nothing it says is missing a reason. Where it describes a
diagnostic that is not in the list above, that rule is still true of the
language and no file you are given violates it — say nothing about it. Printing
a tag outside the list fails a case exactly as a wrong tag would.

Exit code is ignored. Order does not matter and duplicates are ignored; only
the set of tags is compared.

## How you are marked

Your `switchcheck` is run over the files in `cases/` and the tags it prints are
compared against the tags the reference compiler produces for the same file.
**Every case must match exactly.**

Some of the files are well-formed and must produce no output at all. Printing a
diagnostic for a correct program fails exactly as hard as missing one, so do not
guess defensively: a checker that reports a problem whenever it is unsure fails
on the first case. Test against `cases/` before you finish.

## The specification

What follows is the relevant part of the language reference, verbatim. It is all
you get, and it is meant to be enough. Where it is not enough, prefer the
reading the text best supports rather than inventing a rule.

---

"""

body = "\n\n---\n\n".join([section(2), section(3), section(5)])

# Strip every HTML comment except the `check:` ones. A `<!-- decided by ticket
# NN -->` is a pointer into design notes the clean-room implementer does not
# receive — a dangling reference, and an invitation to go looking for the one
# directory the packet forbids. The `<!-- check: ... -->` blocks are the
# opposite: they carry type declarations the examples below them need, and
# removing them would leave code referring to types out of nowhere.
#
# THIS USED TO STRIP ONLY `decided by`, AND THE REST SHIPPED. An HTML comment is
# invisible in RENDERED Markdown; the worker receives this file as text and
# reads every byte of it. Two things were reaching candidates as a result:
#
#   - §5's note on the guard example named the audition directory, the round and
#     the date, and said outright that three candidates had reproduced the
#     illustration instead of the rule. That is a pointer to the forbidden
#     directory AND the answer to the case it describes.
#   - the `<!-- diagnoses: tag -->` preambles (ENG-248) label each example in §5
#     with the exact tag it provokes, which is the mark sheet printed beside the
#     question. `check-language.sh` needs them; the worker must not have them.
#
# Non-greedy and DOTALL because these comments span lines; anchored at line
# start so an inline comment inside an example is left alone.
body = re.sub(r"^<!--(?!\s*check:).*?-->\n", "", body, flags=re.M | re.S)

out = os.path.join(HERE, "PACKET.md")
content = BRIEF + body + "\n"

leaks = [t for t in ("switch_inexhaustive", "unreachable_arm", "rebinding", "return_not_declared")
         if re.search(r"`%s`\s*\|" % t, BRIEF)]
if leaks:
    raise SystemExit("the brief defines tags it should only name: %s" % ", ".join(leaks))

# `--check` — IS THE COMMITTED PACKET WHAT THIS SCRIPT WOULD WRITE TODAY?
#
# The packet is built rather than maintained so that it cannot drift from the
# specification, and until ENG-248 nothing verified that the BUILT file had been
# rebuilt. An edit to §2, §3 or §5 left `PACKET.md` describing the language as it
# was, silently, which is the same defect the generator exists to prevent — one
# step later in the pipeline. `check-switch-diagnostics.sh` calls this, because
# its own claim is that every switch diagnostic is documented WHERE THE WORKER
# WILL SEE IT, and a stale packet makes that claim false.
if "--check" in sys.argv:
    if not os.path.exists(out):
        raise SystemExit("PACKET.md does not exist — run `python3 %s`" % __file__)
    if io.open(out, encoding="utf-8").read() != content:
        raise SystemExit(
            "PACKET.md is STALE: it is not what LANGUAGE.md sections 2, 3 and 5\n"
            "would produce today. Regenerate it:\n"
            "    python3 %s" % __file__)
    print("PACKET.md is current with LANGUAGE.md sections 2, 3 and 5")
else:
    io.open(out, "w", encoding="utf-8").write(content)
    print("wrote %s" % out)
    print("sections 2, 3, 5 — %d lines" % (BRIEF.count("\n") + body.count("\n") + 2))
