#!/usr/bin/env bash
# Is the x86 JIT machine code for Spin identical between hand-written Erlang and bsc?  (+JDdump true)
. "$(dirname "$0")/env.sh"; V=$W/p14; rm -rf $V; mkdir -p $V; cd $V
erl -noshell +JDdump true -pa $W/ebin -eval 'bench_erl:part_two([5]), '"'Day01'"':'"'PartTwo'"'([5]), bench_gleam:part_two([5]), halt().'
ex() { # file funcname -> asm body of one function, addresses/labels/module names normalised
  awk -v f="$2" '$0 ~ "^# "f"$"{p=1;next} /^# [A-Za-z0-9_@'"'"']+:[A-Za-z0-9_@'"'"']+\/[0-9]+$/{p=0} p' $1 \
   | grep -v "^\.db" | sed -E "s/bench_erl|Day01|bench_gleam//g; s/'//g; s/Spin/spin/g; s/Wrap/wrap/g; s/[Ll]abel_?[0-9]+/L/g; s/\.L[0-9]+/.L/g; s/\bL[0-9]+/L/g; s/0x[0-9a-f]+/ADDR/g; s/[0-9]+ \(/N (/g" ; }
ex bench_erl.asm "bench_erl:spin/4" > erl_spin.txt;  ex Day01.asm "'Day01':'Spin'/4" > bs_spin.txt
ex bench_erl.asm "bench_erl:wrap/1" > erl_wrap.txt;  ex Day01.asm "'Day01':'Wrap'/1" > bs_wrap.txt
ex bench_gleam.asm "bench_gleam:spin/4" > gl_spin.txt
wc -l *_spin.txt *_wrap.txt
echo "spin: erlang vs bsc diff lines: $(diff erl_spin.txt bs_spin.txt | wc -l)"; echo "wrap: erlang vs bsc diff lines: $(diff erl_wrap.txt bs_wrap.txt | wc -l)"
echo "erl spin JIT bytes-ish (instruction lines): $(grep -vc '^#' erl_spin.txt)  gleam spin: $(grep -vc '^#' gl_spin.txt)"
echo "--- bsc spin: JIT comments about checks:"; grep -E "^#" bs_spin.txt | grep -iE "overflow|small|range" | sort | uniq -c
echo "--- gleam spin: JIT comments about checks:"; grep -E "^#" gl_spin.txt | grep -iE "overflow|small|range" | sort | uniq -c
