#!/usr/bin/env bash
# Verifier's extra probe for ticket 59 (not the author's). Three forgeries not in the brief:
#  U  private params declared as a UNION of records (no tag test is emitted for a union), forged nested Who
#  H  forged nested Customer through TWO private hops (Hop1 -> Hop2)
#  T  tuple (:pair, 100.5) through the exported fn and two private hops into private Cls(>= 9)
# plus controls: a legitimate value must succeed under all three builds.
. "$(cd "$(dirname "$0")/../probes" && pwd)/env.sh"
S=$root/artifacts/verification/59-extra-src
run () { BSC_EBIN=$PROBE_HOME/variants/$1/ebin escript $root/artifacts/probes/bsh.escript "$S/$2" "$3" "$4" "${@:5}" 2>&1 | grep -v '^$' | grep -v 'beam bytes'; }
for v in base v59n v59w; do
  echo "=========== $v"
  echo "U forged union member (Kind='Rc.Other' with Name):"; run $v union.bs Un "'Un':'Run'(#{'Kind'=>'Un.Order','Id'=>1,'Who'=>#{'Kind'=>'Un.Other','Name'=><<\"mallory\">>}})." 
  echo "U control (real Person):"; run $v union.bs Un "'Un':'Run'(#{'Kind'=>'Un.Order','Id'=>1,'Who'=>#{'Kind'=>'Un.Person','Name'=><<\"ok\">>}})."
  echo "H forged Customer via two private hops:"; run $v hops.bs Hp "'Hp':'Run'(#{'Kind'=>'Hp.Order','Id'=>1,'Who'=>#{'Kind'=>'Hp.Other','Name'=><<\"mallory\">>}})."
  echo "H control:"; run $v hops.bs Hp "'Hp':'Run'(#{'Kind'=>'Hp.Order','Id'=>1,'Who'=>#{'Kind'=>'Hp.Customer','Name'=><<\"ok\">>}})."
  echo "T tuple float via two hops (expect high-or-refusal):"; run $v tup.bs Tp "'Tp':'Run'({pair, 100.5})."
  echo "T control {pair, 100}:"; run $v tup.bs Tp "'Tp':'Run'({pair, 100})."
done
