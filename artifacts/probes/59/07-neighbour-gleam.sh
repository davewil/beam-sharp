#!/usr/bin/env bash
# Probe 07 — Gleam 1.5.0 (dependency-free package, `gleam compile-package`, because Hex is blocked): does `pub` vs private change the emitted check?
H="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); cp -r "$H/gleam-n/." "$W/"; mkdir -p "$W/out" "$W/lib" "$W/ebin"
/tmp/claude-0/gleamx/gleam --version
/tmp/claude-0/gleamx/gleam compile-package --target erlang --package "$W" --out "$W/out" --lib "$W/lib" --no-beam 2>&1 | tail -3
echo "--- emitted Erlang ---"; cat "$W/out/_gleam_artefacts/n.erl"
erlc -o "$W/ebin" "$W/out/_gleam_artefacts/n.erl" 2>&1 | head -3
echo "--- forged values (no Gleam type can express these) ---"
erl -noshell -pa "$W/ebin" -eval '
  io:format("n:outer({invoice,2,999})  => ~p   (private inner/1 read element 3 of a wrong tuple)~n",[n:outer({invoice,2,999})]),
  io:format("n:bump_pub(1.5)           => ~p~n",[n:bump_pub(1.5)]), halt().'
