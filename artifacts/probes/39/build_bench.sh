#!/usr/bin/env bash
# Builds every artefact the ticket 39 probes time. usage: SCRATCH=<dir with mm/> build_bench.sh
# Layout produced under $SCRATCH:
#   ebin/                      bsc, unpatched                      v39/I1/ebin, v39/I2/ebin   emitter prototypes (patches/v39-*.patch)
#   bench39/                   aoc/bench harness + the four implementations, UNMODIFIED sources
#   bench39/var/{erl,erl_inline,bs,bs_inline,gleam,gleam_noinline}   one factor changed: -compile(inline) added or stripped
#   bench39/var2/{base,I1,I2}  Day01.bs compiled by the REAL emitter, unpatched / module-wide inline / private-only inline
#   bench39/var3/{erl_inline,bs_I2,oracle}
# Deviation from aoc/bench/build.sh: the Gleam project drops its gleam_stdlib dependency (Hex is unreachable here); the source
# file uses nothing from it.
set -euo pipefail
: "${SCRATCH:?}"; H="$(cd "$(dirname "$0")" && pwd)"; P="$H/.."; ROOT="$(cd "$H/../../.." && pwd)"; B=$ROOT/aoc/bench
. "$P/env.sh"
[ -d "$SCRATCH/ebin" ] || "$P/build_variant.sh" none "$SCRATCH/ebin"
for v in I1 I2; do [ -d "$SCRATCH/v39/$v/ebin" ] || "$P/build_variant.sh" v39-$v "$SCRATCH/v39/$v/ebin"; done
O=$SCRATCH/bench39; rm -rf "$O"; mkdir -p "$O/gleam" "$O/asm"
cp -r "$B/gleam/src" "$O/gleam/"; printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > "$O/gleam/gleam.toml"
(cd "$O/gleam" && gleam build >/dev/null 2>&1); cp "$O/gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam" "$O/"
erlc -o "$O" "$B/bench_erl.erl" "$B/bench.erl"; elixirc -o "$O" "$B/bench_ex.ex" >/dev/null 2>&1
BSC_EBIN=$SCRATCH/ebin bsc -o "$O" "$B/Day01" >/dev/null
V=$O/var; mkdir -p $V/{erl,erl_inline,bs,bs_inline,gleam,gleam_noinline}
cp "$O/bench_erl.beam" $V/erl/; erlc +inline -o $V/erl_inline "$B/bench_erl.erl"
M="$H/make_variant.escript"; G=$O/gleam/build/dev/erlang/bench_gleam/_gleam_artefacts/bench_gleam.abstr
$M "$O/Day01.abstr" $V/bs none; $M "$O/Day01.abstr" $V/bs_inline add_inline; $M $G $V/gleam none; $M $G $V/gleam_noinline strip_inline
V2=$O/var2; for v in base I1 I2; do e=$SCRATCH/ebin; [ $v != base ] && e=$SCRATCH/v39/$v/ebin; mkdir -p $V2/$v; BSC_EBIN=$e bsc -o $V2/$v "$B/Day01" >/dev/null; done
V3=$O/var3; mkdir -p $V3/oracle; erlc -o $V3/oracle "$H/oracle/oracle.erl"; cp -r $V/erl_inline $V3/erl_inline; cp -r $V2/I2 $V3/bs_I2
echo "ok: $O"
