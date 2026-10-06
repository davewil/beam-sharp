#!/usr/bin/env bash
# PROBE 60b -- ticket 60 (ENG-242). Claims, each against the REAL bsc built from compiler/src:
#   B1. Today bsc has no "who": a module that was never meant to name Lab.Core compiles and runs
#       when it writes `using Lab.Core` and calls a public function.            (no-who, measured)
#   B2. CONTROL: the "what" half works: the same Stranger calling a PRIVATE function is refused.
#   B3. A caller restriction would have to be a source check: Stranger reaches Lab.Core.Sum
#       with no `using Lab.Core` and no remote call form naming it, by (a) a function value Core
#       hands out, (b) :erlang.apply through a foreign declaration. Both compile and run.
#   B4. `private` is already porous to function values (Core.Leak returns its private Hidden).
# Needs: BSC from env.sh (run from repo root). Usage: BSC=... ./60b_bsharp_today_has_no_who.sh
set -uo pipefail
: "${BSC:?source scratchpad env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/Lab/Core" "$W/src/Lab/Friend" "$W/src/Lab/Stranger" "$W/o"
cat > "$W/src/Lab/Core/Core.bs" <<'E'
module Lab.Core

public int Sum(int a, int b)
Sum(a, b) -> a + b

private int Hidden(int n)
Hidden(n) -> n * 100

public fn(int) -> int Leak()
Leak() -> Hidden
E
cat > "$W/src/Lab/Friend/Friend.bs" <<'E'
module Lab.Friend
using Lab.Core

public int Go(int n)
Go(n) -> Sum(n, 1)
E
cat > "$W/src/Lab/Stranger/Stranger.bs" <<'E'
module Lab.Stranger
using Lab.Core

public int Direct(int n)
Direct(n) -> Sum(n, 2)

public int ViaValue(int n)
ViaValue(n) -> Run(Leak(), n)

private int Run(fn(int) -> int f, int n)
Run(f, n) -> f(n)
E
mkdir -p "$W/src/Lab/Sneak"
cat > "$W/src/Lab/Sneak/Sneak.bs" <<'E'
module Lab.Sneak

using :erlang {
    int apply(atom m, atom f, list<int> args)
}

// no `using Lab.Core`, no remote-call form naming it: the module atom arrives at run time
public int Dyn(atom m, atom f, int n)
Dyn(m, f, n) -> :erlang.apply(m, f, [n, 3])
E
mkdir -p "$W/src/Lab/Peek"
cat > "$W/src/Lab/Peek/Peek.bs" <<'E'
module Lab.Peek
using Lab.Core

public int Go(int n)
Go(n) -> Hidden(n)
E
echo "--- compile Friend, Stranger, Sneak (expect exit 0 each: no 'who' exists)"
for m in Friend Stranger Sneak; do
  "$BSC" --src-root "$W/src" -o "$W/o" "$W/src/Lab/$m" >"$W/$m.log" 2>&1; echo "Lab.$m exit=$?"; head -3 "$W/$m.log"
done
echo "--- CONTROL: Peek calls the private Hidden (expect nonzero exit, a refusal)"
"$BSC" --src-root "$W/src" -o "$W/o2" "$W/src/Lab/Peek" 2>&1 | head -4; echo "Lab.Peek exit=${PIPESTATUS[0]}"
echo "--- run"
erl -noshell -pa "$W/o" -eval '
  io:format("Friend:Go(1)        = ~p~n", [(catch '"'"'Lab.Friend'"'"':'"'"'Go'"'"'(1))]),
  io:format("Stranger:Direct(1)  = ~p~n", [(catch '"'"'Lab.Stranger'"'"':'"'"'Direct'"'"'(1))]),
  io:format("Stranger:ViaValue(1)= ~p   (Core.Leak handed out private Hidden/1)~n", [(catch '"'"'Lab.Stranger'"'"':'"'"'ViaValue'"'"'(1))]),
  io:format("Sneak:Dyn(Core,Sum,1)= ~p   (reached Lab.Core:Sum by atoms)~n", [(catch '"'"'Lab.Sneak'"'"':'"'"'Dyn'"'"'('"'"'Lab.Core'"'"', '"'"'Sum'"'"', 1))]),
  halt().'
