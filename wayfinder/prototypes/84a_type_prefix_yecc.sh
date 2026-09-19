#!/usr/bin/env bash
# 84a — F53's grammar measurement for the type-prefix pattern (ticket 84).
#
# 55f measured three variants at zero conflicts and every one of them began with
# a `uident` — `Frame { … } f`. `float a` begins with a TYPE PRIMITIVE, a
# different token class, and the risk is named: `pattern -> lident` already
# reduces a bare name to a variable, so a second `lident` after it is exactly
# the place a shift/reduce lives. yecc resolves shift/reduce SILENTLY by
# shifting, so a quiet `rebar3 compile` measures nothing.
#
# Usage:  ./84a_type_prefix_yecc.sh [base|a|b|all|--self-test]
#
#   a — the bare type prefix                 Post(float a)
#   b — (a) plus the generic spelling        Count(list<int> ns)
#
# (b) is measured even though the checker refuses `list<int> ns` under ticket
# 84's Q2, because the refusal is the CHECKER's and its words are `map<K, V>`'s:
# a form refused at parse time cannot say "temporary by construction" in them.
#
# Run from anywhere: the measurement `cd`s to the repo root, because a bare
# `erl` started inside `compiler/` dies during boot on macOS, where `C.beam`
# shadows stdlib's `c` module.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GRAMMAR="$ROOT/compiler/src/bs_parser.yrl"
WORK="${SPEC_CHECK_DIR:-${TMPDIR:-/tmp}}/bs84_yecc.$$"

if [ ! -f "$GRAMMAR" ]; then
    echo "FATAL: grammar not found at $GRAMMAR" >&2
    exit 2
fi

mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

ANCHOR="pattern -> '{' pat_fields '}' : {p_map, line('\$1'), '\$2'}."

emit_variant() {
    local name="$1" out="$2" addition="$3"
    if ! grep -qF "$ANCHOR" "$GRAMMAR"; then
        echo "FATAL: anchor production not found in the grammar — it has moved." >&2
        echo "       Looked for: $ANCHOR" >&2
        exit 2
    fi
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
    if [ "$(wc -l < "$out")" -le "$(wc -l < "$GRAMMAR")" ]; then
        echo "FATAL: variant $name did not grow the grammar — insertion failed." >&2
        exit 2
    fi
}

# Prints "<conflicts> <status>" for one grammar file. yecc reports shift/reduce
# on stdout and reduce/reduce as an error refusing generation, so both channels
# are captured. The TOTAL arrives once, as a summary line; the per-site wording
# is "Parse action conflict", which is counted beside it.
measure() {
    local yrl="$1" label="$2"
    local log="$WORK/$label.log"
    local rc=0

    ( cd "$ROOT" && erl -noshell -eval "
        R = yecc:file(\"$yrl\", [{report, true}, {verbose, false}, {return, true}]),
        case R of
            {ok, _, Ws}  -> io:format(\"~nYECC_STATUS ok warnings=~p~n\", [length(Ws)]);
            {ok, _}      -> io:format(\"~nYECC_STATUS ok warnings=0~n\", []);
            {error, Es, Ws} -> io:format(\"~nYECC_STATUS error errors=~p warnings=~p~n\",
                                         [length(Es), length(Ws)]);
            Other        -> io:format(\"~nYECC_STATUS other ~p~n\", [Other])
        end,
        halt(0)." ) > "$log" 2>&1 || rc=$?

    local status actions summary
    status=$(grep 'YECC_STATUS' "$log" | head -1 || echo "YECC_STATUS none")
    actions=$(grep -c 'Parse action conflict' "$log" || true)
    summary=$(grep -oE 'conflicts: [0-9]+ shift/reduce, [0-9]+ reduce/reduce' "$log" | head -1 || true)
    [ -z "$summary" ] && summary="conflicts: 0 shift/reduce, 0 reduce/reduce (no summary line emitted)"

    local sr rr total
    sr=$(printf '%s' "$summary" | grep -oE '([0-9]+) shift/reduce' | grep -oE '[0-9]+' || echo 0)
    rr=$(printf '%s' "$summary" | grep -oE '([0-9]+) reduce/reduce' | grep -oE '[0-9]+' || echo 0)
    total=$(( ${sr:-0} + ${rr:-0} ))

    printf '%-6s  exit=%s  %s\n' "$label" "$rc" "$status"
    printf '        yecc: %s\n' "$summary"
    printf '        parse-action sites: %s\n' "$actions"
    printf '        CONFLICT_TOTAL=%s\n' "$total"
    grep -iE 'conflict|Warning:|Error:' "$log" | head -12 | sed 's/^/        | /' || true
    echo
}

run_base() {
    cp "$GRAMMAR" "$WORK/base.yrl"
    measure "$WORK/base.yrl" "base"
}

# The bare prefix. `int`, `float`, `atom`, `binary` are all `lident` to the
# lexer — the language has no keyword for a type primitive — so this one
# production is every part's spelling.
run_a() {
    emit_variant a "$WORK/a.yrl" \
"pattern -> lident lident :
    {p_type, line('\$1'), {t_builtin, value('\$1')}, value('\$2')}."
    measure "$WORK/a.yrl" "a"
}

# The generic spelling beside it. `list<int> ns` shares its first two tokens
# with nothing in pattern position, but `<` is also the relational pattern's
# first token (`Classify(< 4)`), which is the conflict this half looks for.
run_b() {
    emit_variant b "$WORK/b.yrl" \
"pattern -> lident lident :
    {p_type, line('\$1'), {t_builtin, value('\$1')}, value('\$2')}.
pattern -> lident '<' type_list '>' lident :
    {p_type, line('\$1'), {t_generic, value('\$1'), '\$3'}, value('\$5')}."
    measure "$WORK/b.yrl" "b"
}

# --- the self-test -----------------------------------------------------------
#
# A measurement that says "clean" about everything is indistinguishable from one
# that cannot see conflicts at all, so it is not believed until it has been seen
# to go RED on a defect it names, with a GREEN beside it in the same run.
#
# The control is a REDUCE/REDUCE conflict — two productions giving `lident` two
# routes to `pattern` — because no precedence declaration can resolve one, so it
# survives the table and yecc must report it or it can report nothing. 55f
# records why a shift/reduce control over `and` was the wrong one: a token with
# a precedence has its ambiguity resolved silently and reported as nothing.
#
# BOTH HALVES ARE DELTAS AGAINST THE TREE'S OWN BASELINE, NOT AGAINST ZERO.
# 55f's baseline comment says zero and was true on 2026-08-22; the bare-name
# lambda has since put the grammar at 5 shift/reduce (ticket 76, F46, measured
# there as "5 against the landed 4"). A green half asserting zero would fail on
# a clean tree and say nothing about the variant, which is the measurement this
# script exists to make.
self_test() {
    local rc=0 red_log green_log base_log a_log

    echo "--- self-test: the harness must go RED on a known conflict ---"
    echo

    emit_variant selftest "$WORK/selftest.yrl" \
"pattern -> bs84_dup : '\$1'.
bs84_dup -> lident : {p_var, line('\$1'), value('\$1')}."
    perl -0pi -e "s/(\n  rel_pattern rel_test int_lit refinement)/\$1 bs84_dup/" \
        "$WORK/selftest.yrl"
    if ! grep -q 'bs84_dup' "$WORK/selftest.yrl"; then
        echo "FATAL: self-test control was not inserted." >&2
        return 2
    fi

    base_log="$WORK/selftest_base.txt"
    cp "$GRAMMAR" "$WORK/green.yrl"
    measure "$WORK/green.yrl" "BASE" | tee "$base_log"

    red_log="$WORK/selftest_red.txt"
    measure "$WORK/selftest.yrl" "RED" | tee "$red_log"

    a_log="$WORK/selftest_a.txt"
    emit_variant greena "$WORK/greena.yrl" \
"pattern -> lident lident :
    {p_type, line('\$1'), {t_builtin, value('\$1')}, value('\$2')}."
    measure "$WORK/greena.yrl" "GREEN" | tee "$a_log"

    echo "--- verdict ---"

    local base_total red_total green_total
    base_total=$(grep -oE 'CONFLICT_TOTAL=[0-9]+' "$base_log" | grep -oE '[0-9]+' | head -1)
    red_total=$(grep -oE 'CONFLICT_TOTAL=[0-9]+' "$red_log" | grep -oE '[0-9]+' | head -1)
    green_total=$(grep -oE 'CONFLICT_TOTAL=[0-9]+' "$a_log" | grep -oE '[0-9]+' | head -1)

    echo "        baseline measured this run: ${base_total:-?}"

    # RED half: a known-conflicting control must measure ABOVE the baseline.
    if [ "${red_total:-0}" -gt "${base_total:-0}" ]; then
        echo "PASS  red   — control measured $red_total against a baseline of $base_total."
    else
        echo "FAIL  red   — a reduce/reduce control measured $red_total, no more than the"
        echo "              baseline $base_total. The harness cannot see conflicts, and"
        echo "              every result above is void."
        rc=1
    fi

    # GREEN half: the type prefix must measure EXACTLY the baseline. A harness
    # that fired on everything would pass the red half and fail here, which is
    # the half that is easy to skip.
    if [ "${green_total:-0}" -eq "${base_total:-0}" ]; then
        echo "PASS  green — the type prefix measured $green_total, the baseline itself."
    else
        echo "FAIL  green — the type prefix measured $green_total against a baseline of"
        echo "              $base_total. The form costs conflicts and F53's claim is false."
        rc=1
    fi

    return $rc
}

echo "=== 84a — yecc conflict measurement for F53's type prefix ==="
echo "grammar: $GRAMMAR"
echo

case "${1:-all}" in
    base)        run_base ;;
    a)           run_a ;;
    b)           run_b ;;
    all)         run_base; run_a; run_b ;;
    --self-test) self_test ;;
    *)           echo "usage: $0 [base|a|b|all|--self-test]" >&2; exit 2 ;;
esac
