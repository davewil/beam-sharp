#!/usr/bin/env bash
# Cost: patch size, abstract-format shape of `when n >= -5`, compile-time spread (N=15) on cur/A/B.
# Run on a quiet machine: timings are wall-clock including VM boot.
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; C=/home/user/beam-sharp/compiler
echo "--- patch size (changed diff lines):"
for v in A B; do f=src/bs_parser.yrl; [ $v = B ] && f=src/bs_check.erl
  printf 'variant %s (%s): ' $v $f; diff "$C/$f" "$HERE/work/$v/$f" | grep -cE '^[<>]'; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"; mkdir N
printf 'module N\n\npublic atom F(int n)\n\nF(n) when n >= -5 -> :hi\nF(n) when n < -5 -> :lo\nF(_) -> :x\n' > N/n.bs
for t in cur A B; do b=$HERE/work/C/_build/default/bin/bsc; [ $t != cur ] && b=$HERE/work/$t/_build/default/bin/bsc
  "$b" N >/dev/null 2>&1; echo "--- $t: ($?) emitted guard of clause 1:"
  erl -noshell -eval '{ok,Fs}=file:consult("N.abstr"), [io:format("~p~n",[G]) || {function,_,'"'"'F'"'"',_,[{clause,_,_,[G],_}|_]} <- lists:flatten(Fs)], halt().' 2>&1 | head -6
  ts=(); for i in $(seq 15); do s=$(date +%s%N); "$b" N >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n))
  echo "$t compile wall ms x15: min=${sorted[0]} median=${sorted[7]} max=${sorted[14]}"
  echo "beam bytes: $(stat -c %s N.beam)"
done
