#!/usr/bin/env bash
# §3.3: can the Abstract Format carry range info the JIT trusts?
#  (1) is a -spec (even `-> 0..99`) consulted by the optimiser?   (2) does an emitted guard give the `+` a {tr,..} range?
#  (3) does the JIT then drop its checks?  (JIT asm dumped with +JDdump true)
. "$(dirname "$0")/env.sh"
S=$A/probes/src; V=$W/p08; rm -rf $V; mkdir -p $V; erlc -o $V $S/lib08.erl $S/call08.erl
erl -noshell -pa $W -eval 'dis:main(["'$V'/call08.beam"])' > $V/call08.dis
for f in plain spec guard_int guard_range guard_range_cs; do
  echo "=== $f/1 ==="; sed -n "/--- $f\/1/,/^--- /p" $V/call08.dis | grep -v "^---" | grep -E "gc_bif|tr|test|is_|call" ; done
echo; echo "== does the compiler even read the spec? grep beam_ssa_type / sys_core_fold for spec handling =="
cd /opt/otp28/lib/erlang/lib/compiler-9.0/src; grep -ln "{attribute,[^}]*spec\|attribute.*spec" *.erl | tr '\n' ' '; echo
grep -n "spec" sys_core_fold.erl v3_core.erl | grep -v "^.*:-spec" | head -8
echo; echo "== where beam_core_to_ssa mentions spec =="; grep -n "spec" /opt/otp28/lib/erlang/lib/compiler-9.0/src/beam_core_to_ssa.erl | grep -v "^[0-9]*:-spec" | head -5
echo; echo "== core erlang of the spec'd module: is the -spec there? =="
erlc +to_core -o $V $S/lib08.erl; grep -c "spec" $V/lib08.core
echo "(>0 : the spec IS in Core; beam_core_to_ssa.erl:196 include_attribute(spec) -> false drops it before beam_ssa_type runs)"
echo; echo "== JIT asm: does the range-guarded + drop the checks? (+JDdump true writes call08.beam.asm) =="
cd $V; erl -noshell +JDdump true -pa $V -eval 'call08:run(guard_range,10), call08:run(guard_int,10), call08:run(plain,10), halt().'
awk '/^# call08:/{n=$2} {print n": "$0}' $V/call08.asm | grep -E "^call08:(plain|guard_int|guard_range|guard_range_cs)/1: # (add|simplified|skipped|is_int|is_in|is_integer|is the)" | sed "s/^call08://" | sort | uniq -c
rm -f $V/*.asm; cd - >/dev/null
