#!/usr/bin/env bash
#
# Every `.bs` file the compiler accepts must also parse with the Tree-sitter
# grammar, with no ERROR node.
#
# WHY THIS IS THE GATE THAT MATTERS
# `check-tokens.sh` catches a keyword nobody added to a grammar. It cannot catch
# a rule that is present and WRONG, and a Tree-sitter grammar is a whole second
# parser for the language -- so the only honest check is to run it over the same
# corpus the compiler runs over. `compiler/examples/` is the "must run" surface,
# so it is the right corpus: if bsc compiles it, this must parse it.
#
# NOT CHECKED HERE: `examples/exemplars/`. Those are the compiler's target, not
# its test suite, and they do not parse with `bsc` either -- they are written on
# the other side of two documented forks (the bare clause head, and
# `[module: GenServer]`). Holding this grammar to them would be holding it to a
# language the compiler does not implement.
#
# Usage:  editor/bin/check-corpus.sh

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SELF/.." && pwd)"
GRAMMAR="$SELF/tree-sitter-beam-sharp"
# `CHECK_CORPUS_DIR` exists for the self-test below and names the tree of `.bs`
# files to parse. Nothing else sets it; unset, this is the real corpus.
CORPUS="${CHECK_CORPUS_DIR:-$REPO/compiler/examples}"

# ---------------------------------------------------------------------------
# --self-test
#
# TWO CONTROLS, AND THE SECOND ONE FOUND A HOLE IN THIS GATE.
#
#   1. THE GRAMMAR REJECTS SOURCE THE COMPILER ACCEPTS. That is the claim, and
#      the control is a `.bs` file the Tree-sitter parser cannot parse.
#   2. THE CORPUS IS EMPTY. This gate's own header says "a gate that silently
#      stops checking is the failure this whole script was rewritten about" —
#      after a top-level glob matched nothing and the loop ran once on a
#      filename containing a `*`. But nothing checked the COUNT, so an empty
#      corpus ran the loop zero times, set no failure, and printed "every
#      example parses with no ERROR node". The control below required that to be
#      a failure, and the `EMPTY` check further down is what makes it one.
#
# A missing tree-sitter is a failure here rather than a skip. The gate itself
# still skips — that deviation is deliberate and recorded in `check-shell.sh` —
# but a self-test that "passes" without running its controls asserts the one
# thing it exists to disprove.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    if ! command -v tree-sitter >/dev/null 2>&1; then
        echo "SELF-TEST CANNOT RUN: tree-sitter CLI is not installed"
        echo "  npm i -g tree-sitter-cli   (ci.yml installs it before this step)"
        exit 1
    fi

    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1, and `pipefail`
    # would report that status even when the marker was found.
    control() {
        CHECK_CORPUS_DIR="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }

    st_fail=0

    # CONTROL 1 — one file the grammar cannot parse, beside a real one so the
    # control also shows the gate still reporting `ok` for what does parse.
    mkdir -p "$CTL/rejects/Wire"
    cp "$REPO/compiler/examples/Wire/wire.bs" "$CTL/rejects/Wire/wire.bs"
    mkdir -p "$CTL/rejects/Broken"
    printf 'module Broken\n\n@@@ this is not beam-sharp @@@\n' > "$CTL/rejects/Broken/broken.bs"
    case "$(control "$CTL/rejects")" in
        *ERROR*) ;;
        *) echo "SELF-TEST FAILED: a file the grammar cannot parse was not reported"
           st_fail=1 ;;
    esac

    # CONTROL 2 — nothing to check. Must be a failure, not a green run.
    mkdir -p "$CTL/empty"
    case "$(control "$CTL/empty")" in
        *EMPTY*) ;;
        *) echo "SELF-TEST FAILED: an empty corpus was accepted — this gate can report"
           echo "                  success while parsing nothing, which is the exact"
           echo "                  failure its own header was written about"
           st_fail=1 ;;
    esac

    # NEGATIVE CONTROL — the corpus as committed.
    if CHECK_CORPUS_DIR="$REPO/compiler/examples" "${BASH_SOURCE[0]}" >/dev/null 2>&1
    then :; else
        echo "SELF-TEST FAILED: the committed corpus was rejected, so this gate would"
        echo "                  fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: reported the unparseable file and refused the empty corpus;"
        echo "           accepted the committed one — the gate discriminates"
        exit 0
    fi
    exit 1
fi

if ! command -v tree-sitter >/dev/null 2>&1; then
    echo "tree-sitter CLI not found -- skipping (install: npm i -g tree-sitter-cli)"
    exit 0
fi

cd "$GRAMMAR"

# Regenerate first, so a grammar.js edit that was never generated fails here
# rather than passing against a stale parser.c.
tree-sitter generate >/dev/null

# F15 — RECURSIVE, because a module is a directory and there are no `.bs` files
# at the top level of `examples/` any more. A top-level glob matches nothing,
# and an unmatched glob in bash is passed through unexpanded — so this loop ran
# exactly once, on a filename with a `*` in it, and reported one ERROR for a file
# that does not exist while checking none of the ones that do. A gate that
# silently stops checking is the failure this whole script was rewritten about.
#
# `exemplars/` stays excluded for the reason in the header: they are the
# compiler's target and do not parse yet.
fail=0
seen=0
while IFS= read -r f; do
    seen=$((seen + 1))
    if tree-sitter parse -q "$f" >/dev/null 2>&1; then
        printf '  %-8s %s\n' "ok" "${f#"$REPO"/}"
    else
        printf '  %-8s %s\n' "ERROR" "${f#"$REPO"/}"
        # `|| true` because this pipeline ABORTED THE WHOLE GATE. Under
        # `pipefail`, `head -3` closing early gives `grep` a SIGPIPE, the
        # pipeline exits non-zero, and `set -e` kills the script at the FIRST
        # failing file. So a gate whose entire job is to list what the grammar
        # rejects was listing only the first one: `label.bs` was hiding four
        # more, and every one of them was a shipped feature the grammar had
        # never gained.
        tree-sitter parse "$f" 2>&1 | grep -F ERROR | head -3 | sed 's/^/           /' || true
        fail=1
    fi
done < <(find "$CORPUS" \
              -path "$CORPUS/exemplars" -prune -o \
              -name '*.bs' -print | sort)

# PARSING NOTHING IS NOT PASSING, and until the self-test above asked the
# question nothing here said so. The header already named this failure — a
# top-level glob matched nothing after F15 made a module a directory, and the
# loop ran once on a filename containing a `*` — but the repair was to the FIND,
# and a find that legitimately returns nothing produced a green run reporting
# that every example parsed. Zero examples, zero errors, success.
if [ "$seen" -eq 0 ]; then
    echo "  EMPTY    no .bs files under $CORPUS"
    echo "           this gate reports what it parsed, so parsing nothing is a"
    echo "           failure rather than a clean run."
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "$seen examples parse with no ERROR node"
else
    echo "the grammar rejects source the compiler accepts."
    exit 1
fi
