#!/usr/bin/env bash
# 55f — Ticket 55's grammar measurement.
#
# The rule this exists to obey: yecc conflicts are MEASURED, never inferred. A
# quiet `rebar3 compile` proves nothing, because yecc resolves a shift/reduce
# conflict silently (by shifting) and carries on generating a parser that is
# subtly not the grammar you wrote. The only honest measurement is running
# `yecc:file/2` on the before and the after and diffing the conflict count.
#
# Baseline, measured 2026-08-22: bs_parser.yrl generates with ZERO conflicts and
# ZERO warnings. That is what makes this test sharp — any conflict a variant
# introduces is attributable to that variant alone.
#
# Usage:  ./55f_yecc_conflicts.sh [base|a|b|c|all]
#
# Variants, all inserted beside the existing bare record pattern:
#
#   a — bare pattern + trailing binder          { Type: :method } f
#   b — type prefix + trailing binder           Frame { Type: :method } f
#   c — binder on the left, Erlang-side         f = Frame { Type: :method }
#
# Variant (b) is the one with a named risk: after `uident '{' uident`, the token
# that tells a PATTERN from a record CONSTRUCTION — `:` against `=` — is two
# tokens ahead, and yecc has one token of lookahead.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAMMAR="$HERE/../../compiler/src/bs_parser.yrl"
WORK="${SPEC_CHECK_DIR:-${TMPDIR:-/tmp}}/bs55_yecc.$$"

if [ ! -f "$GRAMMAR" ]; then
    echo "FATAL: grammar not found at $GRAMMAR" >&2
    exit 2
fi

mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# The anchor every variant is inserted after: the existing bare record pattern.
ANCHOR="pattern -> '{' pat_fields '}' : {p_map, line('\$1'), '\$2'}."

emit_variant() {
    local name="$1" out="$2" addition="$3"
    if ! grep -qF "$ANCHOR" "$GRAMMAR"; then
        echo "FATAL: anchor production not found in the grammar — it has moved." >&2
        echo "       Looked for: $ANCHOR" >&2
        exit 2
    fi
    # The addition is multi-line, so it goes through a FILE rather than `awk -v`,
    # which cannot carry a newline in a variable.
    local addfile="$WORK/$name.add"
    printf '%s\n' "$addition" > "$addfile"
    awk -v anchor="$ANCHOR" -v addfile="$addfile" '
        { print }
        index($0, anchor) {
            print ""
            while ((getline line < addfile) > 0) print line
            close(addfile)
        }
    ' "$GRAMMAR" > "$out"
    # Prove the insertion actually happened; a silent no-op here would make every
    # variant measure the baseline and agree perfectly.
    if [ "$(wc -l < "$out")" -le "$(wc -l < "$GRAMMAR")" ]; then
        echo "FATAL: variant $name did not grow the grammar — insertion failed." >&2
        exit 2
    fi
}

# Runs yecc and prints "<conflicts> <status>". yecc reports shift/reduce
# conflicts on stdout and reduce/reduce as an error that refuses generation, so
# both channels are captured.
measure() {
    local yrl="$1" label="$2"
    local log="$WORK/$label.log"
    local rc=0

    erl -noshell -eval "
        R = yecc:file(\"$yrl\", [{report, true}, {verbose, false}, {return, true}]),
        case R of
            {ok, _, Ws}  -> io:format(\"~nYECC_STATUS ok warnings=~p~n\", [length(Ws)]);
            {ok, _}      -> io:format(\"~nYECC_STATUS ok warnings=0~n\", []);
            {error, Es, Ws} -> io:format(\"~nYECC_STATUS error errors=~p warnings=~p~n\",
                                         [length(Es), length(Ws)]);
            Other        -> io:format(\"~nYECC_STATUS other ~p~n\", [Other])
        end,
        halt(0)." > "$log" 2>&1 || rc=$?

    local status actions summary
    status=$(grep 'YECC_STATUS' "$log" | head -1 || echo "YECC_STATUS none")

    # yecc does NOT print the words "shift/reduce conflict" per site. Each site is
    # "Parse action conflict scanning symbol X in state N", and the TOTAL arrives
    # once, as "Warning: conflicts: A shift/reduce, B reduce/reduce". Grepping for
    # the per-site wording counts zero on a grammar riddled with conflicts, which
    # is how the first version of this function read a broken grammar as clean.
    actions=$(grep -c 'Parse action conflict' "$log" || true)
    summary=$(grep -oE 'conflicts: [0-9]+ shift/reduce, [0-9]+ reduce/reduce' "$log" | head -1 || true)
    [ -z "$summary" ] && summary="conflicts: 0 shift/reduce, 0 reduce/reduce (no summary line emitted)"

    # A machine-readable total, so the verdict below compares NUMBERS. An earlier
    # version grepped the log for the word "conflict" and matched this function's
    # own labels, failing a grammar that was clean.
    local sr rr total
    sr=$(printf '%s' "$summary" | grep -oE '([0-9]+) shift/reduce' | grep -oE '[0-9]+' || echo 0)
    rr=$(printf '%s' "$summary" | grep -oE '([0-9]+) reduce/reduce' | grep -oE '[0-9]+' || echo 0)
    total=$(( ${sr:-0} + ${rr:-0} ))

    printf '%-6s  exit=%s  %s\n' "$label" "$rc" "$status"
    printf '        yecc: %s\n' "$summary"
    printf '        parse-action sites: %s\n' "$actions"
    printf '        CONFLICT_TOTAL=%s\n' "$total"
    # Any conflict text at all, verbatim — the count is not the whole story.
    grep -iE 'conflict|Warning:|Error:' "$log" | head -12 | sed 's/^/        | /' || true
    echo
}

run_base() {
    cp "$GRAMMAR" "$WORK/base.yrl"
    measure "$WORK/base.yrl" "base"
}

run_a() {
    emit_variant a "$WORK/a.yrl" \
"pattern -> '{' pat_fields '}' lident :
    {p_bind, line('\$1'), value('\$4'), {p_map, line('\$1'), '\$2'}}."
    measure "$WORK/a.yrl" "a"
}

run_b() {
    emit_variant b "$WORK/b.yrl" \
"pattern -> uident '{' pat_fields '}' :
    {p_rec, line('\$1'), value('\$1'), '\$3'}.
pattern -> uident '{' pat_fields '}' lident :
    {p_bind, line('\$1'), value('\$5'), {p_rec, line('\$1'), value('\$1'), '\$3'}}."
    measure "$WORK/b.yrl" "b"
}

# (d) The full generalisation, and the one LANGUAGE.md:611 itself writes. The
# reference's illustrative dispatch is `Area(Circle c)` — a TYPE and a BINDER with
# no property pattern at all — beside the note that "whether a sugar mirroring
# construction is added is a grammar-opinion question that is still open". If the
# type prefix is taken, this degenerate form comes with it or the sugar is
# half-built: `Frame { } f` would be the only way to say "any Frame, called f".
#
# It is measured separately because it is the variant with a real reason to
# conflict: `uident lident` in PATTERN position is character-identical to a
# `param` (`type_prim lident`), and a clause head is where both live.
run_d() {
    emit_variant d "$WORK/d.yrl" \
"pattern -> uident '{' pat_fields '}' :
    {p_rec, line('\$1'), value('\$1'), '\$3'}.
pattern -> uident '{' pat_fields '}' lident :
    {p_bind, line('\$1'), value('\$5'), {p_rec, line('\$1'), value('\$1'), '\$3'}}.
pattern -> uident lident :
    {p_bind, line('\$1'), value('\$2'), {p_rec, line('\$1'), value('\$1'), []}}."
    measure "$WORK/d.yrl" "d"
}

run_c() {
    emit_variant c "$WORK/c.yrl" \
"pattern -> lident '=' pattern :
    {p_bind, line('\$2'), value('\$1'), '\$3'}."
    measure "$WORK/c.yrl" "c"
}

# --- the self-test -----------------------------------------------------------
#
# Every variant above measured ZERO conflicts, including (b), which was predicted
# to conflict. A measurement that says "clean" about everything is indistinguishable
# from a measurement that cannot see conflicts at all, so it is not believed until
# it has been seen to go RED on a defect it names.
#
# THE FIRST CONTROL THIS SCRIPT USED WAS WRONG, and the way it was wrong is the
# reason the self-test earns its place. It built `pattern 'and' pattern`, which
# bs_parser.yrl:366 predicts would conflict — and measured CLEAN, which read as a
# blind harness. The harness was fine; the control was not. `and` carries a
# precedence declaration (`Left 200 'and'`, line 44), and a token with a
# precedence has its ambiguity resolved SILENTLY by yecc and reported as nothing
# at all. So the grammar's line-366 argument is a semantic one about what `and`
# after every pattern form would MEAN, not a claim about a conflict count — and
# any control built on a token that appears in the precedence block measures the
# precedence table rather than the grammar.
#
# The control below is a REDUCE/REDUCE conflict instead: two productions giving
# `lident` two different routes to `pattern`. No precedence declaration can
# resolve a reduce/reduce conflict, so it survives the table and yecc must report
# it or it cannot report anything.
#
# BOTH halves are required, and this is the half that is easy to skip: a harness
# that reported conflicts on everything would pass the red check and be worthless.
# So the green control — the untouched grammar — must come back clean in the same
# run.
self_test() {
    local rc=0 red_log green_log

    echo "--- self-test: the harness must go RED on a known conflict ---"
    echo

    emit_variant selftest "$WORK/selftest.yrl" \
"pattern -> bs55_dup : '\$1'.
bs55_dup -> lident : {p_var, line('\$1'), value('\$1')}."
    # The new nonterminal has to be declared or yecc rejects the file outright,
    # which would look like a conflict and prove nothing.
    perl -0pi -e "s/(\n  rel_pattern rel_test int_lit refinement)/\$1 bs55_dup/" \
        "$WORK/selftest.yrl"
    if ! grep -q 'bs55_dup' "$WORK/selftest.yrl"; then
        echo "FATAL: self-test control was not inserted." >&2
        return 2
    fi

    red_log="$WORK/selftest_red.txt"
    measure "$WORK/selftest.yrl" "RED" | tee "$red_log"

    green_log="$WORK/selftest_green.txt"
    cp "$GRAMMAR" "$WORK/green.yrl"
    measure "$WORK/green.yrl" "GREEN" | tee "$green_log"

    echo "--- verdict ---"

    local red_total green_total
    red_total=$(grep -oE 'CONFLICT_TOTAL=[0-9]+' "$red_log" | grep -oE '[0-9]+' | head -1)
    green_total=$(grep -oE 'CONFLICT_TOTAL=[0-9]+' "$green_log" | grep -oE '[0-9]+' | head -1)

    # RED half: the known-conflicting grammar must report at least one conflict.
    if [ "${red_total:-0}" -gt 0 ]; then
        echo "PASS  red   — control measured $red_total conflicts; the harness can see them."
    else
        echo "FAIL  red   — a reduce/reduce control measured CLEAN ($red_total)."
        echo "              The harness cannot see conflicts. Every result above is void."
        rc=1
    fi

    # GREEN half: the untouched grammar must still be clean IN THE SAME RUN. A
    # harness that fired on everything would pass the red half and be worthless.
    if [ "${green_total:-0}" -gt 0 ]; then
        echo "FAIL  green — the untouched grammar measured $green_total conflicts."
        echo "              The harness fires on everything, which is the same as never."
        rc=1
    else
        echo "PASS  green — the untouched grammar measured 0 beside it."
    fi

    return $rc
}

echo "=== 55f — yecc conflict measurement for ticket 55 ==="
echo "grammar: $GRAMMAR"
echo

case "${1:-all}" in
    base)        run_base ;;
    a)           run_a ;;
    b)           run_b ;;
    c)           run_c ;;
    d)           run_d ;;
    all)         run_base; run_a; run_b; run_c; run_d ;;
    --self-test) self_test ;;
    *)           echo "usage: $0 [base|a|b|c|d|all|--self-test]" >&2; exit 2 ;;
esac
