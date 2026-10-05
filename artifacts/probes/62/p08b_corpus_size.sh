#!/usr/bin/env bash
# P08b: the same size question on the repo's REAL example modules (compiler/examples/*), where bodies are not 1-liners.
# CLAIM: a delegating alias costs less than duplicate bodies on real code. REFUTED IF thin total >= dup total on the corpus.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
W="$SCRATCH/p08b"; rm -rf "$W"; mkdir -p "$W"
EX="$REPO/compiler/examples"
tn=0; tt=0; td=0; sn=0; st=0; sd=0; mods=0; fns=0
printf "%-18s %7s %7s %7s | %7s %7s %7s | pubfns\n" module none thin dup none_s thin_s dup_s
for d in "$EX"/*/; do
  m=$(basename "$d"); [ "$m" = exemplars ] && continue
  ok=1; line=""
  for mode in none thin dup; do
    o="$W/$m/$mode"; mkdir -p "$o"
    if [ $mode = none ]; then "$BSC" --src-root "$EX" -o "$o" "$d" >/dev/null 2>&1 || ok=0
    else BS_ALIAS=$mode "$BSC_ALIAS" --src-root "$EX" -o "$o" "$d" >/dev/null 2>&1 || ok=0; fi
  done
  [ $ok = 1 ] || { echo "$m: SKIPPED (does not compile standalone or alias compiler errored: $(BS_ALIAS=thin "$BSC_ALIAS" --src-root "$EX" -o "$W/x" "$d" 2>&1 | head -1 | cut -c1-120))"; continue; }
  # the module's own beam (name == dir name, possibly with a dotted path); take every beam directly produced
  for b in "$W/$m/none"/*.beam; do
    f=$(basename "$b")
    r=$(for mode in none thin dup; do escript "$HERE/sizes.escript" "$W/$m/$mode/$f" | sed 's/total=\([0-9]*\) stripped=\([0-9]*\) exports=\([0-9]*\).*/\1 \2 \3/'; done)
    set -- $r; n=$1; ns=$2; ne=$3; t=$4; ts=$5; d=$7; ds=$8
    printf "%-18s %7s %7s %7s | %7s %7s %7s | exports(none)=%s\n" "${f%.beam}" $n $t $d $ns $ts $ds $ne
    tn=$((tn+n)); tt=$((tt+t)); td=$((td+d)); sn=$((sn+ns)); st=$((st+ts)); sd=$((sd+ds)); mods=$((mods+1))
  done
done
printf "TOTAL (%d beams)    %7s %7s %7s | %7s %7s %7s\n" $mods $tn $tt $td $sn $st $sd
echo "thin vs none: +$((100*(tt-tn)/tn))% (beam), +$((100*(st-sn)/sn))% (stripped); dup vs none: +$((100*(td-tn)/tn))% (beam), +$((100*(sd-sn)/sn))% (stripped)"
