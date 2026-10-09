#!/usr/bin/env bash
# Probe 6: cost of emitting the alias. Synthetic modules (5 and 200 public multi-clause functions) compiled with the
# patched scratch bsc under BS_ALIAS = none | wrap (tail wrapper) | dup (full copy) [+ specs].  OTP 25, NOT the repo's OTP 28.
. "$(dirname "$0")/common.sh"
BSC_EBIN=/tmp/bsb_62_x/ebin
W=$SCR/p6; rm -rf $W; mkdir -p $W
gen() { # N
  local n=$1; local d=$W/Syn$n; mkdir -p $d
  { echo "module Syn$n"; for i in $(seq 1 $n); do
      printf '\npublic int Fn%d(int x)\n\nFn%d(0) -> %d\nFn%d(n) when n > 100 -> n - %d\nFn%d(n) -> n + %d\n' $i $i $i $i $i $i $i; done; } > $d/a.bs
}
gen 5; gen 200
# an acronym-bearing 5-fn variant is covered by p3; here names are Fn<k> so R1 = fn<k> (digits)
cat > $W/bench.erl <<'ERL'
-module(bench).
-export([compile_ms/3, load_us/2, call_ns/3]).
%% compile: Reps in-process compiles of module dir, returns list of ms
compile_ms(Dir, Out, Reps) ->
    [begin {T, _} = timer:tc(fun() -> 0 = bsc:status(["--src-root", filename:dirname(Dir), "-o", Out, Dir], standalone) end), T / 1000 end || _ <- lists:seq(1, Reps)].
%% load: Reps loads of the .beam binary; returns list of us
load_us(Beam, Reps) ->
    {ok, Bin} = file:read_file(Beam), M = list_to_atom(filename:basename(Beam, ".beam")),
    [begin code:purge(M), code:delete(M), code:purge(M),
           {T, {module, M}} = timer:tc(fun() -> code:load_binary(M, atom_to_list(M) ++ ".beam", Bin) end), T end || _ <- lists:seq(1, Reps)].
%% call overhead: N iterations calling F(1) (a pascal call) or f(1) (the alias), tight loop, ns per call
call_ns(M, F, N) ->
    {T, _} = timer:tc(fun() -> loop(M, F, N) end), T * 1000 / N.
loop(_, _, 0) -> ok;
loop(M, F, N) -> M:F(1), loop(M, F, N - 1).
ERL
(cd $W && erlc bench.erl)
summ() { # stdin: numbers one per line -> median min max
  sort -g | awk '{a[NR]=$1} END{m=(NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2; printf "median=%.2f min=%.2f max=%.2f n=%d", m, a[1], a[NR], NR}'; }
echo "mode            N    beam_bytes  exports  compile_ms(in-proc, 12 reps; 1st dropped)       "
for mode in none wrap dup; do for n in 5 200; do
  out=$W/out_${mode}_$n; mkdir -p $out
  extra=""; [ $mode != none ] && export BS_ALIAS=$mode BS_ALIAS_SPEC=1 || unset BS_ALIAS BS_ALIAS_SPEC
  cs=$(erl -noshell -pa $BSC_EBIN -pa $W -eval "L = bench:compile_ms(\"$W/Syn$n\", \"$out\", 12), io:format(\"~s~n\", [string:join([io_lib:format(\"~.1f\",[X]) || X <- tl(L)], \"\\n\")]), halt(0)." 2>&1 | grep -E '^[0-9.]+$' | summ)
  sz=$(stat -c %s $out/Syn$n.beam)
  ne=$(erl -noshell -pa $out -eval "io:format(\"~p\",[length(('Syn$n'):module_info(exports))]),halt()." )
  printf '%-8s %5s %10s %8s   %s\n' $mode $n $sz $ne "$cs"
done; done
echo; echo "== load time (us per code:load_binary), 10 fresh VMs x 40 loads each; per-VM median, then median/min/max across the 10 VMs =="
for mode in none wrap dup; do for n in 5 200; do
  vals=""
  for r in $(seq 1 10); do
    v=$(erl -noshell -pa $W -eval "L = lists:sort(bench:load_us(\"$W/out_${mode}_$n/Syn$n.beam\", 40)), io:format(\"~p~n\",[lists:nth(20, L)]), halt()." )
    vals="$vals$v\n"
  done
  printf '%-6s N=%-4s ' $mode $n; printf "$vals" | summ; echo
done; done
echo; echo "== call overhead: 5M calls of F(1) (alias wrapper vs direct), ns/call, 10 fresh VMs each; Fn1 = direct PascalCase, fn1 = alias (wrap) / copy (dup) =="
for mode in wrap dup; do for f in Fn1 fn1; do
  vals=""
  for r in $(seq 1 10); do
    v=$(erl -noshell -pa $W/out_${mode}_5 -pa $W -eval "io:format(\"~.2f~n\",[bench:call_ns('Syn5', '$f', 5000000)]), halt()." )
    vals="$vals$v\n"
  done
  printf '%-5s %-4s ' $mode $f; printf "$vals" | summ; echo
done; done
echo "(baseline: unpatched "none" build, Fn1 only; no slow-path control was run)"
vals=""; for r in $(seq 1 10); do vals="$vals$(erl -noshell -pa $W/out_none_5 -pa $W -eval "io:format(\"~.2f~n\",[bench:call_ns('Syn5', 'Fn1', 5000000)]), halt().")\n"; done; printf '%-5s %-4s ' none Fn1; printf "$vals" | summ; echo
