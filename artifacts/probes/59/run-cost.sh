#!/usr/bin/env bash
# Probe 59-C: what do the two guards cost, measured on bsc's own output?
# Usage: source env.sh; ./run-cost.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
erlc -o "$W" "$HERE/cost/bench.erl" || exit 1

gen_record() { # N fields -> module RecN
  local n=$1 f="" i
  for ((i=1;i<=n;i++)); do f+="F$i: int"; [ $i -lt $n ] && f+=", "; done
  mkdir -p "$W/src/Rec$n"
  cat > "$W/src/Rec$n/Rec$n.bs" <<X
module Rec$n

record R { $f }

public int Run(R r)
Run(r) -> Inner(r)

private int Inner(R r)
Inner(r) -> r.F1
X
}
gen_int() {
  mkdir -p "$W/src/PlainInt" "$W/src/RangeInt"
  cat > "$W/src/PlainInt/PlainInt.bs" <<X
module PlainInt

public int Run(int n)
Run(n) -> Inner(n)

private int Inner(int n)
Inner(n) -> n + 1
X
  cat > "$W/src/RangeInt/RangeInt.bs" <<X
module RangeInt

type Octet = int where value >= 0 and value <= 255

public int Run(Octet n)
Run(n) -> Inner(n)

private int Inner(Octet n)
Inner(n) -> n + 1
X
}
gen_listint() {
  mkdir -p "$W/src/ListInt" "$W/src/ListRange"
  # The private function's argument arrives out of a list, so the BEAM compiler's
  # type pass cannot see that it is an integer (contrast PlainInt, where the
  # exported guard on Run is visible to it).
  cat > "$W/src/ListInt/ListInt.bs" <<X
module ListInt

public list<int> Run(list<int> xs)
Run([])       -> []
Run([x, ..t]) -> [Inner(x), ..Run(t)]

private int Inner(int n)
Inner(n) -> n + 1
X
  cat > "$W/src/ListRange/ListRange.bs" <<X
module ListRange

type Octet = int where value >= 0 and value <= 255

public list<int> Run(list<Octet> xs)
Run([])       -> []
Run([x, ..t]) -> [Inner(x), ..Run(t)]

private int Inner(Octet n)
Inner(n) -> n + 1
X
}
for n in 1 4 16 32; do gen_record $n; done; gen_int; gen_listint

echo "=== A. bytes: Code chunk / whole .beam / stripped .beam (bsc output, OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')) ==="
printf '%-10s %-8s %s\n' module build "code file stripped"
for m in Rec1 Rec4 Rec16 Rec32 PlainInt RangeInt ListInt ListRange; do
  for v in head narrow widen; do
    mkdir -p "$W/o/$v"
    "$W/c/$v/bsc" --src-root "$W/src" -o "$W/o/$v" "$W/src/$m/$m.bs" >/dev/null 2>&1 || { echo "compile failed $m $v"; continue; }
    printf '%-10s %-8s %s\n' $m $v "$(escript "$HERE/cost/size.escript" "$W/o/$v/$m.beam")"
  done
done

echo
echo "=== B. compile time, in-process bsc:file/2, 40 compiles each (ms): min / median / max ==="
cat > "$W/ct.escript" <<'X'
#!/usr/bin/env escript
%% usage: ct.escript BSC_SRC_DIR SRC_ROOT MODULE OUTDIR  -- times bsc:status/2, the CLI's own entry
main([Lib, Src, Mod, Out]) ->
    code:add_pathsa(filelib:wildcard(Lib ++ "/_build/default/lib/*/ebin")),
    Args = ["--src-root", Src, "-o", Out, Src ++ "/" ++ Mod ++ "/" ++ Mod ++ ".bs"],
    Run = fun() -> S = erlang:monotonic_time(microsecond),
                   0 = bsc:status(Args, batch),
                   (erlang:monotonic_time(microsecond) - S) / 1000 end,
    _ = [Run() || _ <- lists:seq(1, 5)],
    Ts = lists:sort([Run() || _ <- lists:seq(1, 40)]),
    io:format("~.2f / ~.2f / ~.2f~n", [hd(Ts), lists:nth(20, Ts), lists:last(Ts)]).
X
for v in head narrow widen; do
  mkdir -p "$W/ct/$v"
  printf '%-7s Rec32: ' $v; escript "$W/ct.escript" "$W/c/$v-src" "$W/src" Rec32 "$W/ct/$v" 2>&1 | tail -1
done

echo
echo "=== C. call time, ns/call (15 trials x 10M calls per VM; 6 VM pairs per comparison, ORDER ALTERNATED each pair so a warm-machine effect cannot favour one build) ==="
call() { # build module fun arg
  (cd "$W" && erl -noshell -pa "$W/o/$1" -pa "$W" -run bench main "$2" "$3" "$4" 15 10000000 2>&1 | tail -1)
}
med() { sed -E 's/.* med=([0-9.]+) max=.*/\1/'; }
# compare MODULE FUN ARG BASELINE_BUILD VARIANT_BUILD : prints each VM line and the per-pair delta (baseline - variant)
compare() {
  local m=$1 f=$2 a=$3 b=$4 v=$5 rep x y lb lv deltas=""
  for rep in 1 2 3 4 5 6; do
    if [ $((rep % 2)) = 1 ]; then x=$b; y=$v; else x=$v; y=$b; fi
    lx=$(call $x $m $f "$a"); ly=$(call $y $m $f "$a")
    printf '%-7s %s\n%-7s %s\n' $x "$lx" $y "$ly"
    if [ $x = $b ]; then lb=$lx; lv=$ly; else lb=$ly; lv=$lx; fi
    d=$(echo "$(echo "$lb" | med) $(echo "$lv" | med)" | awk '{printf "%.2f", $1-$2}')
    deltas="$deltas $d"
  done
  echo "  per-pair median delta ($b - $v) ns/call:$deltas   mean: $(echo $deltas | tr ' ' '\n' | awk '{s+=$1} END {printf "%.2f", s/NR}')"
}
REC='#{'"'"'Kind'"'"' => '"'"'Rec1.R'"'"', '"'"'F1'"'"' => 1}'
echo "-- record tag test on a private fn (Rec1: head vs narrow) --"
compare Rec1 Run "$REC" head narrow
echo "-- int kind test where BEAM type pass can see the arg (PlainInt: head vs widen) --"
compare PlainInt Run 7 head widen
echo "-- int kind test where it cannot: private Inner fed from a list (ListInt [7]: head vs widen) --"
compare ListInt Run '[7]' head widen
