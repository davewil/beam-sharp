#!/usr/bin/env bash
# P10: real call cost of a thin alias vs the Pascal export vs a duplicate-body alias.
# CLAIM: a thin alias is ~one extra jump; measurable per call but tiny. REFUTED (as 'a real cost') if the thin `effect` column's
#   median lies inside the spread of the `none` effect column (none has no alias, so its effect is pure noise/placement bias, expected 0).
# Design: R rounds, round-robin over modes (none/thin/dup), each a fresh VM; ITERS remote calls per timed run; min of 3 timed runs
# per figure; the reported value per cell is the MEDIAN over rounds with the min-max range. Host is a shared microVM: noise is expected.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
R=${R:-9}; ITERS=${ITERS:-20000000}
W="$SCRATCH/p10"; rm -rf "$W"; mkdir -p "$W/src"; "$HERE/gen_sz.sh" 10 "$W/src"
for mode in none thin dup; do mkdir -p "$W/o_$mode"
  if [ $mode = none ]; then "$BSC" --src-root "$W/src" -o "$W/o_$mode" "$W/src/Sz10" >/dev/null 2>&1
  else BS_ALIAS=$mode "$BSC_ALIAS" --src-root "$W/src" -o "$W/o_$mode" "$W/src/Sz10" >/dev/null 2>&1; fi
done
attempt() {
echo "R=$R rounds, ITERS=$ITERS calls per timed run, nproc=$(nproc), $(erl -noshell -eval 'io:format("OTP ~s, JIT=~p~n",[erlang:system_info(otp_release), erlang:system_info(emu_flavor)]),halt().')"
: > "$W/raw.txt"
for r in $(seq 1 $R); do
  for mode in none thin dup; do
    fn=score_at1_value; [ $mode = none ] && fn=ScoreAt1Value   # none has no alias: its sc* columns re-measure the Pascal fn = the null control
    echo "$mode $(escript "$HERE/bench_call.escript" "$W/o_$mode" Sz10 ScoreAt1Value $fn $ITERS)" >> "$W/raw.txt"
  done
done
cat "$W/raw.txt"
echo "--- median over rounds [min..max], ns per call"
for mode in none thin dup; do
  for col in loop pc1 pc2 sc1 sc2 effect; do
    grep "^$mode " "$W/raw.txt" | sed "s/.*$col=\([-0-9.]*\).*/\1/" | sort -n | awk -v m=$mode -v c=$col '{a[NR]=$1} END{printf "%-5s %-8s median=%6.2f [%6.2f..%6.2f]\n", m, c, a[int((NR+1)/2)], a[1], a[NR]}'
  done
done
}
# Noise gate (added after run.sh's first full run produced a null spread of ~4 ns on a busy host, see CHANGELOG):
# an attempt whose NULL (mode none) effect spread is wider than 1.0 ns cannot resolve a ~1 ns effect and is reported as such; retry up to 3 times.
for a in 1 2 3; do
  echo "################ attempt $a"
  attempt | tee "$W/attempt$a.txt"
  width=$(grep '^none  effect' "$W/attempt$a.txt" | sed 's/.*\[\(.*\)\]/\1/' | awk -F'\\.\\.' '{print $2-$1}')
  echo "null-effect spread width attempt $a = $width ns (gate: <= 1.0)"
  awk -v w="$width" 'BEGIN{exit !(w<=1.0)}' && { echo "GATE PASSED on attempt $a"; break; }
  echo "GATE FAILED: attempt $a is too noisy to resolve ~1 ns; retrying"
done
