#!/usr/bin/env bash
# Ticket 59: can a forged value reach a PRIVATE function through an exported one that cannot catch it?
# Each case passes a forgery in a position the exported guard does not inspect (a nested record, a
# record's int field, a list element) and records what the private function does with it — under
# the compiler as it is (base), with the record tag test removed from private functions (v59n),
# and with the int-kind test extended to private functions (v59w).
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
S=$root/artifacts/probes/src59
run () { # variant file mod expr
  BSC_EBIN=$PROBE_HOME/variants/$1/ebin escript $root/artifacts/probes/bsh.escript "$S/$2" "$3" "$4" "${@:5}" 2>&1 | grep -v '^$'; }
for v in base v59n v59w; do
  echo "=========== $v"
  echo "-- nested record with a WRONG Kind but the right field (Who.Kind = 'Rc.Other')"
  run $v nested_tag.bs Rc "'Rc':'Run'(#{'Kind'=>'Rc.Order','Id'=>1,'Who'=>#{'Kind'=>'Rc.Other','Name'=><<\"mallory\">>}})." | tail -2
  echo "-- record int field forged as a float (Count = 100.5), private Classify(>= 9)"
  run $v nested_int.bs Bk "'Bk':'Run'(#{'Kind'=>'Bk.Bucket','Count'=>100.5})." | tail -2
  echo "-- list element forged as a float ([1, 100.5]), private Classify(>= 9)"
  run $v list_elems.bs Ls "'Ls':'Run'([1, 100.5])." | tail -2
done
