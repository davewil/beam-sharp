#!/usr/bin/env bash
# CLAIM: the callee-side directory rule adds no measurable compile time (it is a string-prefix test per `using`).
# REFUTED IF: patched median exceeds HEAD median by more than the HEAD run-to-run spread (max-min) on either program.
# CONTROL: HEAD-vs-HEAD (same binary run twice, interleaved) shows the noise floor.
# Programs: (A) 5-module `ok` tree; (B) generated 41 modules (Gen.Internal + Gen.M1..M40, each `using` Gen.Internal
#   and its two predecessors => 121 `using` edges). N=15 alternating runs each, wall ms via date +%s%N (includes VM start).
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
PB=$("$D/60_build_patched.sh" | tail -1); [ -x "$PB" ] || { echo "patched build failed"; exit 1; }
G=$(mktemp -d /tmp/probe60gen.XXXXXX); mkdir -p $G/Gen/Internal
printf 'module Gen.Internal\n\npublic int Core(int n)\nCore(n) -> n + 1\n' > $G/Gen/Internal/C.bs
for i in $(seq 1 40); do mkdir -p $G/Gen/M$i
  { echo "module Gen.M$i"; echo; echo "using Gen.Internal"
    [ $i -gt 1 ] && echo "using Gen.M$((i-1))"; [ $i -gt 2 ] && echo "using Gen.M$((i-2))"
    echo; echo "public int F$i(int n)"
    e="Core(n)"; [ $i -gt 1 ] && e="$e + F$((i-1))(n)"; echo "F$i(n) -> $e"; } > $G/Gen/M$i/M.bs; done
stats() { sort -n | awk '{a[NR]=$1} END{printf "n=%d min=%d median=%d max=%d ms\n", NR, a[1], a[int((NR+1)/2)], a[NR]}'; }
run() { # compiler srcroot module outdir
  s=$(date +%s%N); ( cd "$2" && "$1" --src-root . -o "$4" "$3" >/dev/null 2>&1 ) || echo FAIL >&2; e=$(date +%s%N); echo $(( (e-s)/1000000 )); }
O=$(mktemp -d /tmp/probe60out.XXXXXX)
for prog in A B; do
  if [ $prog = A ]; then R="$D/60_shop/ok"; M=Shop/Billing; else R=$G; M=Gen/M40; fi
  : > $O/h1; : > $O/h2; : > $O/p
  run $BSC $R $M $O >/dev/null; run $PB $R $M $O >/dev/null   # warm file cache
  for k in $(seq 1 15); do run $BSC $R $M $O >> $O/h1; run $PB $R $M $O >> $O/p; run $BSC $R $M $O >> $O/h2; done
  echo "program $prog ($M)"; echo -n "  HEAD run1   "; stats < $O/h1; echo -n "  HEAD run2   "; stats < $O/h2; echo -n "  PATCHED     "; stats < $O/p
done
