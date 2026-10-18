#!/usr/bin/env bash
# Runs every probe for ticket 59 (ENG-241) in order.  Each prints its own measurement.
#   FULL=1 ./run.sh   also runs 08_eunit.sh (the repo suite per variant: ~10 min each)
# Needs: erl/elixir (OTP 25 / Elixir 1.14), gleam 1.12.0 and elm in /tmp/bin, and a bsc built
# by build_variants.sh (which patches compiler/src's leex shim for OTP 25; see README.md).
set -u
cd "$(dirname "$0")"
[ -x "${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}/var/v4/bsc" ] || ./build_variants.sh
for p in 01_repro 02_escape 02b_foreign_callback 03_reach 10_cross_file_escape 04_variants 06_single_guard_bytes 07_handwritten_loop 05_bytes_and_time 09_corpus_size survey/erlang_elision survey/gleam; do
  echo; echo "################ $p"; ./$p.sh 2>&1 | head -80
done
echo; echo "################ survey/elixir_defp"; elixir survey/elixir_defp.exs 2>&1 | grep -v "^warning\|elixir_defp.exs:2\|^$" | head -12
[ "${FULL:-0}" = 1 ] && ./08_eunit.sh
