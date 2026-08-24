#!/usr/bin/env bash
# PROTOTYPE 25d — what today's compiler says about the database exemplar's claims.
#
# Throwaway. Ticket 25, exemplar 4. Runs the compiler (`compiler/`) over five
# probes. Each one decides a sentence in 25d-database-querying.md — the rule
# is to run the form rather than reason about it, because two prior exemplars
# each found one claim that reading alone got wrong.
#
#   ./25d_surface_probe.sh
#
# Requires: OTP 28, rebar3. Builds bsc if it is not already built.
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

# One directory per probe, named after the module — F15's rule, learned by
# 25c_residual_probe.sh the hard way (see the note there).
probe () {
    local name="$1" body="$2"
    shift 2
    local mod
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name ---"
    "$BSC" "$WORK/$name/$mod/$mod.bs" "$@" 2>&1 || true
    echo
}

echo "=== 1. Is a catch-all refused over a CLOSED atom residual today? (ticket 12 §2) ==="
echo "A status column is a CHECK-constrained text field: three values, closed."
echo "25c measured the skeleton accepting this on 2026-08-13. Re-measured today."
probe closed_catchall 'module P1
type OrderStatus = :placed | :shipped | :cancelled
public atom Advance(OrderStatus s)
Advance(:placed) -> :shipped
Advance(_)       -> :done'

echo "=== 2. Does valve subtraction prove the two-clause result-shape stage exhaustive? ==="
echo "equery returns (:ok, count) | (:ok, cols, rows) | (:error, e). The valve"
echo "subtracts the error member; the stage after it should need exactly the two"
echo "ok shapes and no third clause."
probe valve_subtracts 'module P2
type QueryOutcome = (:ok, int) | (:ok, term, term) | (:error, term)
type Ok = (:ok, int) | (:ok, term, term)
public term Run(QueryOutcome o)
Run(o) -> o |?> Shaped()
private term Shaped(Ok o)
Shaped((:ok, n))          -> (:error, (:not_rows, n))
Shaped((:ok, cols, rows)) -> rows'

echo "=== 2b. CONTROL: drop the count clause and the residual should name it ==="
probe valve_control 'module P2b
type QueryOutcome = (:ok, int) | (:ok, term, term) | (:error, term)
type Ok = (:ok, int) | (:ok, term, term)
public term Run(QueryOutcome o)
Run(o) -> o |?> Shaped()
private term Shaped(Ok o)
Shaped((:ok, cols, rows)) -> rows'

echo "=== 3. ValidateAs over a list of TUPLE rows: does the path name the row? ==="
echo "Rows cross the boundary as tuples, not records. Handed a 2-row set whose"
echo "second row has an atom where text belongs, the error should read [1](2)."
probe rowset_path 'module P3
type WireRow = (int, string, term)
public result<list<WireRow>, ValidationError> Check(term rows)
Check(rows) -> ValidateAs<list<WireRow>>(rows)' \
    Check '[(1, "ada", :x), (2, :bad, :y)]'

echo "=== 3b. ...and a clean set passes through unchanged ==="
probe rowset_clean 'module P3b
type WireRow = (int, string, term)
public result<list<WireRow>, ValidationError> Check(term rows)
Check(rows) -> ValidateAs<list<WireRow>>(rows)' \
    Check '[(1, "ada", :x)]'

echo "=== 4. SQL NULL is not :nothing ==="
echo "epgsql hands back the atom null (measured live, 25d_live_capture.escript)."
echo "option<T> spells absence :nothing. Ask the language what :null is."
probe null_is_not_nothing 'module P4
public atom Has(option<atom> v)
Has(:nothing) -> :absent
Has(v)        -> :present' \
    Has ':null'

echo "=== 5. Is a 3-clause property-pattern dispatch over a closed record field exhaustive? ==="
echo "The summary fold dispatches on a record field typed by a closed atom union,"
echo "with no catch-all. If the checker cannot subtract at the field, this is red."
probe field_exhaustive 'module P5
type OrderStatus = :placed | :shipped | :cancelled
record OrderRow { Status: OrderStatus, TotalCents: int }
record Totals { P: int, S: int, C: int }
public Totals Add(Totals t, OrderRow r)
Add(t, { Status: :placed } r)    -> t with { P = t.P + r.TotalCents }
Add(t, { Status: :shipped } r)   -> t with { S = t.S + r.TotalCents }
Add(t, { Status: :cancelled } r) -> t with { C = t.C + r.TotalCents }'

echo "=== 5b. CONTROL: drop the :cancelled clause — the residual should name it ==="
probe field_control 'module P5b
type OrderStatus = :placed | :shipped | :cancelled
record OrderRow { Status: OrderStatus, TotalCents: int }
record Totals { P: int, S: int, C: int }
public Totals Add(Totals t, OrderRow r)
Add(t, { Status: :placed } r)    -> t with { P = t.P + r.TotalCents }
Add(t, { Status: :shipped } r)   -> t with { S = t.S + r.TotalCents }'
