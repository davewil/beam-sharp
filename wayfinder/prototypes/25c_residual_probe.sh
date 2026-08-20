#!/usr/bin/env bash
# PROTOTYPE 25c — can the surface state that a wire field is an octet?
#
# Throwaway. Ticket 25, exemplar 3. Runs the walking skeleton (`compiler/`) over
# four probes and prints the exhaustiveness residual for each. The question is
# ticket 12 §2's — a catch-all is legal only over an OPEN residual — asked of a
# wire protocol, where every dispatch field has a width.
#
#   ./25c_residual_probe.sh
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

# One directory per probe, NAMED AFTER THE MODULE. F15 broke this script in
# two ways at once and both were silent: a directory is now one module, so
# sharing $WORK made probe 2 onward fail with "one directory is one module,
# and this one declares N"; and a module's declaration must match its
# directory name, so a dir named for the probe rejected a body declaring
# `module P1`. Probe 1 alone still passed, which is why the rot was quiet
# and the prototype's prose went on reporting results the script could no
# longer produce. Found 2026-08-20 re-verifying these results for ticket 30.
probe () {
    local name="$1" body="$2"
    local mod
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name ---"
    "$BSC" -o "$WORK/$name/$mod" "$WORK/$name/$mod/$mod.bs" 2>&1 || true
    echo
}

echo "=== 1. Four named frame types over a bare \`int\` ==="
echo "AMQP's frame type is ONE OCTET. The parameter can only be declared \`int\`."
probe octet_open 'module P1
type FrameType = :method | :header | :body | :heartbeat
FrameType Classify(int t)
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
Classify(8) -> :heartbeat'

echo "=== 2. The same, with a guard bounding the octet ==="
echo "The guard covers 0..255 exactly. What is left is what an octet cannot hold."
probe octet_guarded 'module P2
type FrameType = :method | :header | :body | :heartbeat | :reserved
FrameType Classify(int t)
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
Classify(8) -> :heartbeat
Classify(t) when t >= 0 and t <= 255 -> :reserved'

echo "=== 2b. CONTROL: is each half of that guard credited independently? ==="
echo "If a single-sided guard leaves exactly \`int <= -1\`, the checker's interval"
echo "reasoning is sound and the gap in probe 2 is the SIGNATURE's, not the checker's."
probe octet_one_sided 'module P2b
type FrameType = :method | :header | :body | :heartbeat | :reserved
FrameType Classify(int t)
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
Classify(8) -> :heartbeat
Classify(t) when t >= 0 -> :reserved'

echo "=== 2c. F2: the SIGNATURE says it, and the residual closes ==="
echo "This is what probes 1 and 2 could not write. The gap they measured was the"
echo "signature's, and \`type Octet\` is what closes it — so the residual here is"
echo "252 octets the compiler can NAME, where probe 2's was values a wire cannot"
echo "even carry."
probe octet_refined 'module P2c
type Octet = int where value >= 0 and value <= 255
type FrameType = :method | :header | :body | :heartbeat
FrameType Classify(Octet t)
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
Classify(8) -> :heartbeat'

echo "=== 3. Is a catch-all refused over a CLOSED residual? (ticket 12 §2) ==="
echo "Residual here is :method | :header | :heartbeat — closed, every case named."
echo "NOTE the \`_\`. This probe used to write \`Classify(t)\`, a bare NAME, which"
echo "12 §2 does not refuse and never did: the rule is about DISCARDING a case."
probe closed_catchall 'module P3
type FrameType = :method | :header | :body | :heartbeat
type Kind = :control | :data
Kind Classify(FrameType t)
Classify(:body) -> :data
Classify(_)     -> :control'

echo "=== 3b. F2: the span pattern is what answers probe 2c ==="
echo "Seven clauses, 256 values, no catch-all. This is the program probe 2c"
echo "rejects, written with the one construct that makes it writable."
probe span_discharges 'module P3b
type Octet = int where value >= 0 and value <= 255
type FrameType = :method | :header | :body | :heartbeat | :reserved
FrameType Classify(Octet t)
Classify(1)             -> :method
Classify(2)             -> :header
Classify(3)             -> :body
Classify(8)             -> :heartbeat
Classify(0)             -> :reserved
Classify(>= 4 and <= 7) -> :reserved
Classify(>= 9)          -> :reserved'

echo "=== 4. What the residual LOOKS LIKE at wire-protocol clause counts ==="
echo "AMQP 0-9-1 defines ~40 methods. Ticket 23 publishes the residual to an agent."
echo "Ticket 43 truncates the PROSE at three cases; the term keeps all 41."
mkdir -p "$WORK/wide/P4"
{
    echo 'module P4'
    echo 'type Method = :known | :unknown'
    echo 'Method Dispatch(int m)'
    for i in $(seq 10 10 400); do
        echo "Dispatch($i) -> :known"
    done
} > "$WORK/wide/P4/P4.bs"
echo "--- wide (40 singleton clauses) ---"
"$BSC" -o "$WORK/wide/P4" "$WORK/wide/P4/P4.bs" 2>&1 || true
echo

echo "=== timing the check at that width ==="
START=$(date +%s%N)
for _ in 1 2 3 4 5; do "$BSC" -o "$WORK/wide/P4" "$WORK/wide/P4/P4.bs" >/dev/null 2>&1 || true; done
END=$(date +%s%N)
echo "5 runs of the 40-clause check (includes process start): $(( (END-START)/1000000 )) ms total"
