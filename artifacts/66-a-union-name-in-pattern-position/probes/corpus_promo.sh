#!/usr/bin/env bash
# Compile every example module dir with the stock bsc and with a COPY compiled with
# vacuous_clause promoted to error (bs_check.erl:4785 warning->error). Usage: corpus_promo.sh
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
W=$S/66/corpus; rm -rf $W; mkdir -p $W; cp -r /home/user/beam-sharp/compiler/examples $W/examples
cd $W/examples
n=0
for d in $(find . -path ./exemplars -prune -o -name '*.bs' -print | xargs -n1 dirname | sort -u); do
  n=$((n+1)); d=${d#./}
  a=$($S/bsc --src-root . $d 2>&1); ra=$?
  b=$($S/66/bsc_promo --src-root . $d 2>&1); rb=$?
  w=$(grep -c ': warning:' <<<"$a")
  echo "$d base_rc=$ra promo_rc=$rb warnings=$w"
  [ $ra != $rb ] && echo "  DIVERGES"
  grep ': warning:' <<<"$a" | sed 's/^/    /'
done
echo "modules=$n"
