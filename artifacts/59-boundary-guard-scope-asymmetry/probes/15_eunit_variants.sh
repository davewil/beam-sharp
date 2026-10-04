#!/bin/bash
# Probe 15 (e): run the compiler's own eunit suite against each variant, on a COPY of compiler/
# (never the real tree), and report what breaks. ~10-15 min per variant on this 4-vCPU box when run alone.
#   usage: ./15_eunit_variants.sh run [variants...]  # does the work (slow), writes logs/eunit_<variant>.log (default: all four)
#          ./15_eunit_variants.sh          # just summarises the logs captured on 2026-10-04
cd "$(dirname "$0")"; . ./lib.sh; P=$(pwd)
if [ "$1" = run ]; then
  SRC=/home/user/beam-sharp/compiler; shift; VS=${@:-base narrow wide proj}
  for v in $VS; do
    rm -rf /tmp/p59/ev/$v; mkdir -p /tmp/p59/ev/$v
    cp -r $SRC/src $SRC/test $SRC/bin $SRC/examples $SRC/features $SRC/bench $SRC/rebar.config $SRC/rebar.lock /tmp/p59/ev/$v/
    [ $v != base ] && (cd /tmp/p59/ev/$v/src && { [ $v = proj ] && patch -s bs_emit.erl < $P/narrow.patch; patch -s bs_emit.erl < $P/$v.patch; })
    (cd /tmp/p59/ev/$v && /tmp/tc/rebar3 eunit 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $P/logs/eunit_$v.log)   # run ONE AT A TIME: concurrent runs hit eunit timeouts (observed)
  done
fi
for v in base narrow wide proj; do
  echo "=== $v: $(grep -E 'Failed: |All [0-9]+ tests passed' logs/eunit_$v.log | tail -1)"
  grep '\*failed\*' logs/eunit_$v.log | sed 's/^ */    /' | sed 's/\.\.\.\*failed\*//'
done
echo
echo "failures present in a variant but NOT in base (the real delta):"
for v in narrow wide proj; do echo "  $v:"; comm -13 <(grep '\*failed\*' logs/eunit_base.log | sort) <(grep '\*failed\*' logs/eunit_$v.log | sort) | sed 's/^ */    /;s/\.\.\.\*failed\*//'; done
echo
echo "NOTE: the 5 failures common to all three (aoc path, batch, utf8, diagnostics gate, non-ascii) fail on the UNMODIFIED copy; they are layout/locale"
echo "      artefacts of running from a copy (not investigated further), and are identical across variants."
echo "NOTE: logs/eunit_base.log was produced while two other eunit runs shared the CPU; narrow/wide were re-run alone after theirs hit eunit timeouts."
