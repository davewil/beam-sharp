#!/usr/bin/env bash
# Re-runs every ENG-211 probe on this host and rewrites the *.out files.
# Needs erl/erlc (OTP 25 here; ticket numbers are OTP 28). Idempotent.
set -u
cd "$(dirname "$0")"
W=${TMPDIR:-/tmp}/eng211; rm -rf "$W"; mkdir -p "$W/S" "$W/ebin"
VARS="v_a_ops v_b_remote v_c_retguard v_d_spec v_g_exported v_h_spin_exported v_j_guarded_exported v_k_spec_exported v_m_guarded_private v_s_extra_guard"
{ echo "otp=$(erl -noshell -eval 'io:format("~s ~p",[erlang:system_info(otp_release),erlang:system_info(emu_flavor)]),halt().')"
  echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2) nproc=$(nproc)"
  echo "elixir=$(elixir --version 2>/dev/null | tail -1)  elm=$(elm --version 2>/dev/null)"; } > env.out
# 1. which variants keep operand type annotations in the hot loop (erlc -S)
{ printf "%-24s %s\n" variant "tr-operands-in-spin/4  (first var_info line in spin/4)"
  for v in $VARS; do erlc -S -o "$W/S" src/$v.erl 2>/dev/null
    n=$(awk '/function, spin, 4/,/function, sign/' "$W/S/$v.S" | grep -c '{tr,')
    t=$(awk '/function, spin, 4/,/function, sign/' "$W/S/$v.S" | grep -m1 "var_info,{x,0}" | tr -s ' ')
    printf "%-24s tr=%s  %s\n" $v "$n" "$t"; done
  echo "--- baseline: the repo's own aoc/bench/bench_erl.erl"
  erlc -S -o "$W/S" ../../../aoc/bench/bench_erl.erl 2>/dev/null
  echo "bench_erl tr=$(awk '/function, spin, 4/,/function, sign/' "$W/S/bench_erl.S" | grep -c '{tr,')"
} > tr_annotations.out
# 2. the bsc build route (forms -> .abstr -> compile:file from_abstr, debug_info): does it lose types?
{ for m in ident zero_fn_line bs_like nodebug; do
    ./mk_abstr.escript src/v_a_ops.erl $m "$W/abstr_$m" >/dev/null 2>&1
    echo "route=$m  tr-in-spin=$(awk '/function, spin, 4/,/function, sign/' "$W/abstr_$m/v_a_ops.S" | grep -c '{tr,')"; done; } > abstr_route.out
# 3. timings
for v in $VARS; do erlc -o "$W/ebin" src/$v.erl 2>/dev/null; done
erlc -o "$W/ebin" bench39.erl
( cd "$W/ebin" && for r in 1 2 3; do echo "### run $r"; erl -noshell -pa . -s bench39 main $VARS 2>&1; done ) > timings.out
{ for v in $VARS; do printf "%-24s %s bytes\n" $v "$(stat -c %s "$W/ebin/$v.beam")"; done; } > beam_sizes.out
# 4. does the optimiser trust a narrowing -spec? (compare exported spin with/without narrow spec)
# (covered by tr_annotations.out: v_k_spec_exported vs v_g/h)
# 5. compile time of the Erlang side
{ for v in v_a_ops v_c_retguard; do /usr/bin/env bash -c "time (for i in \$(seq 20); do erlc -o $W/ebin src/$v.erl; done)" 2>&1 | grep real | sed "s/^/$v 20 compiles: /"; done; } > compile_time.out
# 6. Elixir's front end, same route: BenchEx -> debug_info forms -> 'S'
elixir elixir_tr.exs "$W/ex" ../../../aoc/bench/bench_ex.ex >/dev/null 2>&1
spin_tr() { awk '/^\{function, spin, 4/{f=1;next} /^\{function, /{f=0} f' "$1" | grep -c '{tr,'; }
{ echo "elixir 1.14 BenchEx (defp)  tr-in-spin=$(spin_tr "$W/ex/Elixir.BenchEx.S")"
  echo "erlang v_a_ops (same awk)   tr-in-spin=$(spin_tr "$W/S/v_a_ops.S")"
  echo "erlang v_g_exported (same awk) tr-in-spin=$(spin_tr "$W/S/v_g_exported.S")"; } > elixir_tr.out
