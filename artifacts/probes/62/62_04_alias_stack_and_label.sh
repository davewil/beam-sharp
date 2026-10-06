#!/usr/bin/env bash
# PROBE 62-04 — Claims: (a) a snake_case alias emitted as a thin wrapper `which(A) -> 'Which'(A).` compiles to a
# jump (call_only), adds NO stack frame and does not break tail-calls; (b) BEAM can export two names to one label
# (ExpT patched by hand on the real Shop.beam) — the alternative to a wrapper.
# CONTROLS: a non-tail wrapper (`R = 'Which'(A), R`) must show an extra frame; a non-tail recursion must GROW memory.
# Run from repo root: bash artifacts/probes/62/62_04_alias_stack_and_label.sh
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/ebin" "$W/sh"
$BSC --src-root compiler/examples -o "$W/sh" compiler/examples/Shop >/dev/null 2>&1
H=artifacts/probes/62
erlc -o "$W/ebin" $H/alias_xform.erl $H/alias_trace.erl
cd "$W" && erl -noshell -pa ebin -eval 'alias_trace:main(["sh"]), halt().'
