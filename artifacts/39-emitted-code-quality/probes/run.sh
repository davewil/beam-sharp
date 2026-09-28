#!/usr/bin/env bash
# run.sh -- regenerates EVERY *.out in this directory from scratch. usage: ./run.sh [rounds]
# Environment: OTP 25 / x86-64 Linux / JIT. NOT the ticket's OTP 28 / Apple Silicon.
#
# PREDICTIONS (written before any result was seen; results are judged against these in brief.md):
#  P1 base (== bench_erl.erl) shows {tr,..,{t_integer,{0,99}}}-style ranged annotations on spin/4's Pos
#     (the ticket says Erlang has them). Source of ranges = call-site inference for PRIVATE functions
#     (beam_ssa_type.erl:119-121, 432-437).
#  P2 BSSHAPE (Sign/Size written the B# way) keeps the same annotations as base: source shape alone is
#     NOT what loses them. If it does lose them, the ticket's "B# forms differ" story is a source-shape story.
#  P3 EXPORTALL loses the ranges (exported => args start `any`, beam_ssa_type.erl:438-441) with no change
#     to the instruction sequence.
#  P4 A guard is_integer(P) restores {t_integer,any} only. A range guard P>=0,P=<99 does NOT restore a
#     range on OTP 25 because beam_ssa_type.erl has no infer_type clause for relational operators
#     (grep of infer_type shows only is_*/=:= clauses). => the brief's mechanism (b) "guards carry ranges" is
#     predicted to FAIL on 25. (Might differ on 28: unprobed.)
#  P5 -spec (tight ranges) changes nothing in the emitted code: beam_ssa_type never reads specs.
#  P6 +no_type_opt strips every {tr} and makes the hot loop slower IF this OTP 25 JIT consumes the Type chunk.
#     I predict a slowdown of ~5-25%. If ~0, then the OTP-25 JIT does not exploit these annotations and the
#     ticket's mechanism cannot be reproduced here (it says nothing about OTP 28).
#  P7 EXPORTALL (any-typed) runs slower than private base, by less than or about equal to the no_type_opt gap.
set -e
cd "$(dirname "$0")"
ROUNDS=${1:-300}
B=build; rm -rf $B; mkdir -p $B; rm -f timing_repeat.out
ERLC="erlc -Werror"
INPUT=../../../aoc/2025/Day01/input.txt

{ echo "date: $(date -u +%F)"; uname -srm; grep -m1 'model name' /proc/cpuinfo; echo "nproc: $(nproc)"
  erl -noshell -eval 'io:format("otp_release=~s erts=~s emu_flavor=~p~n",[erlang:system_info(otp_release),erlang:system_info(version),erlang:system_info(emu_flavor)]),halt().'
  erl -noshell -eval 'application:load(compiler),{ok,V}=application:get_key(compiler,vsn),io:format("compiler_app=~s~n",[V]),halt().'
  elixir --version | tail -1; echo "gleam: not installed / not probed"; erlc -v 2>&1 | head -1; } > versions.out 2>&1

v() { # name, extra erlc flags...   (module name must equal file name, so copy the source per variant)
  local name=$1; shift
  mkdir -p $B/src; cp loop.erl $B/src/$name.erl
  erlc "$@" -DMOD=$name -o $B $B/src/$name.erl
  erlc "$@" -DMOD=$name +to_asm -o $B $B/src/$name.erl
}
v v_base
v v_bs        -DBSSHAPE
v v_base_nt   +no_type_opt
v v_bs_nt     -DBSSHAPE +no_type_opt
v v_exp       -DEXPORTALL
v v_exp_is    -DEXPORTALL -DGUARD_IS
v v_exp_rng   -DEXPORTALL -DGUARD_RNG
v v_exp_spec  -DEXPORTALL -DSPEC
v v_priv_rng  -DGUARD_RNG
v v_bs_rng    -DBSSHAPE -DGUARD_RNG
v v_remote    -DREMOTE
v v_remote_nt -DREMOTE +no_type_opt
# positive control (see ctl.erl)
mkdir -p $B/src; for n in ctl ctl_nt; do cp ctl.erl $B/src/$n.erl; done
erlc -DMOD=ctl -o $B $B/src/ctl.erl; erlc -DMOD=ctl_nt +no_type_opt -o $B $B/src/ctl_nt.erl
# the bsc build path: forms -> ~p .abstr with line 0 -> compile:file(from_abstr, debug_info)  (bsc.erl:843)
erlc -o $B mkabstr.erl
erl -noshell -pa $B -run mkabstr main loop.erl v_abstr $B BSSHAPE SPEC_WIDE BSATOMS
erl -noshell -pa $B -run mkabstr main loop.erl v_abstr_rng $B BSSHAPE SPEC_WIDE BSATOMS GUARD_RNG
erlc -o $B ../../../aoc/bench/bench_erl.erl
erlc -o $B timing.erl types.erl identity.erl

# --- 1. type annotations of the hot functions (from +to_asm) ---
for m in v_base v_bs v_base_nt v_bs_nt v_exp v_exp_is v_exp_rng v_exp_spec v_priv_rng v_bs_rng v_abstr v_abstr_rng v_remote v_remote_nt; do
  echo "=== $m: {tr,..} operands inside spin/4 and wrap/1 (+to_asm) ==="
  awk '/^\{function, (spin|wrap),/{on=1} /^\{function, (hit|sign|size_|clicks|part_two|module_info),/{on=0} on && /\{tr,/' $B/$m.S
  echo "  total {tr,..} operands in module: $(grep -c '{tr,' $B/$m.S)"
done > tr_summary.out

# --- 2. instruction streams: are spin/4 and wrap/1 identical across variants after erasing {tr,R,_} -> R ?

# --- 3. size / instruction counts / Type chunk ---
for m in v_base v_bs v_base_nt v_exp v_exp_is v_exp_rng v_exp_spec v_priv_rng v_abstr; do
  erl -noshell -pa $B -run types main $B/$m.beam
done > sizes.out 2>&1
erl -noshell -pa $B -run types main $B/bench_erl.beam >> sizes.out 2>&1

# --- 4. Elixir 1.14 (OTP 25 host) : build, recover asm, type annotations, size ---
mkdir -p $B/ex; elixirc -o $B/ex ../../../aoc/bench/bench_ex.ex > /dev/null 2>&1
cp $B/ex/Elixir.BenchEx.beam $B/
erl -noshell -pa $B -pa /usr/lib/elixir/lib/elixir/ebin -eval '
{ok,{_,[{debug_info,{debug_info_v1,Be,Data}}]}} = beam_lib:chunks("build/ex/Elixir.BenchEx.beam",[debug_info]),
{ok,Forms} = Be:debug_info(erlang_v1, (list_to_atom("Elixir.BenchEx")), Data, []),
io:format("elixir forms recovered from debug_info: ~p forms~n",[length(Forms)]),
{ok,_,Asm} = compile:forms(Forms,[to_asm,binary,return_errors]),
{ok,Fd} = file:open("build/ex_asm.S",[write]), beam_listing:module(Fd, Asm), file:close(Fd),
halt().' > elixir_recover.out 2>&1
erl -noshell -pa $B -run types main $B/Elixir.BenchEx.beam > elixir_sizes.out 2>&1 || true
{ echo "=== Elixir.BenchEx (asm recovered via debug_info -> compile:forms to_asm; NOT elixirc's own flags): {tr,..} operands in spin/wrap ==="
  awk '/^\{function, (spin|wrap),/{on=1} /^\{function, (hit|sign|size_|clicks|part_two|module_info|__info__),/{on=0} on && /\{tr,/' build/ex_asm.S; echo "  total {tr,..} in module: $(grep -o '{tr,' build/ex_asm.S 2>/dev/null | wc -l)"; } > elixir_tr.out 2>&1

# --- 4b. instruction-stream identity (needs ex_asm.S from step 4) ---
erl -noshell -pa $B -run identity main > instr_identity.out 2>&1

# --- 5. timing (interleaved) ---
{ echo "rounds=$ROUNDS ; times in ms per part_two() call over 4732 rotations / 673364 clicks"
  taskset -c 2 erl -noshell +S 1:1 -pa $B -run timing main $INPUT $ROUNDS bench_erl v_base v_bs v_base_nt v_bs_nt v_exp v_exp_is v_exp_rng v_exp_spec v_priv_rng v_bs_rng v_abstr v_abstr_rng v_remote v_remote_nt 'Elixir.BenchEx'
} > timing.out 2>&1
# second, independent process + core to check run-to-run (process-level) variance on the key pairs
for core in 1 3; do
 { echo "--- independent VM on core $core, key pairs only ---"
   taskset -c $core erl -noshell +S 1:1 -pa $B -run timing main $INPUT $ROUNDS v_base v_base_nt v_exp v_exp_rng v_exp_spec
 } >> timing_repeat.out 2>&1
done

# --- 6. positive control ---
{ echo "control (ctl.erl): tuple loop + binary-match loop, with vs without +no_type_opt; 100 rounds"
  taskset -c 2 erl -noshell +S 1:1 -pa $B -run timing main $INPUT 100 ctl ctl_nt
} > control.out 2>&1
{ echo "Type-chunk bytes (control):"; for m in ctl ctl_nt; do erl -noshell -pa $B -eval "{ok,_,C}=beam_lib:all_chunks(\"$B/$m.beam\"),io:format(\"$m type_chunk=~p~n\",[byte_size(element(2,lists:keyfind(\"Type\",1,C)))]),halt()."; done; } >> control.out 2>&1
echo done
