#!/bin/sh
# (Attempt 1, run.first-attempt.out: bsc:main halts the VM, so the in-VM clock printed nothing; it now times bsc:status/2, which returns.)
# Probe 60/04: what does the Internal rule cost the checker? Same generated tree, three compilers
# (base / v1 / v1+v2 from probe 03), 12 alternating runs each, two clocks:
#   wall  = the whole `erl` process (VM boot + load + compile), via date +%s%N
#   in-VM = timer:tc around bsc:main only
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
W=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/proto60
[ -d $W/proto2/ebin ] || ../03_proto/build.sh >/dev/null 2>&1
N=${1:-100}; RUNS=${2:-12}
T=$W/tree$N; python3 gen.py $N $T
echo "-- sanity: tree compiles under all three (exit codes, then the result of Main 1)"
for V in base proto proto2; do
  erl -noshell -pa $W/$V/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra --src-root $T -o $W/out_$V $T/Acme/App Main 1 2>&1 | tail -2 | tr '\n' ' '; echo "[$V]"
done
for V in base proto proto2; do : > $W/wall_$V; : > $W/vm_$V; done
i=0
while [ $i -lt $RUNS ]; do
  for V in base proto proto2; do
    rm -rf $W/out_$V
    s=$(date +%s%N)
    erl -noshell -pa $W/$V/ebin -eval '{US,_}=timer:tc(fun() -> bsc:status(init:get_plain_arguments(), standalone) end), io:format(standard_error, "VM ~p~n", [US]), halt().' -extra --src-root $T -o $W/out_$V $T/Acme/App 2>$W/err_$V >/dev/null
    e=$(date +%s%N)
    echo $(( (e-s)/1000000 )) >> $W/wall_$V
    sed -n 's/^VM //p' $W/err_$V | awk '{printf "%d\n", $1/1000}' >> $W/vm_$V
  done
  i=$((i+1))
done
stat() { sort -n "$1" | awk '{a[NR]=$1; s+=$1} END {printf "n=%d min=%d median=%d max=%d mean=%.1f\n", NR, a[1], a[int((NR+1)/2)], a[NR], s/NR}'; }
for V in base proto proto2; do echo "[$V] wall ms: $(stat $W/wall_$V)"; echo "[$V] in-VM ms: $(stat $W/vm_$V)"; done
for V in base proto proto2; do echo "[$V] raw wall: $(tr '\n' ' ' < $W/wall_$V)"; done
