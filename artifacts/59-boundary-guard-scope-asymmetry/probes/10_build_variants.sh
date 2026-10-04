#!/bin/bash
# Probe 10 (e, part 1): build the three compiler variants from a COPY of compiler/ (the real
# tree is never touched). base = untouched copy; narrow.patch = record tag test exported-only;
# wide.patch = int kind / range / float tests on private functions too.
# proj = narrow.patch + proj.patch = option C: tag test exported-only AND the exported entry also tests the
# record-typed and int-typed FIELDS of its record parameter (ticket 46 s4's 'fixed number of projections', one level). Output: /tmp/p59/bin/bsc-{base,narrow,wide,proj}
cd "$(dirname "$0")"; P=$(pwd); . ./lib.sh
SRC=/home/user/beam-sharp/compiler; mkdir -p /tmp/p59/bin /tmp/p59/bv
for v in base narrow wide proj; do
  rm -rf /tmp/p59/bv/$v; mkdir -p /tmp/p59/bv/$v
  cp -r $SRC/src $SRC/bin $SRC/rebar.config $SRC/rebar.lock /tmp/p59/bv/$v/
  [ $v != base ] && (cd /tmp/p59/bv/$v/src && { [ $v = proj ] && patch -s bs_emit.erl < $P/narrow.patch; patch -s bs_emit.erl < $P/$v.patch; })
  (cd /tmp/p59/bv/$v && /tmp/tc/rebar3 escriptize >/tmp/p59/bv/$v.build.log 2>&1) || { echo "BUILD FAILED $v"; tail -20 /tmp/p59/bv/$v.build.log; exit 1; }
  cp /tmp/p59/bv/$v/_build/default/bin/bsc /tmp/p59/bin/bsc-$v
  echo "built bsc-$v  $(md5sum < /tmp/p59/bin/bsc-$v | cut -c1-12)  $(diff <(cat $SRC/src/bs_emit.erl) /tmp/p59/bv/$v/src/bs_emit.erl | grep -c '^[<>]') changed lines in bs_emit.erl"
done
