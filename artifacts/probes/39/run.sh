#!/usr/bin/env bash
# Ticket 39 (ENG-211) probes. Re-runs every measurement in artifacts/39-emitted-code-quality.md.
#   BSC=/path/to/bsc ./run.sh [WORKDIR]
# BSC defaults to compiler/_build/default/bin/bsc. Needs erl/erlc/elixirc on PATH;
# gleam too if you want the Gleam row (skipped with a notice otherwise).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
BSC="${BSC:-$ROOT/compiler/_build/default/bin/bsc}"
W="${1:-$(mktemp -d)}"; mkdir -p "$W"/{out,v,e,rec/out,rc,ex,gl/src}
cd "$ROOT"

echo "## 0. environment"
erl -noshell -eval 'io:format("OTP ~s, ~p, ~p~n",[erlang:system_info(otp_release),erlang:system_info(emu_flavor),erlang:system_info(system_architecture)]),halt().'

echo; echo "## 1. build: bsc on aoc/bench/Day01, hand-written Erlang variants, beam-sharp variants"
"$BSC" -o "$W/out" aoc/bench/Day01 >/dev/null 2>&1 || "$BSC" -o "$W/out" aoc/bench/Day01
"$HERE/gen_e.sh" "$W/e"
cp "$W/e/e0.erl" "$W/e/e0b.erl"; sed -i 's/-module(e0)/-module(e0b)/' "$W/e/e0b.erl"
(cd "$W/e" && erlc +debug_info *.erl && for m in e0 e1 e2 e3 e4; do erlc -S $m.erl; done)
"$HERE/variants.escript" "$W/out/Day01.abstr" "$W/v"
erlc -o "$W" "$HERE/time.erl"

echo; echo "## 2. disassembly: do the hot functions carry the same {tr,_,Type} annotations?"
echo "   (digest equal  <=> instruction stream identical modulo labels/names)"
"$HERE/disasm.escript" "$W/e/e0.S" "$W/v/bs0.S" "$W/v/bs1.S" "$W/v/bs2.S" "$W/v/bs3.S" \
    "$W/e/e1.S" "$W/e/e2.S" "$W/e/e3.S" "$W/e/e4.S" "$W/v/bs4.S" "$W/v/bs5.S"

echo; echo "## 3. Elixir: same loop through elixirc, forms recovered and re-listed"
if command -v elixirc >/dev/null; then
  EXL="$(dirname "$(readlink -f "$(command -v elixir)")")/../lib/elixir/ebin"
  [ -d "$EXL" ] || EXL=/usr/lib/elixir/lib/elixir/ebin
  cp "$HERE/bench_ex39.ex" "$W/ex/bench_ex.ex"; cp "$HERE/dump_elixir.erl" "$W/ex/"
  (cd "$W/ex" && elixirc -o . bench_ex.ex >/dev/null && erlc dump_elixir.erl \
     && erl -noshell -pa "$EXL" -run dump_elixir main Elixir.BenchEx.beam ex.S >/dev/null)
  "$HERE/disasm.escript" "$W/ex/ex.S"
fi

echo; echo "## 4. Gleam: its generated Erlang header and listing"
GLB=""
if command -v gleam >/dev/null; then
  cp aoc/bench/gleam/src/bench_gleam.gleam "$W/gl/src/"
  printf 'name = "bench_gleam"\nversion = "1.0.0"\ntarget = "erlang"\n' > "$W/gl/gleam.toml"
  (cd "$W/gl" && gleam build >/dev/null 2>&1)
  GLB="$W/gl/build/dev/erlang/bench_gleam/ebin"
  A="$W/gl/build/dev/erlang/bench_gleam/_gleam_artefacts"
  sed -n 1,2p "$A/bench_gleam.erl"
  (cd "$A" && erlc -S bench_gleam.erl) && "$HERE/disasm.escript" "$A/bench_gleam.S"
else echo "gleam not on PATH; skipped"; fi

echo; echo "## 5. timing (interleaved, 41 rounds each; run 3 times to show run-to-run spread)"
MODS="e0 e0b bs0 bs1 bs2 bs3 e1 e2 e3 e4 bs4 bs5"
PA=(-pa "$W" -pa "$W/e" -pa "$W/v")
if [ -n "$GLB" ]; then PA+=(-pa "$GLB"); MODS="$MODS bench_gleam"; fi
if [ -d "${EXL:-}" ]; then PA+=(-pa "$W/ex" -pa "$EXL"); MODS="$MODS Elixir.BenchEx"; fi
for i in 1 2 3; do echo "-- run $i"; erl -noshell "${PA[@]}" -run time main $MODS 2>&1 | grep -E 'min|OTP'; done

echo; echo "## 6. record Kind-tag guard (ticket 39 §3 'never measured'; also ticket 59's private-function claim)"
"$BSC" -o "$W/rec/out" "$HERE/rec/Rec" >/dev/null
"$HERE/rec_noguard.escript" "$W/rec/out/Rec.abstr" "$W/rec/out"
erl -noshell -eval 'compile:file("'"$W"'/rec/out/Rec.abstr",[from_abstr,'"'S'"',{outdir,"'"$W"'/rec/out"}]),halt().'
echo "-- tag test present in private WeightP? (expect map_get Kind + is_eq_exact)"
awk '/^\{function, .WeightP/,/^\{function, .Make/' "$W/rec/out/Rec.S" | grep -E "map_get|is_eq_exact"
erlc -o "$W/rc" "$HERE/rec_cost.erl"
for i in 1 2 3; do echo "-- run $i"; erl -noshell -pa "$W/rc" -pa "$W/rec/out" -run rec_cost main | grep -E 'min|OTP'; done
echo; echo "## 7. what -compile(inline) costs: bytes and stack frames"
"$HERE/inline_cost.sh" "$W"
echo; echo "workdir: $W"
