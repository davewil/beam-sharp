#!/usr/bin/env bash
# Probe 10 — the cost of the only way to make "exported-only" sound for containers: check elements at the door.
# HAND-WRITTEN Erlang (bsc emits no element check; probe 01). OTP 25 on this VM.
H="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); erlc -o "$W" "$H/deep_door.erl" && erl -noshell -pa "$W" -eval 'deep_door:run(), halt().'
