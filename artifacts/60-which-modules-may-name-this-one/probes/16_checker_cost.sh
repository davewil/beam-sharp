#!/bin/bash
# (d) Checker cost. Same tree, three compilers/configs, N timed runs each (wall clock, full `bsc` process
# including VM start, compile of EVERY module, emit, load and run). 4 vCPU container: only ratios matter.
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=/tmp/c60/_build/default/bin/bsc; PROTO=/tmp/c60a/_build/default/bin/bsc; INSTR=/tmp/c60i/_build/default/bin/bsc
G=${G:-20}; M=${M:-15}; N=${N:-7}
rm -rf /tmp/big_a /tmp/big_b
"$HERE/15_gen_big_tree.py" /tmp/big_a $G $M 0
"$HERE/15_gen_big_tree.py" /tmp/big_b $G $M 1
echo "within lines in tree B: $(grep -rl '^within ' /tmp/big_b | wc -l) of $(find /tmp/big_b -name '*.bs' | wc -l) files"
echo "using lines in tree: $(grep -rh '^using ' /tmp/big_a | wc -l)"
echo "## add_import calls per compile (instrumented copy /tmp/c60i), tree A:"
( cd /tmp/big_a && $INSTR -o /tmp/o60big --src-root . Big/Main Go 1 2>&1 >/dev/null | grep -c 'add_import' )
t() { # compiler tree
  local s e; s=$(date +%s.%N); ( cd $2 && $1 -o /tmp/o60big --src-root . Big/Main Go 1 >/dev/null 2>/tmp/err60 ) ; rc=$?; e=$(date +%s.%N)
  [ $rc -ne 0 ] && { echo "FAILED rc=$rc"; head -3 /tmp/err60; }
  echo "$e - $s" | bc -l; }
run() { # label compiler tree
  local v=(); for i in $(seq 1 $N); do v+=($(t $2 $3)); done
  printf '%s\n' "${v[@]}" | sort -n | awk -v l="$1" '{a[NR]=$1; s+=$1} END {printf "%-46s n=%d min=%.3f median=%.3f mean=%.3f max=%.3f s\n", l, NR, a[1], a[int((NR+1)/2)], s/NR, a[NR]}'; }
t $BASE /tmp/big_a >/dev/null   # warm file cache
run "HEAD compiler,  tree A (no within)"            $BASE  /tmp/big_a
run "PROTOTYPE,      tree A (no within)"            $PROTO /tmp/big_a
run "PROTOTYPE,      tree B (within on 20 helpers)" $PROTO /tmp/big_b
run "HEAD compiler,  tree A (no within)  [again]"   $BASE  /tmp/big_a
run "PROTOTYPE,      tree A (no within)  [again]"   $PROTO /tmp/big_a
