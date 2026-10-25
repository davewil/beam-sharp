#!/usr/bin/env bash
# Does the union-name prototype change the verdict or the .abstr of any shipped example? (stock vs prototype, byte-compare .abstr)
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
W=$S/66/corpus2; rm -rf $W; mkdir -p $W/a $W/b; cp -r /home/user/beam-sharp/compiler/examples $W/examples
cd $W/examples; n=0; diffs=0
for d in $(find . -path ./exemplars -prune -o -name '*.bs' -print | xargs -n1 dirname | sort -u); do
  d=${d#./}; n=$((n+1))
  $S/bsc --src-root . -o $W/a $d >$W/a.log 2>&1; ra=$?
  $S/66/bsc_proto --src-root . -o $W/b $d >$W/b.log 2>&1; rb=$?
  if [ $ra != $rb ] || ! cmp -s $W/a.log $W/b.log; then echo "DIFF diag/rc: $d"; diffs=$((diffs+1)); fi
done
for f in $W/a/*.abstr; do cmp -s $f $W/b/$(basename $f) || { echo "DIFF abstr: $(basename $f)"; diffs=$((diffs+1)); }; done
echo "modules=$n abstr_files=$(ls $W/a/*.abstr | wc -l) differences=$diffs"
