#!/usr/bin/env bash
#
# Every keyword the lexer defines must appear in both editor grammars.
#
# WHY THIS EXISTS
# `compiler/src/bs_lexer.xrl` is the source of truth for the surface's tokens,
# and the two grammars here are a hand-written second copy of part of it. This
# repo designs duplicate sources of truth away where it can -- `resolve/2` is
# exported so the checker and the emitter do not have two resolvers, and
# `qualified/2` is "THE SINGLE MINTING POINT" -- but a TextMate grammar cannot be
# derived from a leex file, so the copy is unavoidable and the drift is not.
#
# WHAT IT CHECKS, AND WHAT IT DOES NOT
# Keywords and the multi-character operators, which are what a new feature adds.
# It does NOT
# check that the grammars are CORRECT -- a rule can be present and wrong, and
# only looking at a coloured file catches that. F7 is the case in point: it added
# `switch`, `=>`, and the two keyword atoms, and this gate would have named all
# four.
#
# Usage:  editor/bin/check-tokens.sh

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# `CHECK_TOKENS_ROOT` exists for the self-test below and mirrors the three paths
# this gate reads. Nothing else sets it.
REPO="${CHECK_TOKENS_ROOT:-$(cd "$SELF/.." && pwd)}"
HERE="$REPO/editor"

LEXER="$REPO/compiler/src/bs_lexer.xrl"
TM="$HERE/vscode/syntaxes/beam-sharp.tmLanguage.json"
VIM="$HERE/nvim/syntax/bs.vim"

# ---------------------------------------------------------------------------
# --self-test
#
# TWO CONTROLS, ONE PER DIRECTION THIS GATE IS BLIND IN WITHOUT IT.
#
#   1. THE LEXER GAINS A KEYWORD THE GRAMMARS DO NOT HAVE. This is the real
#      failure mode and it has already happened: F7 added `switch`, `=>` and the
#      two keyword atoms, and `editor/` collected five features of drift before
#      this gate was wired in at all. Nothing in the editor breaks loudly when a
#      keyword goes uncoloured — it just quietly looks like an identifier.
#   2. A GRAMMAR LOSES AN OPERATOR. That list is hand-maintained, because the
#      operators are escaped regexes in the leex file rather than bare words, so
#      it is the half most likely to be edited by someone tidying a grammar.
#
# The controls copy the real lexer and the real grammars. A fixture grammar
# would contain whatever the control put in it and nothing else, which proves
# only that `grep` works.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # Captured, not piped: a control run is meant to exit 1, and `pipefail`
    # would report that status even when the marker was found.
    control() {
        CHECK_TOKENS_ROOT="$1" "${BASH_SOURCE[0]}" 2>&1 || true
    }
    fresh() {
        rm -rf "$1"
        mkdir -p "$1/compiler/src" "$1/editor/vscode/syntaxes" "$1/editor/nvim/syntax"
        cp "$SELF/../compiler/src/bs_lexer.xrl"                    "$1/compiler/src/"
        cp "$SELF/vscode/syntaxes/beam-sharp.tmLanguage.json"      "$1/editor/vscode/syntaxes/"
        cp "$SELF/nvim/syntax/bs.vim"                              "$1/editor/nvim/syntax/"
    }

    st_fail=0

    # CONTROL 1 — a keyword the lexer defines and neither grammar colours. The
    # rule is written in the leex shape this gate recognises, so it is picked up
    # the same way a real new keyword would be.
    fresh "$CTL/keyword"
    printf '\nunlessy                 : {token, {unlessy, TokenLine}}.\n' \
        >> "$CTL/keyword/compiler/src/bs_lexer.xrl"
    case "$(control "$CTL/keyword")" in
        *MISSING*unlessy*|*unlessy*MISSING*) ;;
        *) echo "SELF-TEST FAILED: a keyword the grammars do not have was not named —"
           echo "                  this is the drift the gate was wired in for"
           st_fail=1 ;;
    esac

    # CONTROL 2 — an operator removed from one grammar. The valve is the newest
    # and the one an editor tidy-up would most plausibly drop.
    fresh "$CTL/operator"
    sed -i.bak 's/|?>//g' "$CTL/operator/editor/nvim/syntax/bs.vim"
    rm -f "$CTL/operator/editor/nvim/syntax/bs.vim.bak"
    case "$(control "$CTL/operator")" in
        *MISSING*) ;;
        *) echo "SELF-TEST FAILED: an operator dropped from a grammar was not reported"
           st_fail=1 ;;
    esac

    # NEGATIVE CONTROL — the lexer and both grammars as committed.
    fresh "$CTL/clean"
    if CHECK_TOKENS_ROOT="$CTL/clean" "${BASH_SOURCE[0]}" > /dev/null 2>&1; then :; else
        echo "SELF-TEST FAILED: the committed grammars were rejected, so this gate"
        echo "                  would fail every clean tree and be removed"
        st_fail=1
    fi

    if [ "$st_fail" -eq 0 ]; then
        echo "self-test: named the uncoloured keyword and the dropped operator;"
        echo "           accepted the committed grammars — the gate discriminates"
        exit 0
    fi
    exit 1
fi

for f in "$LEXER" "$TM" "$VIM"; do
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 2; }
done

# A keyword rule in leex is a bare lowercase word in the first column followed by
# the token action. Every other rule starts with a sigil, a brace or `_`, so this
# picks out exactly the words and nothing else.
KEYWORDS="$(grep -oE '^[a-z]+[[:space:]]+:[[:space:]]*\{token,' "$LEXER" \
            | sed -E 's/[[:space:]]*:.*//' | sort -u)"

fail=0

for kw in $KEYWORDS; do
    in_tm=0; in_vim=0
    grep -q "\\b$kw\\b" "$TM"  && in_tm=1
    grep -q "\\b$kw\\b" "$VIM" && in_vim=1

    if [ "$in_tm" = 1 ] && [ "$in_vim" = 1 ]; then
        printf '  %-10s %s\n' "ok" "$kw"
    else
        missing=""
        [ "$in_tm" = 0 ]  && missing="$missing vscode"
        [ "$in_vim" = 0 ] && missing="$missing nvim"
        printf '  %-10s %s  -- missing from:%s\n' "MISSING" "$kw" "$missing"
        fail=1
    fi
done

# The multi-character operators, which is the set most likely to be added one at
# a time: `->` has been there since the walking skeleton, `=>` arrived with F7,
# `|>`/`|?>` with F14, and `<<` with F13. They cannot be derived from the leex
# file the way the
# keywords above are, because every one of them is written as an escaped regex
# there rather than as a bare word -- so the list is hand-maintained, and adding
# to it is part of adding an operator.
#
# BACKSLASHES ARE STRIPPED BEFORE MATCHING. Both grammars escape these for their
# own regex dialect: the valve is `\\|\\?>` in the TextMate JSON and `|?>` in
# vim, so the three characters are not adjacent in one file and are in the other.
# Comparing the de-escaped text is what makes one list check both.
OPS='-> => |> |?> <<'
NOPS=0
for op in $OPS; do
    NOPS=$((NOPS + 1))
    if grep -qF -- "$op" <(tr -d '\\' < "$TM") &&
       grep -qF -- "$op" <(tr -d '\\' < "$VIM"); then
        printf '  %-10s %s\n' "ok" "$op"
    else
        printf '  %-10s %s  -- an operator the lexer has and a grammar does not\n' \
               "MISSING" "$op"
        fail=1
    fi
done

echo
if [ "$fail" -eq 0 ]; then
    echo "$(echo "$KEYWORDS" | wc -w | tr -d ' ') keywords + $NOPS operators: all present in both grammars"
else
    echo "a token the lexer defines has no rule in one of the editor grammars."
    exit 1
fi
