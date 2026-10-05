#!/usr/bin/env bash
# p06 -- call-time cost of the private-function guards.  Same B# source under four compilers.
#   BenchBase / BenchBase2 : base bsc twice (identical code; their difference IS the noise floor)
#   BenchA : option a (no private tag test)      BenchB : option b (private int kind + range tests)
# Per element visited: Amount() runs the tag test (base vs A);  Weight() runs is_integer+range (B vs base).
# A difference smaller than |BenchBase - BenchBase2| (or than the spread of the raw reps) is NOT reported as a difference.
# REFUTES "guard has a measurable call-time cost" if every delta is within the noise floor.
. "$(dirname "$0")/lib.sh"; cd "$HERE"
REPS=${REPS:-9}; CALLS=${CALLS:-20000}; LEN=${LEN:-1000}
O="$OUT/p06"; rm -rf "$O"; mkdir -p "$O/src"
for spec in BenchBase:base BenchBase2:base BenchA:a BenchB:b BenchC:c; do
  m=${spec%%:*}; v=${spec##*:}
  mkdir -p "$O/src/$m" "$O/$m"; sed "s/@MOD@/$m/" src/bench_tmpl/bench.bs.in > "$O/src/$m/m.bs"
  "$(bscv $v)" -o "$O/$m" "$O/src/$m" > "$O/$m/bsc.log" 2>&1 || { cat "$O/$m/bsc.log"; exit 1; }
  printf '%s (%s) ' $m $v; ./bytes_one.escript "$O/$m/$m.beam"
done | tee "$O/sizes.txt"
echo "machine: $(nproc) cpus, $(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2); loadavg at start: $(cut -d" " -f1-3 /proc/loadavg) (shared host: other jobs may run)" | tee "$O/machine.txt"
erl -noshell -eval 'io:format("OTP ~s erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().' | tee -a "$O/machine.txt"
erl -noshell +S 1:1 -s init stop >/dev/null 2>&1
erl -noshell -eval 'io:format("jit: ~p~n",[erlang:system_info(emu_flavor)]),halt().' | tee -a "$O/machine.txt"
echo "REPS=$REPS CALLS=$CALLS LEN=$LEN  => $((CALLS*LEN)) element visits per rep per variant" | tee -a "$O/machine.txt"
./bench.escript "$O" $REPS $CALLS $LEN Base=BenchBase Base2=BenchBase2 A=BenchA B=BenchB C=BenchC 2>&1 | tee "$O/bench.txt"
