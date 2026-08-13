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

probe () {
    local name="$1" body="$2"
    printf '%s\n' "$body" > "$WORK/$name.bs"
    echo "--- $name ---"
    "$BSC" -o "$WORK" "$WORK/$name.bs" 2>&1 || true
    echo
}

echo "=== 1. Four named frame types over a bare \`int\` ==="
echo "AMQP's frame type is ONE OCTET. The parameter can only be declared \`int\`."
probe octet_open 'module P1;
type FrameType = :method | :header | :body | :heartbeat;
FrameType Classify(int t);
Classify(1) -> :method;
Classify(2) -> :header;
Classify(3) -> :body;
Classify(8) -> :heartbeat;'

echo "=== 2. The same, with a guard bounding the octet ==="
echo "The guard covers 0..255 exactly. What is left is what an octet cannot hold."
probe octet_guarded 'module P2;
type FrameType = :method | :header | :body | :heartbeat | :reserved;
FrameType Classify(int t);
Classify(1) -> :method;
Classify(2) -> :header;
Classify(3) -> :body;
Classify(8) -> :heartbeat;
Classify(t) when t >= 0 && t <= 255 -> :reserved;'

echo "=== 3. Is a catch-all refused over a CLOSED residual? (ticket 12 §2) ==="
echo "Residual here is :method | :header | :heartbeat — closed, every case named."
probe closed_catchall 'module P3;
type FrameType = :method | :header | :body | :heartbeat;
type Kind = :control | :data;
Kind Classify(FrameType t);
Classify(:body) -> :data;
Classify(t)     -> :control;'

echo "=== 4. What the residual LOOKS LIKE at wire-protocol clause counts ==="
echo "AMQP 0-9-1 defines ~40 methods. Ticket 23 publishes the residual to an agent."
{
    echo 'module P4;'
    echo 'type Method = :known | :unknown;'
    echo 'Method Dispatch(int m);'
    for i in $(seq 10 10 400); do
        echo "Dispatch($i) -> :known;"
    done
} > "$WORK/wide.bs"
echo "--- wide (40 singleton clauses) ---"
"$BSC" -o "$WORK" "$WORK/wide.bs" 2>&1 || true
echo

echo "=== timing the check at that width ==="
START=$(date +%s%N)
for _ in 1 2 3 4 5; do "$BSC" -o "$WORK" "$WORK/wide.bs" >/dev/null 2>&1 || true; done
END=$(date +%s%N)
echo "5 runs of the 40-clause check (includes process start): $(( (END-START)/1000000 )) ms total"
