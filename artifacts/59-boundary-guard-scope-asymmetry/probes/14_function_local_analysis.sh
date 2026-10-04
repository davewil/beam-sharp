#!/bin/bash
# Probe 14: is 18 s4's function-local "would the body object?" analysis what the emitter does?
# Prediction if it were: a guard only where the body would not object, and "a value handed to
# another function counts as unchecked, and is guarded" only on the pass-through. Observed with the
# real bsc: the int and tag guards are emitted from the DECLARED PARAMETER TYPE alone (guard_one/8
# reads TypeExpr and the clause's own pattern; it never reads the body or any callee).
cd "$(dirname "$0")"; . ./lib.sh
W=$(mktemp -d); mkdir -p $W/An $W/o
cat > $W/An/an.bs <<'BS'
module An
record Order { Id: int, Total: int }
int Helper(int n)
Helper(n) -> n

// body computes on the int: 18 s1(b) says outcome 3 (1.5 + 1 = 2.5), so guarded
public int Incr(int n)
Incr(n) -> n + 1
// body only hands it on (18 s4's example): guarded
public int Pass(int n)
Pass(n) -> Helper(n)
// body never mentions it
public int Ignore(int n, int m)
Ignore(n, m) -> m + 1
// a record the body projects (a field read objects to nothing about identity)
public int Amount(Order o)
Amount(o) -> o.Total
// a record the body hands on
public int PassO(Order o)
PassO(o) -> Amount(o)
BS
bs_build $W/An $W/o || exit 1
abstr $W/o/An.beam | grep -v '^$'
echo
echo "grep of the emitter for any read of a function body when deciding a guard:"
grep -n "guard_one\|boundary_guards" /home/user/beam-sharp/compiler/src/bs_emit.erl | head
sed -n '/^guard_one/,/^%% A public .float/p' /home/user/beam-sharp/compiler/src/bs_emit.erl | grep -n "Body\|body\|callee\|call" || echo "  (no mention of Body / callee in guard_one/8)"
