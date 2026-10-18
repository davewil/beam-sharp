#!/usr/bin/env bash
# 05 — cost.  Same B# program (bench.bs.inc) compiled by each variant:
#   v0 today (tag test on private, kind test on exported only)
#   v1 tag test exported-only      v2 kind test on private too      v4 both, exported-or-escaping
# Reports: .beam Code-chunk bytes, the guards each function carries, and the
# time of a 30M-iteration loop through private functions (min / median of 9).
# OTP 25 here; ticket 18's numbers are OTP 28.5 arm64.  Compare ratios, not ns.
HERE0="$(cd "$(dirname "$0")" && pwd)"; source "$HERE0/lib.sh"
N=${N:-30000000}
echo "erts: $(erl -noshell -eval 'io:format("OTP ~s, ~s, jit=~p",[erlang:system_info(otp_release),erlang:system_info(system_architecture),erlang:system_info(emu_flavor)]),halt().')"
for v in v0 v1 v2 v4; do
  W=$(mktemp -d); mkdir -p $W/Bench; cp "$HERE0/bench.bs.inc" $W/Bench/a.bs
  "$SCRATCH/var/$v/bsc" -o $W/Bench/out $W/Bench 2>&1 | head -3
  echo "######## $v"
  erl -noshell -pa $W/Bench/out -eval '
    {ok,{_,[{"Code",Code}]}} = beam_lib:chunks("'$W'/Bench/out/Bench.beam", ["Code"]),
    io:format("Code chunk: ~p bytes   .beam file: ~p bytes~n",[byte_size(Code), filelib:file_size("'$W'/Bench/out/Bench.beam")]),
    {ok,Forms}=file:consult("'$W'/Bench/out/Bench.abstr"),
    [io:format("  ~s~n",[string:trim(re:replace(erl_pp:form(Fm),"\\s+"," ",[global,{return,list}]))]) || {function,_,Nm,_,_}=Fm <- Forms, lists:member(atom_to_list(Nm),["LoopInt","Step","LoopRec","Get"]), length(element(5,Fm))>0, false],
    Time = fun(F, A) -> lists:sort([element(1,timer:tc(fun() -> '"'Bench'"':F(A) end)) || _ <- lists:seq(1,9)]) end,
    Rep = fun(L, F) -> Ts = Time(F, '$N'), io:format("~-34s min ~7.1f ms  median ~7.1f ms   (~.2f ns/iter)~n",[L, hd(Ts)/1000, lists:nth(5,Ts)/1000, hd(Ts)*1000/'$N']) end,
    Rep("RunInt (LoopInt+Step, int kind)", '"'RunInt'"'),
    Rep("RunRec (LoopRec+Get, record tag)", '"'RunRec'"'),
    halt().'
done
