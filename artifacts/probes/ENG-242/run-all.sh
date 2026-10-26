#!/usr/bin/env bash
# Re-runs every probe behind artifacts/ENG-242-decision-brief.md. Needs erl 25+, elixir 1.14+,
# mix, elm; network only for the Elm registry (expected to fail here) and the Gleam source fetch.
cd "$(dirname "$0")"
for s in p1_beam_cannot_restrict.sh p2_erlang_xref_whitelist.sh p3_erlang_otp25_moduledoc.sh \
         p5_corpus_audiences.sh ex/xref.sh elm/run.sh gleam/fetch-and-grep.sh ex/time200.sh; do
  echo "################ $s"; bash "$s" 2>&1
done
echo "################ ex/driver.exs on the 3-module project (plain, then traced)"
(cd /tmp && for m in plain trace; do elixir "$OLDPWD/ex/driver.exs" $m "$OLDPWD/ex/proj3"; echo "exit=$?"; done)
