#!/usr/bin/env bash
# Reruns every probe for ticket 52 from scratch; non-zero if any expected observation fails.
# Needs: erl/erlc (OTP 25 tested), elixir/mix 1.14 on PATH, gleam at $GLEAM (p7 skipped, loudly, if absent).
D="$(cd "$(dirname "$0")" && pwd)"; rc=0
for p in p1_undef_and_tools p2_attribute_cost p3_presence_checks p4_module_to_app p5_vm_speaks_app_names p6_elixir p7_gleam p8_app_files_are_name_only p9_corpus_usings p10_check_cost; do
  echo; echo "################ $p"
  if [ "$p" = p7_gleam ] && [ ! -x "${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam}" ]; then echo "SKIPPED: no gleam binary"; continue; fi
  ( cd "$(mktemp -d)" && bash "$D/$p.sh" ) >"${TMPDIR:-/tmp}/$p.log" 2>&1; r=$?
  cat "${TMPDIR:-/tmp}/$p.log"; rm -f "${TMPDIR:-/tmp}/$p.log"
  echo ">> $p exit=$r"; [ $r -eq 0 ] || rc=1
done
echo; [ $rc -eq 0 ] && echo "ALL PROBES HELD" || echo "SOME PROBE FAILED"; exit $rc
