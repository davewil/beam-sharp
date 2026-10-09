#!/usr/bin/env bash
# The compiler delta for the inline lever: ONE extra form in bs_emit's output, {attribute,0,compile,inline}
# (or {inline,[{F,A}...]}).  (1) is the attribute form equivalent to erlc +inline?  (2) what does it cost across the
# compiler's own examples corpus: BEAM bytes, compile time, behaviour (stack-trace frames)?
. "$(dirname "$0")/env.sh"
V=$W/p12; rm -rf $V; mkdir -p $V
echo "### (1) attribute form on the Day01 benchmark, vs +inline, vs default (interleaved, 100 rounds, x2)"
for v in attr listed; do
  case $v in attr) F='{attribute,0,compile,inline}.';; listed) F="{attribute,0,compile,{inline,[{'Wrap',1},{'Hit',1}]}}.";; esac
  sed "s/'Day01'/'d_$v'/" $W/ebin/Day01.abstr | awk -v f="$F" 'NR==2{print; print f; next}{print}' > $V/d_$v.abstr
  erlc +from_abstr -o $V $V/d_$v.abstr
done
sed "s/'Day01'/'d_plain'/" $W/ebin/Day01.abstr > $V/d_plain.abstr; erlc +from_abstr -o $V $V/d_plain.abstr
for i in 1 2; do erl -noshell -pa $V -pa $W/ebin -eval 'bench2:main(["'$INPUT'","100","plain:d_plain:PartTwo","attr_inline:d_attr:PartTwo","listed_inline:d_listed:PartTwo","gleam:bench_gleam:part_two"])' | tail -5; echo; done
echo "### (2) corpus cost: compile every compiler/examples module that bsc accepts, then erlc the .abstr with/without +inline"
C=$V/corpus; mkdir -p $C
n=0; for d in $REPO/compiler/examples/*/; do m=$(basename $d); \
  $BSC --src-root $REPO/compiler/examples -o $C/$m $d >/dev/null 2>&1 && n=$((n+1)); done
echo "modules built by bsc: $n"
mkdir -p $C/_a; for f in $C/*/*.abstr; do cp $f $C/_a/; done; ls $C/_a | wc -l
for mode in plain inline; do
  rm -rf $V/o_$mode; mkdir -p $V/o_$mode
  opt=""; [ $mode = inline ] && opt="+inline"
  for rep in 1 2 3; do
    rm -f $V/o_$mode/*; t0=$(date +%s.%N)
    for f in $C/_a/*.abstr; do erlc +from_abstr $opt -o $V/o_$mode $f 2>/dev/null; done
    t1=$(date +%s.%N); echo "$mode rep$rep compile wall=$(echo "$t1 - $t0" | bc)s"
  done
  echo "$mode total beam bytes: $(cat $V/o_$mode/*.beam | wc -c) (files: $(ls $V/o_$mode/*.beam | wc -l))"
done
