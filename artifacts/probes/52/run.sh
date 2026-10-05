#!/usr/bin/env bash
# Re-executes every probe for ticket 52 from scratch and captures RAW output in out/.
#   ./run.sh               all probes (the dialyzer PLT build in 08 takes ~2 minutes)
#   RUN_EUNIT=1 ./run.sh   also the repo's eunit suite on the patched copy (~6 minutes, runs twice)
# Needs: the toolchain env.sh below (OTP 28, Elixir 1.19, gleam, elm, rebar3, built bsc), no network.
# The repo's compiler/ is only ever READ (copied to $WORK for the patched build).
cd "$(dirname "$0")"
. /tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/env.sh
rm -rf out; mkdir -p out
for p in 00-fixtures 04-build-patched-bsc 01-bsc-today 02-codepath-queries 03-versions-and-name \
         05-patched-behaviour 06-size-and-cost 07-corpus-census 08-ecosystem-readers 09-erlang-and-rebar3 \
         10-elixir-mix 11-gleam 12-elm 13-attribute-to-app 14-module-to-app-rule 15-surface-today \
         16-prototype-suite 17-otp-app-names; do
  T0=$(date +%s); bash "./$p.sh" > "out/$p.txt" 2>&1; rc=$?
  printf '%-28s exit=%d  %3ds  out/%s.txt (%s lines)\n' "$p" "$rc" "$(( $(date +%s)-T0 ))" "$p" "$(wc -l < out/$p.txt)"
done
