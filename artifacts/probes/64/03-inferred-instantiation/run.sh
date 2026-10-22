#!/usr/bin/env bash
# Probe 03 -- is the loud refusal (ticket 68 Q1) complete?  A generic `option<T>` / `result<T,E>`
# instantiated at T = term by INFERENCE (nobody writes option<term>) -- does it refuse, or collapse silently?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/env.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
mkdir -p "$W/G"; cat > "$W/G/G.bs" <<'B'
module G

public option<T> Head<T>(list<T> xs)
Head([])       -> :nothing
Head([x, ..r]) -> x

public result<T, atom> First<T>(list<T> xs)
First([])       -> (:error, :empty)
First([x, ..r]) -> x

// Callers pass list<term>: T = term is INFERRED here, never written.
public string DescribeHead(list<term> xs)
DescribeHead(xs) -> Head(xs) switch {
    :nothing => "absent",
    v        => "present"
}

public string DescribeFirst(list<term> xs)
DescribeFirst(xs) -> First(xs) switch {
    (:error, e) => "failed",
    v           => "ok"
}

public string EmptyHead()
EmptyHead() -> DescribeHead([])
public string NothingHead()
NothingHead() -> DescribeHead([:nothing])
public string IntHead()
IntHead() -> DescribeHead([1])
public string EmptyFirst()
EmptyFirst() -> DescribeFirst([])
public string ErrorFirst()
ErrorFirst() -> DescribeFirst([(:error, :custom)])
public string IntFirst()
IntFirst() -> DescribeFirst([1])
B
echo "=== compile ==="; "$BSC" "$W/G" </dev/null; echo "exit=$?"
echo "=== --api ==="; "$BSC" --api "$W/G" </dev/null
for f in EmptyHead NothingHead IntHead EmptyFirst ErrorFirst IntFirst; do
  printf '%-12s -> ' "$f"; "$BSC" "$W/G" "$f" </dev/null 2>&1 | tail -1
done

echo
echo "################ same program, bsc with the PROTOTYPE call-site refusal (Option 2's compiler delta) ################"
PROTO="$("$HERE/../lib/build-bsc-callsite-refusal.sh" | tail -1)"
"$PROTO" "$W/G" </dev/null; echo "exit=$?"
mkdir -p "$W/H"; cat > "$W/H/H.bs" <<'B'
module H

public option<T> Head<T>(list<T> xs)
Head([])       -> :nothing
Head([x, ..r]) -> x

// control: T = int survives, so the prototype must stay quiet
public int OrZero(list<int> xs)
OrZero(xs) -> Head(xs) switch { :nothing => 0, n => n }

// control: Head([]) instantiates T at the empty type
public string EmptyCase()
EmptyCase() -> Head([]) switch { :nothing => "absent", v => "present" }
B
echo "=== controls (T = int; T = none) under the prototype ==="; "$PROTO" "$W/H" </dev/null; echo "exit=$?"
"$PROTO" "$W/H" OrZero '[]' </dev/null 2>&1 | tail -1
