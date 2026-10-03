#!/bin/sh
# usage: corpus.sh WORKDIR -- compile every compiler/examples module dir with base/proto/wide; count how many emitted guards change
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
W=$1; EX=/home/user/beam-sharp/compiler/examples; cd "$(dirname "$0")"; rm -rf o; mkdir o
ok=0; fail=0
for d in $EX/*/ $EX/exemplars/*/; do m=$(basename $d); [ $m = exemplars ] && continue
  for v in base proto wide; do ../bsc-run.sh $W/$v/ebin --src-root $EX -o o/$v/$m $EX/$m >/dev/null 2>o/$v-$m.err || true; done
  if [ -n "$(ls o/base/$m/*.abstr 2>/dev/null)" ]; then ok=$((ok+1)); else fail=$((fail+1)); echo "  (not compiled: $m)"; fi
done
echo "tag tests ('Kind' occurrences) in shipped output: $(cat o/base/*/*.abstr | grep -o "'Kind'" | wc -l)"
echo "modules compiled by shipped compiler: $ok   not compiled: $fail"
for v in proto wide; do
  n=0; changed=""
  for f in o/base/*/*.abstr; do m=$(echo $f | cut -d/ -f3); b=$(basename $f)
    if ! cmp -s $f o/$v/$m/$b; then n=$((n+1)); changed="$changed $m/$b"; fi; done
  echo "$v: $n modules emit a different .abstr than shipped:$changed"
done
for v in proto wide; do
  echo "guard count diff ($v vs base): tag tests=$(( $(cat o/$v/*/*.abstr | grep -o "'Kind'" | wc -l) - $(cat o/base/*/*.abstr | grep -o "'Kind'" | wc -l) ))  is_integer=$(( $(cat o/$v/*/*.abstr | grep -o 'is_integer' | wc -l) - $(cat o/base/*/*.abstr | grep -o 'is_integer' | wc -l) ))  is_float=$(( $(cat o/$v/*/*.abstr | grep -o 'is_float' | wc -l) - $(cat o/base/*/*.abstr | grep -o 'is_float' | wc -l) ))"
done
