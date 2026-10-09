#!/usr/bin/env bash
# §3.2: do the {tr,...} annotations CAUSE speed, or merely accompany it?  Strip them with the compiler's own switch
# (+no_type_opt turns off beam_ssa_type, so no {tr} reach the loader) and time the hand-written Erlang and bsc's .abstr.
# Modules are renamed (e_*, b_*) so all variants run in ONE VM, interleaved.
. "$(dirname "$0")/env.sh"
V=$W/variants; rm -rf $V; mkdir -p $V
B=$REPO/aoc/bench
mk_erl() { # name opts...
  n=$1; shift; sed "s/-module(bench_erl)/-module($n)/" $B/bench_erl.erl > $V/$n.erl; erlc "$@" -o $V $V/$n.erl; }
mk_bs() {
  n=$1; shift; sed "s/'Day01'/'$n'/" $W/ebin/Day01.abstr > $V/$n.abstr; erlc +from_abstr "$@" -o $V $V/$n.abstr; }
mk_erl e_default
mk_erl e_no_type_opt +no_type_opt
mk_erl e_no_ssa_opt  +no_ssa_opt
mk_bs  b_default
mk_bs  b_no_type_opt +no_type_opt
echo "== {tr,..} count / spin+wrap annotation per variant =="
for n in e_default e_no_type_opt e_no_ssa_opt b_default b_no_type_opt; do
  erl -noshell -pa $W -eval 'dis:main(["'$V'/'$n'.beam"])' > $V/$n.dis
  echo "$n: tr=$(grep -c '{tr,' $V/$n.dis) bytes=$(stat -c%s $V/$n.beam) instrs(spin)=$(grep -E '^--- .?[sS]pin' $V/$n.dis)"
done
echo; echo "-- e_no_type_opt spin gc_bif operands --"; sed -n '/--- spin\/4/,/^--- /p' $V/e_no_type_opt.dis | grep -A4 gc_bif | head -14
echo; echo "== timing, 300 interleaved rounds x2 (answers must all be 6770) =="
for i in 1 2; do
erl -noshell -pa $V -pa $W/ebin -eval 'bench2:main(["'$INPUT'","300","e_default:e_default:part_two","e_no_type_opt:e_no_type_opt:part_two","e_no_ssa_opt:e_no_ssa_opt:part_two","b_default:b_default:PartTwo","b_no_type_opt:b_no_type_opt:PartTwo"])'; echo; done
