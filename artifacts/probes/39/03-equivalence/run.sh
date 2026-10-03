#!/usr/bin/env bash
# Is beam-sharp's emitted module the same as Erlang's? Per-function comparison of the +to_asm
# listing (labels renamed, line/func_info dropped; {tr,..} and var_info KEPT), plus raw chunks.
set -e
source "$(dirname "$0")/../common.sh"
cd "$(dirname "$0")"
A="$PWD/../02-asm/work"; B="$PWD/../01-rerun/build"
[ -f "$A/beamsharp.S" ] || bash ../02-asm/run.sh >/dev/null 2>&1
erlc eq.erl
erl -noshell -pa . -eval 'eq:main(["'$A'/erlang.S","'$A'/beamsharp.S","'$B'/bench_erl.beam","'$B'/Day01.beam"])'
