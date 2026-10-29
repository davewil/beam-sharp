#!/bin/bash
# Re-run every probe. Gleam binary path is the scratchpad copy.
set -u; cd "$(dirname "$0")"
(cd p1 && escript gen.escript && escript chunks.escript)
(cd p2 && ./gen.sh && escript bench.escript)
(cd p2b && ./gen.sh && escript bench.escript && ./pat.sh)
(cd p2c && ./run.sh)
(cd p3 && erlc forge.erl forge_fun.erl && erl -noshell -s forge main -s init stop && erl -noshell -s forge_fun main -s init stop)
(cd p4/gl && PATH=$PATH:/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/gleam-bin gleam build >/dev/null 2>&1; cd .. && mkdir -p gebin gebin_tmp && cp gl/build/dev/erlang/probe/_gleam_artefacts/probe.erl gebin_tmp/probe.erl && erlc -o gebin gebin_tmp/probe.erl && erlc gl_forge.erl && erl -noshell -pa gebin -s gl_forge main -s init stop; elixir ex.exs)
