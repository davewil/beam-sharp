#!/usr/bin/env bash
# Probe 64/07 - the same lookup written as B# option<int> (bare success) and as a user-declared
# Maybe<int> = (:some,V)|:nothing (tagged success), both compiled by the real bsc:
# .beam size, compile wall time (7 runs, min/median), and run time of 2,000,000 lookups (7 runs).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(cd "$HERE/../../../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd "$HERE"
echo "git HEAD: $(git -C $REPO log --oneline -1)"
for m in Opt Tag; do "$BSC" -o $W/$m --src-root src src/$m || exit 1; done
echo ".beam sizes (bytes):"; for m in Opt Tag; do printf '  %s %s\n' $m "$(stat -c %s $W/$m/$m.beam)"; done
echo
echo "emitted Find/3 for each (erl_pp of .abstr):"
for m in Opt Tag; do
  echo "--- $m"
  erl -noshell -eval '{ok,Fs}=file:consult(hd(init:get_plain_arguments())), [io:put_chars(erl_pp:form(F)) || F <- Fs, element(1,F)==function, element(3,F)==(list_to_atom("Find"))], halt().' -extra $W/$m/$m.abstr
done
echo
med(){ sort -n | awk '{a[NR]=$1} END{print "min="a[1]" median="a[int((NR+1)/2)]}'; }
echo "compile wall time, ms (bsc process incl. VM start), 7 runs:"
for m in Opt Tag; do
  for i in 1 2 3 4 5 6 7; do s=$(date +%s%N); "$BSC" -o $W/c_$m --src-root src src/$m >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )); done | med | sed "s/^/  $m /"
done
echo
echo "run time of Run(2000000) (20-element assoc list, hit at position 19), microseconds, 7 runs:"
for m in Opt Tag; do
  for i in 1 2 3 4 5 6 7; do
    erl -noshell -pa $W/$m -eval "{T,_}=timer:tc(fun() -> '$m':'Run'(2000000) end), io:format(\"~p~n\",[T]), halt()."
  done | med | sed "s/^/  $m /"
done
echo
echo "result check: Opt Run(3) = $(erl -noshell -pa $W/Opt -eval "io:format(\"~p\",['Opt':'Run'(3)]),halt().")  Tag Run(3) = $(erl -noshell -pa $W/Tag -eval "io:format(\"~p\",['Tag':'Run'(3)]),halt().")"
