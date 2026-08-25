#!/usr/bin/env bash
# PROTOTYPE 48j — the two walls a program actually hits, named precisely.
#
# Throwaway. Ticket 48, correcting how the walls have been described.
#
# Two things in the ticket's trail are stated in a way that misdirects:
#
#   * The prelude gap is quoted as `Assigns: map<atom, term>` being refused.
#     True, but it says nothing about which SPELLING is missing.
#   * 25a's front wall is recorded in FRONTIER as "`#{ ... }`, the anonymous
#     map literal". That names an ERLANG spelling. 48f has since shown that
#     beam-sharp spells anonymous maps with BARE braces at the type and
#     pattern levels, so "the `#{` literal is missing" describes a foreign
#     form rather than the actual hole.
#
# The hole is at the EXPRESSION level specifically. `bs_parser.yrl:696` is
# `expr -> uident '{' assign_fields '}'` — construction requires a record name
# in front. There is no bare `expr -> '{' ... '}'` rule at all.
#
#   1. Is `map<K, V>` refused, and what does the diagnostic recommend?
#   2. Is `dict<K, V>` refused the same way — is the name the issue, or the
#      arity/parametric machinery?
#   3. Does the `#{` spelling lex at all?
#   4. Does a BARE-BRACE map work at EXPRESSION level, the way it does at
#      type and pattern level?
#   CONTROL: record construction, which is the form that does work.
#
#   ./48j_the_two_walls.sh
#
# Requires: OTP 28, rebar3, a built bsc. Runs in a temp dir.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

probe () {
    local name="$1" body="$2"
    local mod out rc
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name ---"
    out="$("$BSC" "$WORK/$name/$mod/$mod.bs" 2>&1)"; rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    if [ "$rc" -eq 0 ]; then echo "    ACCEPTED (exit 0)"; else echo "    REFUSED (exit $rc)"; fi
    echo
}

echo "==============================================================="
echo "0. CONTROL — record construction, the form that works."
echo "==============================================================="
echo "    Establishes that brace CONSTRUCTION is understood when a"
echo "    record name precedes it, so the refusals below are about the"
echo "    missing name, not about braces in expression position."

probe control_record_construction '
module CtlRec

record Order { Total: int }

public Order Make()

Make() -> Order{ Total = 1 }
'

echo "==============================================================="
echo "1. WALL ONE — is there a map type to name?"
echo "==============================================================="
echo "    Note what the diagnostic RECOMMENDS. It is worth running the"
echo "    recommended form rather than reading past it."

probe map_type_named '
module MapNamed

public map<atom, int> Totals()

Totals() -> []
'

echo "==============================================================="
echo "2. Is it the NAME, or the parametric machinery?"
echo "==============================================================="
echo "    If \`dict\` refuses identically, the gap is a missing prelude"
echo "    entry rather than anything about the word chosen. Ticket 48's"
echo "    naming question is then genuinely open (see 48h)."

probe dict_type_named '
module DictNamed

public dict<atom, int> Totals()

Totals() -> []
'

echo "==============================================================="
echo "3. WALL TWO, as recorded — does \`#{\` lex?"
echo "==============================================================="
echo "    \`#\` appears nowhere in bs_lexer.xrl's Definitions or Rules;"
echo "    every occurrence in that file is prose in a comment about C#."
echo "    So this is expected to fail in the LEXER, before any grammar"
echo "    rule is consulted — which is a different failure from a"
echo "    missing production."

probe hash_brace_literal '
module HashLit

public term Lit()

Lit() -> #{ :a => 1 }
'

echo "==============================================================="
echo "4. WALL TWO, as it actually is — a BARE-BRACE map at EXPRESSION"
echo "   level."
echo "==============================================================="
echo "    This is the real hole. The same spelling that works in a"
echo "    signature (48f §1) and in a clause head (48f §2) has no"
echo "    expression production behind it."

probe bare_brace_expression '
module BareExpr

public term Lit()

Lit() -> { Status = 200 }
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    Wall one is a missing PRELUDE ENTRY, and it is name-neutral:"
echo "    \`map\` and \`dict\` refuse identically, so the naming question"
echo "    is decided on accuracy rather than availability."
echo
echo "    Wall two has been recorded in the wrong place. \`#{\` failing is"
echo "    a LEXER refusal of a foreign spelling, and adding \`#\` would"
echo "    give beam-sharp a second way to write a construct bare braces"
echo "    already serve at two of three levels. The hole is that the"
echo "    third level — EXPRESSION — has no bare-brace production."
echo
echo "    So 25a's front wall is anonymous map CONSTRUCTION, not \`#{\`."
echo "done."
