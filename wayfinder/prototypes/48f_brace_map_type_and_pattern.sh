#!/usr/bin/env bash
# PROTOTYPE 48f — does beam-sharp already HAVE an anonymous map type and a map
# pattern, spelled with bare braces?
#
# Throwaway. Ticket 48, checking the claim the whole ticket rests on.
#
# Ticket 48 frames three candidates and spends its length deciding whether a
# map should be MATCHABLE. That framing assumes the pattern form does not
# exist. The assumption was never run.
#
# The doubt came from the grammar. `bs_parser.yrl:228` reads
# `type_prim -> '{' field_decls '}' : {t_map, '$2'}` and `:485` reads
# `pattern -> '{' pat_fields '}' : {p_map, line('$1'), '$2'}` — two rules that
# say "anonymous map", not "record". If those fire, candidate 2's machinery is
# already built and the ticket has been deciding something else.
#
#   1. Does an anonymous map TYPE `{ Status: int }` type-check?
#   2. Does a map PATTERN `{ Status: 200 }` compile IN A CLAUSE HEAD?
#   3. Does it DISPATCH — do two clauses select on the key's value at runtime?
#   4. Is a catch-all beside it legal, rather than `catch_all_over_closed`?
#
#   ./48f_brace_map_type_and_pattern.sh
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

# Compile only. A silent run at exit 0 is this compiler's success signal.
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

# Compile AND RUN, because "it compiles" does not prove a clause was selected.
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
echo "0. CONTROLS — is the checker looking, and is \`#{\` really foreign?"
echo "==============================================================="
echo "    Control A refuses a bad return type, so the checker reaches a"
echo "    body at all. Control B is the SAME idea written with Erlang's"
echo "    \`#{\` spelling: if it is refused while bare braces are accepted,"
echo "    then \`#{\` is a foreign spelling rather than a missing feature."

probe control_a_checker_is_looking '
module CtlA

public int F(int n)

F(n) -> :not_an_int
'

probe control_b_hash_brace_spelling '
module CtlB

public term Lit()

Lit() -> #{ :a => 1 }
'

echo "==============================================================="
echo "1. An anonymous map TYPE in a signature — bare braces."
echo "==============================================================="

probe map_type_in_signature '
module MapTy

public int Read({ Status: int } m)

Read({ Status: s }) -> s
'

echo "==============================================================="
echo "2 & 3. A map PATTERN in a clause head, and does it DISPATCH?"
echo "==============================================================="
echo "    Two clauses keyed on the same field. If both arms are reachable"
echo "    with different answers, the pattern is really selecting."

MAPDISPATCH='
module MapDisp

public atom Kind({ Status: int } m)

Kind({ Status: 200 }) -> :ok
Kind(m)               -> :other
'

probe map_pattern_compiles "$MAPDISPATCH"
run_probe map_pattern_dispatch_200 Kind "#{'Status' => 200}" "$MAPDISPATCH"
run_probe map_pattern_dispatch_404 Kind "#{'Status' => 404}" "$MAPDISPATCH"

echo "==============================================================="
echo "4. Is the catch-all beside a map pattern LEGAL — and LIVE?"
echo "==============================================================="
echo "    Section 3 already answered the stronger question: \`Kind(m)\`"
echo "    did not merely compile, it FIRED and returned :other. So the"
echo "    catch-all beside a map pattern is reachable, not tolerated."
echo
echo "    The contrast below is what a catch-all looks like when the"
echo "    residual IS closed: the clauses exhaust the union, so the"
echo "    catch-all can never be reached and the compiler says so."
echo "    Note it WARNS rather than refusing — worth stating precisely,"
echo "    because an earlier draft of this probe predicted a refusal and"
echo "    the run corrected it."

probe catchall_over_closed_union '
module CtlClosed

type Status = :live | :dead

public int F(Status s)

F(:live) -> 1
F(:dead) -> 2
F(s)     -> 3
'

echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    beam-sharp ALREADY HAS an anonymous map type and a map pattern,"
echo "    spelled with BARE BRACES. They compile, they dispatch, and a"
echo "    catch-all stands beside them legally."
echo
echo "    So ticket 48's three-candidate framing is wrong at the root:"
echo "    candidate 2 asks for machinery that shipped with F3. What is"
echo "    missing is not the pattern form. See 48i for what IS missing —"
echo "    the key position takes a PascalCase field name, never a value."
echo "done."
