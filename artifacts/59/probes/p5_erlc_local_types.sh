#!/usr/bin/env bash
cd "$(dirname "$0")"; T=$(mktemp -d); cp p5_erlc_local_types.erl "$T/"; cd "$T"
erlc -S p5_erlc_local_types.erl 2>&1
awk '/^{function,/ {f=$0} /is_integer/ {c[f]++} END {for (k in c) print c[k], "is_integer test(s) in", k}' p5_erlc_local_types.S | sort -k5
echo "--- functions present:"; grep -o '^{function, [a-z0-9_]*, [0-9]*' p5_erlc_local_types.S
