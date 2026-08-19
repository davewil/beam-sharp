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
# BOTH OF THESE ARE ABSOLUTE BEFORE THE `cd`, and the second one is why. This
# script changes directory to `compiler/`, so a later `"$0"` — still the
# relative path it was invoked with — resolves against the wrong directory. The
# self-test below re-invokes this script, and with a relative `$0` every control
# failed, negative control included, which reads as a broken gate rather than a
# broken harness.
SELF="$(cd "$(dirname "$0")/.." && pwd)"
SELF_SH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$SELF"

# `CHECK_DIAGNOSTICS_SRC` exists for the self-test below and names a copy of
# `src/` with one defect introduced. Nothing else sets it; unset, this reads the
# real sources exactly as before, from the same directory it always did.
SRC="${CHECK_DIAGNOSTICS_SRC:-src}"

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR CONTROLS, because this gate makes four separate claims and the one it
# exists for is the one a lazy control would skip.
#
# THAT ONE IS THE STRAY. F16 moved 56 `io:format` calls into `bs_diag`, and the
# drift reopens SILENTLY: the next person to add a diagnostic writes the
# `io:format` at the site that found the problem, every test still passes,
# because the PROSE is right — there is no failing assertion anywhere, only a
# term that no longer describes what the compiler said. A control for that is
# the whole reason to have one here.
#
# The other three are the two directions of the tag/message correspondence and
# the delegation of the call sites. Each red must carry its own sentence; they
# all print `ERROR:` and would otherwise stand in for one another.
#
# The controls copy the real `src/`, because check 2 diffs the actual minted and
# rendered tag sets and a fixture module would compare two empty lists.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1, and `pipefail`
    # would report that status even when the sentence was found.
    control() {
        CHECK_DIAGNOSTICS_SRC="$1" "$SELF_SH" 2>&1 || true
    }
    fresh() { rm -rf "$1"; cp -R "$SELF/src" "$1"; }

    st_fail=0
    expect() {   # expect <sentence> <dir> <what the control built>
        case "$(control "$2")" in
            *"$1"*) ;;
            *) echo "SELF-TEST FAILED: $3 was not reported"
               st_fail=1 ;;
        esac
    }

    # CONTROL 1 — a diagnostic written where the problem was found. This is the
    # exact shape F16 removed, put back in a module that is not `bs_diag`.
    #
    # SINGLE TILDES. `~` is nothing special to `printf`, so the first draft's
    # `~~s:~~p:` landed in the file literally doubled — which is not the defect
    # shape, so the gate correctly ignored it and the control reported "cannot
    # fire" against a check that works. A control that does not build the defect
    # it names tests nothing but itself.
    fresh "$CTL/stray"
    printf '\nstray_report(F, L) ->\n    io:format(standard_error, "~s:~p: error: nope~n", [F, L]).\n' \
        >> "$CTL/stray/bs_check.erl"
    expect "a diagnostic is formatted outside bs_diag.erl" "$CTL/stray" \
        "a diagnostic formatted outside bs_diag"

    # CONTROL 2 — a tag minted with no clause to render it. Left alone this
    # crashes at the moment the diagnostic is reported, which is intended
    # behaviour and exactly why nothing else would catch it first.
    fresh "$CTL/unrendered"
    printf '\n%%%% self-test control\n%%%% tag => never_rendered\n' \
        >> "$CTL/unrendered/bs_diag.erl"
    expect "descriptor/2 mints tags that message/1 cannot render" "$CTL/unrendered" \
        "a minted tag with no message clause"

    # CONTROL 3 — the other direction: prose nothing can produce, which reads as
    # a supported diagnostic to anyone grepping for one.
    fresh "$CTL/orphan"
    printf '\n%%%% self-test control\n%%%% #{tag := never_minted\n' \
        >> "$CTL/orphan/bs_diag.erl"
    expect "message/1 renders tags descriptor/2 never mints" "$CTL/orphan" \
        "a rendered tag nothing mints"

    # CONTROL 4 — the call site stops delegating.
    fresh "$CTL/undelegated"
    sed -i.bak 's/bs_diag:emit/bs_diag_emit_removed/g' "$CTL/undelegated/bsc.erl"
    rm -f "$CTL/undelegated/bsc.erl.bak"
    expect "bsc.erl no longer reports through bs_diag" "$CTL/undelegated" \
        "a call site that stopped delegating"

    # NEGATIVE CONTROL — the sources as committed.
    fresh "$CTL/clean"
    if CHECK_DIAGNOSTICS_SRC="$CTL/clean" "$SELF_SH" > /dev/null 2>&1; then :; else
        echo "SELF-TEST FAILED: the sources as committed were rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the stray diagnostic, the unrenderable tag, the"
        echo "           orphaned message and the broken delegation; accepted the"
        echo "           committed sources — the gate discriminates"
        exit 0
    fi
    exit 1
fi

fail=0
say() { printf '%s\n' "$*"; }

# --- 1. No diagnostic-shaped message outside bs_diag -------------------------

say "==> diagnostics are written in one place"
strays=$(grep -rn '~s:~p: \(error\|warning\):' "$SRC"/ --include='*.erl' \
             | grep -v "^$SRC/bs_diag\.erl:" || true)
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
minted=$(grep -o 'tag => [a-z_]*' "$SRC"/bs_diag.erl | sed 's/tag => //' | sort -u)
rendered=$(grep -o '#{tag := [a-z_]*' "$SRC"/bs_diag.erl | sed 's/#{tag := //' | sort -u)

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
if grep -q 'bs_diag:emit' "$SRC"/bsc.erl && grep -q 'bs_diag:descriptor' "$SRC"/bsc.erl; then
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
