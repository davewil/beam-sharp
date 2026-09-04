#!/usr/bin/env bash
# Ticket 12 §2 says a catch-all `_` is an error over a CLOSED residual --
# "F discards cases the compiler can name". This probe asks: does a bound
# VARIABLE catch-all (same effect -- the value is never inspected further)
# get the same treatment? Surfaced while measuring the async exemplar's own
# use of exactly this shape (BatchReduce/checked.bs).
set -e
BSC="$1"
DIR="$2"   # candidates/_isolation_probes/ResidualProbe

echo "--- F(x) -> :other   (bound variable, closed residual Ev = :a | :b | :c) ---"
cat > "$DIR/f.bs" <<'EOF'
public atom F(Ev e)

F(:a) -> :got_a
F(x)  -> :other
EOF
"$BSC" "$DIR"; echo "exit=$? (expect 0 -- ACCEPTED)"

echo
echo "--- F(_) -> :other   (wildcard, same closed residual) ---"
cat > "$DIR/f.bs" <<'EOF'
public atom F(Ev e)

F(:a) -> :got_a
F(_)  -> :other
EOF
"$BSC" "$DIR"; echo "exit=$? (expect 1 -- REFUSED)"
