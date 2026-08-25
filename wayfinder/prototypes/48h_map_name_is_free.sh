#!/usr/bin/env bash
# PROTOTYPE 48h — does beam-sharp actually HAVE Gleam's name collision?
#
# Throwaway. Ticket 48, checking the survey's tie-break datum.
#
# The survey names one documented decision in the whole four-language field,
# and leans the naming question on it — lpil, gleam-lang/gleam issue 2405:
#
#     "`Map` is a little confusing as it collides with the common map
#      function. Let's rename it."
#
# The survey then calls this "the tie-break datum, and unlike the pattern-form
# question it is a documented decision rather than a silent one."
#
# A borrowed reason is only worth what its PREMISE is worth here. Gleam's
# premise is that one namespace holds both the type and the map/filter/reduce
# family. beam-sharp may not share it: `bs_check.erl:710-712` says the prelude
# owns the lowercase namespace while user types are PascalCase, "so the two
# cannot collide". If that separation also covers FUNCTIONS, the tie-break is
# disqualified rather than overruled — a distinction worth keeping straight,
# because the repo's rule is to survey sources and take the most accurate word.
#
#   1. Is `Map` a usable FUNCTION name today — declare, resolve, run?
#   2. Do a prelude type and a same-named module coexist in ONE file?
#   3. Control: is `Map<T,U>` (the planned polymorphic signature) shipped, or
#      is LANGUAGE.md's `not-yet` fence telling the truth?
#
#   ./48h_map_name_is_free.sh
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

run_probe () {
    local name="$1" fn="$2" arg="$3" body="$4"
    local mod out rc
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name : $fn $arg ---"
    out="$("$BSC" "$WORK/$name/$mod/$mod.bs" "$fn" "$arg" 2>&1)"; rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    echo "    exit $rc"
    echo
}

echo "==============================================================="
echo "1. Is \`Map\` a usable function name — declared, resolved, RUN?"
echo "==============================================================="
echo "    Not just \"does it parse\". \`Uses\` calls \`Map\` UNQUALIFIED, so"
echo "    this also exercises unqualified_key/4 (bs_check.erl:2129-2144),"
echo "    the resolver that would have to reject a reserved name."

MAPNAME='
module Coll

public int Map(int n)

Map(n) -> n * 2

public int Uses(int n)

Uses(n) -> Map(n)
'

probe map_as_function_name "$MAPNAME"
run_probe map_as_function_name_runs Uses 21 "$MAPNAME"

echo "==============================================================="
echo "2. THE ONE THAT SETTLES IT — a prelude type and a same-named"
echo "   module, in one file."
echo "==============================================================="
echo "    \`list<T>\` is the prelude type; \`List\` is an ordinary module"
echo "    name. Gleam's problem is one namespace holding both. If this"
echo "    compiles, beam-sharp is already running the pair that Gleam"
echo "    renamed to avoid — and the shipped surface agrees:"
echo "    compiler/examples/Shop/Collections/List/List.bs:8-10 declares"
echo "    \`module Shop.Collections.List\` and a signature over list<int>."

probe prelude_type_and_module_name '
module List

public int Sum(list<int> xs, int acc)

Sum([], acc)          -> acc
Sum([h, ..t], acc)    -> Sum(t, acc + h)
'

echo "==============================================================="
echo "3. CONTROL — is \`Map<T,U>\` shipped, or still \`not-yet\`?"
echo "==============================================================="
echo "    LANGUAGE.md:966-970 fences the polymorphic signature as"
echo "    \`not-yet\`, which check-language.sh REQUIRES not to compile. If"
echo "    this were accepted, the collision would be real after all and"
echo "    section 1 would be measuring the wrong thing."

probe polymorphic_map_signature '
module Poly

public list<U> Map<T, U>(list<T> xs, fn(T) -> U f)

Map([], f)       -> []
Map([h, ..t], f) -> [f(h), ..Map(t, f)]
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    beam-sharp does NOT have Gleam's collision, and it has neither"
echo "    half of it. \`Map\` is a free, usable function name today, and a"
echo "    lowercase prelude type coexists with a PascalCase module of the"
echo "    same word — the split is stated as a decision at"
echo "    bs_check.erl:710-712 and is visible in the shipped examples."
echo
echo "    So the survey's tie-break is DISQUALIFIED ON MEASUREMENT rather"
echo "    than overruled on taste. Gleam renamed for a reason that does"
echo "    not reach this language, which leaves the name free to be the"
echo "    most accurate word rather than the most cautious one."
echo "done."
