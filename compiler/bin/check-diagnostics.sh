#!/usr/bin/env bash
#
# The diagnostic is a term, and prose is a pure function of it (ticket 23 §1).
#
# WHY THIS EXISTS
# F16 moved 56 `io:format` calls out of `bsc.erl` and into `bs_diag`, so that
# every message the compiler can print is derived from a descriptor rather than
# written beside one. The drift that closes REOPENS SILENTLY: the next person to
# add a diagnostic can write `io:format(standard_error, "~s:~p: error: ...")` at
# the site that found the problem, and every test in the suite will still pass,
# because the prose will be right. There is no failing assertion to notice —
# only a term that no longer describes what the compiler said.
#
# That is the failure this repo has now found four times in four features (F11,
# F12, F14, F15) in its other form: a gate that reports something without
# looking at the thing. This one is pointed at the thing.
#
# WHAT IT CHECKS
#   1. NO DIAGNOSTIC-SHAPED MESSAGE OUTSIDE `bs_diag.erl`. The test is the shape
#      of the format string, not the call: a diagnostic names a source location,
#      so `~s:~p: error:` and `~s:~p: warning:` are its signature. This is
#      deliberately narrower than "no `io:format(standard_error, ...)` outside
#      bs_diag", which would be wrong — see the allowlist below.
#   2. EVERY TAG `descriptor/2` MINTS HAS A `message/1` CLAUSE. A tag with none
#      crashes at the moment it is reported. That is intended and is why
#      `message/1` has no generic catch-all: a renderer that could always print
#      *something* would let a new diagnostic ship looking like it had a message.
#   3. THE TWO CALL SITES STILL DELEGATE. `bsc:publish/2` must reach `bs_diag`.
#
# WHAT IS DELIBERATELY ALLOWED, AND WHY
# These write to stderr and are NOT diagnostics. Every one of them is about the
# invocation or the runtime, never about the source being compiled, and none can
# name a file and a line:
#
#   bsc.erl    usage text; `--diagnostics` given a bad value; `is a namespace,
#              not a module`; `cannot run more than one file`; `which function?`
#              and its neighbours — all about what you TYPED, and what they hand
#              back is a different command rather than a clause to write, which
#              is ticket 23 §4's own membership test.
#   bsc.erl    `crashed: ...` — a RUNNING program died. Ticket 23 §6 puts the
#              structured form of that on `error_info` in emitted code, which is
#              a separate decision with a size cost, and F16 does not build it.
#   bsc.erl    `erlc: ...` — erlc's own output, passed through verbatim. Wrapping
#              it would be claiming authorship of a message we did not write.
#   bs_repl.erl  the REPL's own echo. It renders messages the compiler already
#              produced; it does not produce any.
#
# An exclusion carries its reason, per the rule in `.github/workflows/ci.yml`.

set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
say() { printf '%s\n' "$*"; }

# --- 1. No diagnostic-shaped message outside bs_diag -------------------------

say "==> diagnostics are written in one place"
strays=$(grep -rn '~s:~p: \(error\|warning\):' src/ --include='*.erl' \
             | grep -v '^src/bs_diag\.erl:' || true)
if [ -n "$strays" ]; then
    say "ERROR: a diagnostic is formatted outside bs_diag.erl:"
    say "$strays"
    say ""
    say "  A message that names a file and a line is a diagnostic, and a"
    say "  diagnostic is a term first (ticket 23 §1). Add a descriptor/2 clause"
    say "  and a message/1 clause in bs_diag.erl instead, so the term and the"
    say "  prose cannot drift."
    fail=1
else
    say '    ok — no file:line-shaped message outside bs_diag.erl'
fi

# --- 2. Every minted tag has a message clause --------------------------------

say "==> every tag the compiler mints can be rendered"
minted=$(grep -o 'tag => [a-z_]*' src/bs_diag.erl | sed 's/tag => //' | sort -u)
rendered=$(grep -o '#{tag := [a-z_]*' src/bs_diag.erl | sed 's/#{tag := //' | sort -u)

missing=$(comm -23 <(printf '%s\n' "$minted") <(printf '%s\n' "$rendered"))
if [ -n "$missing" ]; then
    say "ERROR: descriptor/2 mints tags that message/1 cannot render:"
    # The split is deliberate: one tag per line, each indented. Quoting would
    # print the whole list as a single argument and indent only the first line.
    # shellcheck disable=SC2086
    printf '      %s\n' $missing
    say ""
    say "  message/1 has no catch-all on purpose, so this crashes at the moment"
    say "  the diagnostic is reported rather than printing something generic."
    fail=1
fi

# The other direction is a real defect too: a message nothing can produce is
# dead prose, and it reads as a supported diagnostic to anyone grepping for one.
orphaned=$(comm -13 <(printf '%s\n' "$minted") <(printf '%s\n' "$rendered"))
if [ -n "$orphaned" ]; then
    say "ERROR: message/1 renders tags descriptor/2 never mints:"
    # Deliberate split, as above.
    # shellcheck disable=SC2086
    printf '      %s\n' $orphaned
    fail=1
fi

if [ -z "$missing" ] && [ -z "$orphaned" ]; then
    say "    ok — $(printf '%s\n' "$minted" | grep -c .) tags, minted and rendered"
fi

# --- 3. The call sites still delegate ----------------------------------------

say "==> bsc reports through bs_diag"
if grep -q 'bs_diag:emit' src/bsc.erl && grep -q 'bs_diag:descriptor' src/bsc.erl; then
    say "    ok — bsc:publish/2 reaches bs_diag"
else
    say "ERROR: bsc.erl no longer reports through bs_diag."
    fail=1
fi

say ""
if [ "$fail" -eq 0 ]; then
    say "diagnostics: ok"
else
    say "diagnostics: FAILED"
fi
exit "$fail"
