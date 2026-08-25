#!/usr/bin/env bash
# PROTOTYPE 48i — what is actually missing, given that map patterns exist?
#
# Throwaway. Ticket 48. This is the probe that locates the real gap.
#
# 48f showed the brace map type and pattern already ship, and 48g showed
# exhaustiveness over them is enforced rather than vacuous. So the ticket's
# question is not "should maps be matchable". Something else is missing, and
# this probe pins it.
#
# The suspicion came from the grammar. All three brace forms take a single
# TERMINAL in key position — not a nonterminal, so there is nothing to extend:
#
#     field_decl   -> uident ':' type_expr     bs_parser.yrl:98    the TYPE
#     pat_field    -> uident ':' pattern       bs_parser.yrl:490   the PATTERN
#     assign_field -> uident '=' expr          bs_parser.yrl:702   construct + `with`
#
# Note the asymmetry inside each rule: the VALUE side is a full nonterminal,
# the KEY side is one token. `uident` is `{UPPER}{ALNUM}*`, so the restriction
# is PascalCase specifically — not "an identifier", not "a literal".
#
# A dictionary needs a key that is a VALUE: a string, a runtime atom, a bound
# variable. Every case below is one of those.
#
#   1. A string key, in a TYPE.
#   2. A string key, in a PATTERN.
#   3. A lowercase identifier as a key.
#   4. An atom literal as a key.
#   5. A bound variable as a key, using ticket 45's `== name` pin.
#   6. A string key in `with`.
#   CONTROLS: the PascalCase form that works, and `== k` used OUTSIDE a key.
#
#   ./48i_key_position_takes_no_value.sh
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
    local name="$1" fn="$2" body="$3"; shift 3
    local mod out rc
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name : $fn $* ---"
    out="$("$BSC" "$WORK/$name/$mod/$mod.bs" "$fn" "$@" 2>&1)"; rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    echo "    exit $rc"
    echo
}

echo "==============================================================="
echo "0. CONTROLS — the working form, and the pin OUTSIDE a key."
echo "==============================================================="
echo "    Control A is the PascalCase key that works, so every refusal"
echo "    below is about the KEY POSITION and not about braces."
echo "    Control B proves \`== k\` is a legal pattern in its own right"
echo "    (bs_parser.yrl:355). Without B, case 5's syntax error would be"
echo "    read as \"pins are not patterns\", which is the wrong lesson."

probe control_a_pascal_key_works '
module CtlA

public int Read({ Status: int } m)

Read({ Status: s }) -> s
'

CTLPIN='
module CtlB

public int Pick(atom a, atom b)

Pick(== b, b) -> 1
Pick(a, b)    -> 0
'

probe control_b_pin_outside_a_key "$CTLPIN"
run_probe control_b_pin_runs Pick "$CTLPIN" ":a" ":a"

echo "==============================================================="
echo "1 & 2. A STRING key — the group-by case from exemplar 25d."
echo "==============================================================="
echo "    25d wanted to group orders by customer, an open string key,"
echo "    and wrote an assoc list by hand at O(n) per lookup because"
echo "    this does not exist."

probe string_key_in_type '
module StrTy

public int Read({ "acme": int } m)

Read(m) -> 0
'

probe string_key_in_pattern '
module StrPat

public int Read(term m)

Read({ "acme": tot }) -> tot
'

echo "==============================================================="
echo "3 & 4. A lowercase identifier, and an atom literal, as keys."
echo "==============================================================="
echo "    Ticket 31's \`conn.assigns\` is atom-keyed but the ATOM SET is"
echo "    open, so even an atom key does not rescue the fixed form."

probe lowercase_key '
module LowKey

public int Read(term m)

Read({ status: tot }) -> tot
'

probe atom_literal_key '
module AtomKey

public int Read(term m)

Read({ :acme: tot }) -> tot
'

echo "==============================================================="
echo "5. A BOUND VARIABLE as a key — the lookup a dictionary IS."
echo "==============================================================="
echo "    Read against control B. The pin is a legal pattern; what is"
echo "    refused is a pattern appearing in key position at all."

probe bound_variable_key '
module VarKey

public int Read(term m, atom k)

Read({ == k: tot }, k) -> tot
'

echo "==============================================================="
echo "6. A string key in \`with\` — construction and update share one"
echo "   production, so they cannot diverge."
echo "==============================================================="
echo "    bs_parser.yrl:696 (construct) and :708 (\`with\`) both consume"
echo "    assign_fields, whose element is :702 \`uident '=' expr\`."

probe string_key_in_with '
module WithKey

record Order { Total: int }

public Order Bump(Order o)

Bump(o) -> o with { "acme" = 1 }
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    The key position takes ONE TERMINAL, \`uident\`, and nothing"
echo "    else. A string, a lowercase name, an atom literal and a bound"
echo "    variable are all refused at the PARSER — while the same pin"
echo "    runs fine one position to the left."
echo
echo "    So what beam-sharp is missing is not a map pattern. It is a"
echo "    key that is a VALUE, and behind that an UNBOUNDED KEY DOMAIN."
echo
echo "    Those two are ONE blocker, not two: bs_types.erl:99 declares"
echo "    map_member() as {closed | open, #{atom() => ty()}}, so keys are"
echo "    atoms end to end, and every intersection, subtraction and"
echo "    absorption decision routes through an atom-set comparison"
echo "    (same_keys/2 and keys_subset/2, bs_types.erl:735-738). Changing"
echo "    the parser alone would emit a key with nowhere to land."
echo "done."
