#!/usr/bin/env bash
# 66a — ticket 66 re-measured: may a named union of records stand in pattern
# position, `Delta(Payment p)` where `type Payment = CardPaid | BankPaid` and the
# declared input is the wider `Event`?
#
# Each case is a whole module written to a scratch directory, compiled with the
# repo's own `bsc`, and its exit code and diagnostic printed. For the forms that
# compile, the emitted Erlang is printed from the `.beam`'s abstract code, so the
# ticket can quote what the program becomes rather than what it is believed to
# become.
#
# Usage:  ./66a_union_name_in_pattern.sh
# Needs:  compiler/_build/default/bin/bsc (rebar3 escriptize) and `erl` on PATH.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BSC="$ROOT/compiler/_build/default/bin/bsc"
WORK="${TMPDIR:-/tmp}/bs66a.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

[ -x "$BSC" ] || { echo "FATAL: build bsc first: (cd compiler && rebar3 escriptize)" >&2; exit 2; }

HEAD_DECLS='record CardPaid { Id: int, Amount: int }
record BankPaid { Id: int, Amount: int }
record Refunded { Id: int, Amount: int }
record Voided   { Id: int, Amount: int }

type Payment = CardPaid | BankPaid
type Event   = CardPaid | BankPaid | Refunded'

case_() {  # name, body
    local name="$1" body="$2" dir="$WORK/$1" mod
    mod="L$(echo "$1" | sed 's/_//g')"
    mkdir -p "$dir/out" "$dir/$mod"
    printf 'module %s\n\n%s\n\n%s\n' "$mod" "$HEAD_DECLS" "$body" > "$dir/$mod/l.bs"
    echo "=== $name"
    sed -n '/^public/,$p' "$dir/$mod/l.bs" | sed 's/^/    /'
    # F15: a directory is a module, so each case is its own module directory.
    ( cd "$dir" && "$BSC" -o out "$mod" ) > "$dir/log" 2>&1
    echo "--- rc=$?"
    sed 's/^/    /' "$dir/log"
    if ls "$dir"/out/*.beam >/dev/null 2>&1; then
        echo "--- emitted Delta/1"
        erl -noshell -eval '
            [B] = filelib:wildcard("'"$dir"'/out/*.beam"),
            {ok, {_, [{abstract_code, {_, Forms}}]}} = beam_lib:chunks(B, [abstract_code]),
            [io:format("    ~s~n", [erl_pp:form(F)]) || F = {function, _, '"'"'Delta'"'"', 1, _} <- Forms],
            halt().' 2>&1
    fi
}

# 1. The program the ticket turns on: the union named in the head of a function
#    whose declared input is wider than the union.
case_ union_in_head 'public int Delta(Event e)

Delta(Payment p)  -> p.Amount
Delta(Refunded r) -> 0 - r.Amount'

# 2. What a program writes today: one clause per member, the body repeated.
case_ one_clause_per_member 'public int Delta(Event e)

Delta(CardPaid p) -> p.Amount
Delta(BankPaid p) -> p.Amount
Delta(Refunded r) -> 0 - r.Amount'

# 3. The plain case: the union IS the declared input. Already served.
case_ union_is_the_input 'public int Delta(Payment p)

Delta(p) -> p.Amount'

# 4. A non-member at a call into case 3.
case_ non_member_call 'public int Delta(Payment p)

Delta(p) -> p.Amount

public int Bad()

Bad() -> Delta(Refunded { Id = 1, Amount = 2 })'

# 5. A clause no call can reach: a record outside the declared union.
case_ unreachable_clause 'public int Delta(Payment p)

Delta(CardPaid p) -> p.Amount
Delta(BankPaid p) -> p.Amount
Delta(Voided v)   -> 0'

# 6. Case 1 with the Refunded clause dropped: what the residual prints today
#    for the one-clause-per-member spelling, which is what an answer of yes
#    would have to decide whether to reprint as `Payment p`.
case_ residual_today 'public int Delta(Event e)

Delta(CardPaid p) -> p.Amount
Delta(BankPaid p) -> p.Amount'
