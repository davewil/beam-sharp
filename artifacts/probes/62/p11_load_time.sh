#!/usr/bin/env bash
# P11: module LOAD time for N=1/10/100 public functions: none vs thin vs dup.
# Measured as erlang:prepare_loading/2 and erlang:finish_loading/1 (delete+purge outside the timed region).
# Null control: `none2` loads a second, byte-identical copy of the baseline beam => its difference from `none` is the noise floor.
# CLAIM: load time grows with export-table / code size. REFUTED (as a real cost) if (thin - none) median-of-medians lies inside
#   the none-vs-none2 spread. R interleaved rounds, each cell a fresh VM, REPS timed loads per cell.
# (v1 timed code:load_binary with 3000 reps and took about a minute per cell on this shared host; see CHANGELOG.)
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
R=${R:-3}; REPS=${REPS:-150}; W="$SCRATCH/p08"      # reuses p08's generated beams; regenerate if absent
[ -f "$W/out_100_none/Sz100.beam" ] || "$HERE/p08_size.sh" >/dev/null 2>&1
for N in 1 10 100; do mkdir -p "$W/null_$N"; cp "$W/out_${N}_none/Sz$N.beam" "$W/null_$N/Sz$N.beam"; done
: > "$W/load_raw.txt"
for r in $(seq 1 $R); do for N in 1 10 100; do
  for v in none:out_${N}_none none2:null_$N thin:out_${N}_thin dup:out_${N}_dup; do
    echo "$N ${v%%:*} $(escript "$HERE/bench_load.escript" "$W/${v##*:}/Sz$N.beam" $REPS)" >> "$W/load_raw.txt"
  done
done; done
head -12 "$W/load_raw.txt"; echo "... ($(wc -l < "$W/load_raw.txt") raw cells in total; full file copied to out/p11_raw.txt)"
cp "$W/load_raw.txt" "$HERE/out/p11_raw.txt"
echo "--- median over rounds of per-cell median, microseconds [min..max over rounds]"
for phase in prep fin; do for N in 1 10 100; do for v in none none2 thin dup; do
  grep "^$N $v " "$W/load_raw.txt" | sed "s/.*${phase}_median=\([0-9]*\).*/\1/" | sort -n | awk -v p=$phase -v n=$N -v v=$v '{a[NR]=$1} END{printf "%-4s N=%-4s %-6s %6d [%d..%d]\n", p, n, v, a[int((NR+1)/2)], a[1], a[NR]}'
done; done; done
