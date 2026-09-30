#!/bin/bash
# Ticket 59 probes.  Usage: run.sh [--quick]   (--quick: 3 timing runs instead of 7, fewer compile-time runs)
# Every probe states its EXPECTATION before its command runs, in the `expect` line above it.
# Output of the last run is captured under out/.  Exit status = number of FAILs.
# Neighbour-language probes that cannot run print NOT-RUN, never PASS.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
SP=${SP:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad}
W=${W:-$SP/work/59/run}
RUNS=7; CRUNS=9; [ "${1:-}" = "--quick" ] && { RUNS=3; CRUNS=5; }
OUT=$HERE/out; mkdir -p "$OUT" "$W"
L=$HERE/lib
FAILS=0
export ERL_FLAGS=""

pass_fail() { # id description expected actual
  if [ "$3" = "$4" ]; then echo "PASS $1  $2"; else echo "FAIL $1  $2"; echo "     expected: $3"; echo "     actual:   $4"; FAILS=$((FAILS+1)); fi
}
bsc() { # variant args...   variant: repo (prebuilt from HEAD) | base | narrow | wide
  local v=$1; shift; local E
  case $v in repo) E=$SP/bsc/ebin;; *) E=$W/ebin-$v;; esac
  erl -noshell -pa "$E" -eval 'bsc:main(init:get_plain_arguments()),halt().' -extra "$@"
}

# ---- build: base = repo's bs_emit.erl recompiled untouched; narrow / wide = the same file with variants/*.patch applied
for v in base narrow wide refsite; do
  rm -rf "$W/ebin-$v" "$W/src-$v"; cp -r "$SP/bsc/ebin" "$W/ebin-$v"; mkdir -p "$W/src-$v"
  cp "$REPO/compiler/src/bs_emit.erl" "$W/src-$v/bs_emit.erl"
  [ $v != base ] && (cd "$W/src-$v" && patch -s -p0 bs_emit.erl < "$HERE/variants/$v.patch" >/dev/null)
  erlc -o "$W/ebin-$v" +debug_info "$W/src-$v/bs_emit.erl" >/dev/null 2>&1 || { echo "build $v failed"; exit 99; }
done
for f in narrow wide; do echo "diff base->$f: $(diff "$W/src-base/bs_emit.erl" "$W/src-$f/bs_emit.erl" | grep -c '^[<>]') changed lines"; done

# ---- P1: reproduce the asymmetry on the shipped compiler --------------------------------
# expect: exported record fn HAS a tag test; PRIVATE record fn HAS a tag test (unscoped);
#         exported int fn HAS is_integer; PRIVATE int fn has NONE.
bsc repo -o "$W/p1" "$HERE/src/Asym/asym.bs" >/dev/null
"$L/guards.escript" "$W/p1/Asym.beam" | grep -v type_atoms | tee "$OUT/P1-asymmetry.txt" >/dev/null
flag() { awk -v n="$2" '$2 ~ "^"n"/" { split($3,a,"="); split($4,b,"="); print (a[2]>0?"tag ":"") (b[2]>0?"int":"") }' "$1" | sed 's/ *$//'; }
pass_fail P1a "exported record param: tag test"        "tag"  "$(flag "$OUT/P1-asymmetry.txt" PubRec)"
pass_fail P1b "PRIVATE record param: tag test (unscoped)" "tag" "$(flag "$OUT/P1-asymmetry.txt" PrivRec)"
pass_fail P1c "exported refined-int param: is_integer" "int"  "$(flag "$OUT/P1-asymmetry.txt" PubInt)"
pass_fail P1d "PRIVATE refined-int param: no guard"    ""     "$(flag "$OUT/P1-asymmetry.txt" PrivInt)"
# expect: base (recompiled unpatched) emits byte-identical abstract code to the prebuilt repo compiler
bsc base -o "$W/p1b" "$HERE/src/Asym/asym.bs" >/dev/null
pass_fail P1e "recompiled base == shipped compiler (abstr identical)" "same" "$(cmp -s "$W/p1/Asym.abstr" "$W/p1b/Asym.abstr" && echo same || echo different)"
# expect: NARROW drops only the private tag test; WIDE adds only the private int guard.
for v in narrow wide; do bsc $v -o "$W/p1-$v" "$HERE/src/Asym/asym.bs" >/dev/null; "$L/guards.escript" "$W/p1-$v/Asym.beam" | grep -v type_atoms > "$OUT/P1-asymmetry-$v.txt"; done
pass_fail P1f "NARROW: private record fn loses its tag test, nothing else moves" "PubRec=tag PrivRec= PubInt=int PrivInt=" \
  "PubRec=$(flag "$OUT/P1-asymmetry-narrow.txt" PubRec) PrivRec=$(flag "$OUT/P1-asymmetry-narrow.txt" PrivRec) PubInt=$(flag "$OUT/P1-asymmetry-narrow.txt" PubInt) PrivInt=$(flag "$OUT/P1-asymmetry-narrow.txt" PrivInt)"
pass_fail P1g "WIDE: private int fn gains is_integer, tag test kept" "PubRec=tag PrivRec=tag PubInt=int PrivInt=int" \
  "PubRec=$(flag "$OUT/P1-asymmetry-wide.txt" PubRec) PrivRec=$(flag "$OUT/P1-asymmetry-wide.txt" PrivRec) PubInt=$(flag "$OUT/P1-asymmetry-wide.txt" PubInt) PrivInt=$(flag "$OUT/P1-asymmetry-wide.txt" PrivInt)"

# ---- P2: forgery through an exported function into a private one -----------------------
# A forged record has a wrong Kind tag; a forged int is out of the Octet domain or a float.
# Expectations (from reading guard_one: exported guards test the top-level parameter only; a private one is guarded only by the tag test):
#   Direct(forged record)         : exported guard fires at Direct/1                       - all variants
#   SumAll([forged])  list<Order> : element reaches private Amount/1; base+wide crash there, narrow returns 5 (silent)
#   SumInline([forged])           : no private helper, no guard anywhere                     - ok:5 in all variants
#   SumPair(({forged},1))         : as SumAll (tuple param has no top-level tag test)
#   ViaUnion(forged)              : the clause head refuses it at ViaUnion/1                - all variants
#   Buckets([100.5]) / Buckets([300]) list<Octet> : element reaches private Bucket/1; only WIDE crashes there
F='#{'"'"'Kind'"'"'=>'"'"'Other.Thing'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>5}'
GOOD='#{'"'"'Kind'"'"'=>'"'"'Fwd.Order'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>5}'
for v in repo narrow wide; do bsc $v -o "$W/p2-$v" "$HERE/src/Fwd/fwd.bs" >/dev/null; done
run() { "$L/call.escript" "$W/p2-$1" Fwd "$2" "$3" 2>&1 | head -1; }
{
for v in repo narrow wide; do
  echo "== $v"
  for c in "Direct|$F" "SumAll|[$F]" "SumInline|[$F]" "SumPair|{$F,1}" "ViaUnion|$F" "Buckets|[100.5]" "Buckets|[300]" "SumAll|[$GOOD]" "Buckets|[100]"; do
    echo "$(printf '%-10s %-60s' "${c%%|*}" "${c#*|}") -> $(run $v "${c%%|*}" "${c#*|}")"; done
done; } | sed "s/#{'Kind'=>'Other.Thing','Id'=>1,'Total'=>5}/FORGED/g; s/#{'Kind'=>'Fwd.Order','Id'=>1,'Total'=>5}/VALID/g" | tee "$OUT/P2-forgery.txt" >/dev/null
r() { run "$1" "$2" "$3"; }
pass_fail P2a "Direct(forged): caught at the exported function, every variant" \
  "error:function_clause@'Fwd':'Direct'/1 error:function_clause@'Fwd':'Direct'/1 error:function_clause@'Fwd':'Direct'/1" \
  "$(r repo Direct "$F") $(r narrow Direct "$F") $(r wide Direct "$F")"
pass_fail P2b "SumAll([forged]) via private helper: base crashes IN the private fn, narrow returns silently, wide crashes" \
  "error:function_clause@'Fwd':'Amount'/1 ok:5 error:function_clause@'Fwd':'Amount'/1" \
  "$(r repo SumAll "[$F]") $(r narrow SumAll "[$F]") $(r wide SumAll "[$F]")"
pass_fail P2c "SumPair(({forged},1)): same split as P2b" \
  "error:function_clause@'Fwd':'Amount'/1 ok:6 error:function_clause@'Fwd':'Amount'/1" \
  "$(r repo SumPair "{$F,1}") $(r narrow SumPair "{$F,1}") $(r wide SumPair "{$F,1}")"
pass_fail P2d "SumInline([forged]) (no private helper): silent in every variant" "ok:5 ok:5 ok:5" \
  "$(r repo SumInline "[$F]") $(r narrow SumInline "[$F]") $(r wide SumInline "[$F]")"
pass_fail P2e "ViaUnion(forged): clause head refuses it, every variant" \
  "error:function_clause@'Fwd':'ViaUnion'/1 error:function_clause@'Fwd':'ViaUnion'/1 error:function_clause@'Fwd':'ViaUnion'/1" \
  "$(r repo ViaUnion "$F") $(r narrow ViaUnion "$F") $(r wide ViaUnion "$F")"
pass_fail P2f "Buckets([300]) out-of-domain int under private helper: silent in base and narrow, crash in wide" \
  "ok:1 ok:1 error:function_clause@'Fwd':'Bucket'/1" "$(r repo Buckets "[300]") $(r narrow Buckets "[300]") $(r wide Buckets "[300]")"
pass_fail P2g "Buckets([100.5]) float under private helper: same split" \
  "ok:1 ok:1 error:function_clause@'Fwd':'Bucket'/1" "$(r repo Buckets "[100.5]") $(r narrow Buckets "[100.5]") $(r wide Buckets "[100.5]")"
pass_fail P2h "controls: valid record and valid int still answer in every variant" "ok:5 ok:5 ok:5 ok:1 ok:1 ok:1" \
  "$(r repo SumAll "[$GOOD]") $(r narrow SumAll "[$GOOD]") $(r wide SumAll "[$GOOD]") $(r repo Buckets "[100]") $(r narrow Buckets "[100]") $(r wide Buckets "[100]")"

# ---- P5b: does an exported function pay its guard when called from inside its own module? (ticket 18 §1: one entry label)
# expect: Caller's local `call` targets Exp's entry label, and that entry block contains is_integer; Priv's has none.
bsc repo -o "$W/p5b" "$HERE/src/Loc/loc.bs" >/dev/null
"$L/asm.escript" "$W/p5b/Loc.beam" 2>/dev/null > "$OUT/P5b-loc.asm.txt"
{ echo "Exp:  $("$L/localcall.escript" "$W/p5b/Loc.beam" Caller Exp)"; echo "Priv: $("$L/localcall.escript" "$W/p5b/Loc.beam" Caller Priv)"; } > "$OUT/P5b-localcall.txt"
pass_fail P5b1 "local call reaches the exported function's guarded entry label" "callee_has_is_integer=true calls_callee_entry=true" \
  "$(grep '^Exp:' "$OUT/P5b-localcall.txt" | grep -o 'callee_has_is_integer=[a-z]*') $(grep '^Exp:' "$OUT/P5b-localcall.txt" | grep -o 'calls_callee_entry=[a-z]*')"
pass_fail P5b2 "private sibling has no is_integer at its entry" "callee_has_is_integer=false" "$(grep '^Priv:' "$OUT/P5b-localcall.txt" | grep -o 'callee_has_is_integer=[a-z]*')"
# expect: under WIDE, erlc removes is_integer from a private callee whose callers prove an integer, but keeps the range tests
bsc wide -o "$W/p5c" "$HERE/src/Loc/loc.bs" >/dev/null
"$L/asm.escript" "$W/p5c/Loc.beam" 2>/dev/null > "$OUT/P5c-loc-wide.asm.txt"
pass_fail P5c "WIDE, callers prove int: private callee's is_integer erased by erlc, range tests kept" "callee_has_is_integer=false" \
  "$("$L/localcall.escript" "$W/p5c/Loc.beam" Caller Priv | grep -o 'callee_has_is_integer=[a-z]*')"

# ---- P8: a private function is reachable from outside as a function value (F46), and by a lambda that calls it
# Erlang-side caller applies the fun a public B# function returned, with an out-of-domain argument.
# The variants: repo/narrow/wide as before; refsite = narrow + the guard placed on the wrapper fun at the site that hands a private function out.
# expect (from reading F46's emission `fun 'Free'/1` and guard_one's Public test):
#   repo/narrow: private int callee unguarded  -> ok:-98.5 / ok:1 (silent);  repo keeps the record tag test, narrow does not
#   wide: crash inside the private callee;  refsite: crash inside the wrapper fun at the hand-out site
#   lambda calling a private fn: only WIDE catches it;  lambda with inline arithmetic: silent in every variant (no private fn to guard)
for v in repo narrow wide refsite; do
  case $v in repo) V=repo;; *) V=$v;; esac
  bsc $V -o "$W/p8-$v" "$HERE/src/Fv/fv.bs" >/dev/null
done
fv() { "$L/fvcall.escript" "$W/p8-$1" "$2" "$3" 2>&1 | head -1; }
FF='#{'"'"'Kind'"'"'=>'"'"'Other'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>5}'
{ for v in repo narrow wide refsite; do echo "== $v"
    for c in "Rule|1.5" "Banding|300" "Banding|100.5" "Reader|$FF" "ViaLambda|1.5" "InlineLambda|1.5" "Rule|150" "Banding|100"; do
      echo "$(printf '%-13s %-8s' "${c%%|*}" "$(echo "${c#*|}" | cut -c1-8)") -> $(fv $v "${c%%|*}" "${c#*|}")"; done; done; } > "$OUT/P8-function-values.txt"
q() { fv "$1" "$2" "$3"; }
pass_fail P8a "private int fn handed out as a value, called with 1.5: silent in repo+narrow, crash in callee (wide) / in wrapper (refsite)" \
  "ok:-98.5 ok:-98.5 error:function_clause@'Fv':'Shave'/1 error:function_clause@'Fv':'-Rule/1-fun-0-'/1" \
  "$(q repo Rule 1.5) $(q narrow Rule 1.5) $(q wide Rule 1.5) $(q refsite Rule 1.5)"
pass_fail P8b "private Octet fn handed out, called with 300: same split" \
  "ok:1 ok:1 error:function_clause@'Fv':'Band'/1 error:function_clause@'Fv':'-Banding/1-fun-0-'/1" \
  "$(q repo Banding 300) $(q narrow Banding 300) $(q wide Banding 300) $(q refsite Banding 300)"
pass_fail P8c "private record fn handed out, called with a forged map: repo keeps its tag test, narrow loses it" \
  "error:function_clause@'Fv':'Amount'/1 ok:5 error:function_clause@'Fv':'Amount'/1 error:function_clause@'Fv':'-Reader/1-fun-0-'/1" \
  "$(q repo Reader "$FF") $(q narrow Reader "$FF") $(q wide Reader "$FF") $(q refsite Reader "$FF")"
pass_fail P8d "lambda calling a private fn: only WIDE refuses 1.5" \
  "ok:-98.5 ok:-98.5 error:function_clause@'Fv':'Shave'/1 ok:-98.5" \
  "$(q repo ViaLambda 1.5) $(q narrow ViaLambda 1.5) $(q wide ViaLambda 1.5) $(q refsite ViaLambda 1.5)"
pass_fail P8e "lambda with inline arithmetic: silent in every variant (out of this ticket's reach)" \
  "ok:-98.5 ok:-98.5 ok:-98.5 ok:-98.5" "$(q repo InlineLambda 1.5) $(q narrow InlineLambda 1.5) $(q wide InlineLambda 1.5) $(q refsite InlineLambda 1.5)"
pass_fail P8f "controls: in-domain arguments still answer in every variant" "ok:50 ok:50 ok:50 ok:50 ok:1 ok:1 ok:1 ok:1" \
  "$(q repo Rule 150) $(q narrow Rule 150) $(q wide Rule 150) $(q refsite Rule 150) $(q repo Banding 100) $(q narrow Banding 100) $(q wide Banding 100) $(q refsite Banding 100)"
# expect: refsite's Asym is NARROW's (callee unguarded), and its nested-forgery result equals NARROW's (it does not touch nested values)
bsc refsite -o "$W/p8g" "$HERE/src/Fwd/fwd.bs" >/dev/null
pass_fail P8g "refsite leaves nested forgery to the callee exactly as narrow does (SumAll([forged]) -> ok:5)" "ok:5" "$("$L/call.escript" "$W/p8g" Fwd SumAll "[$F]" 2>&1 | head -1)"

# ---- P4: size and compile time -------------------------------------------------------
# expect (ticket 26a / 18): tag test ~ +14 bytes of Code per private function; is_integer +3-5 per test.
# pre-stated pass band: tag 10..18 B/fn, int (is_integer + 2 comparisons) 3..40 B/fn at K=100.
S=$W/sz; rm -rf "$S"; mkdir -p "$S"
{
printf '%-6s %-4s %-7s %10s %10s %10s\n' kind K variant file_B stripped_B code_B
for kind in rec int; do for k in 1 10 100; do
  "$L/gen.escript" "$S/Sz$kind$k" $k $kind
  for v in repo narrow wide; do
    bsc $v -o "$S/o-$v-$kind$k" "$S/Sz$kind$k/x.bs" >/dev/null 2>&1
    printf '%-6s %-4s %-7s %s\n' $kind $k $v "$("$L/size.escript" "$S/o-$v-$kind$k/Sz$kind$k.beam" | awk '{printf "%10s %10s %10s",$1,$2,$3}')"
  done; done; done; } | tee "$OUT/P4-size.txt" >/dev/null
code() { awk -v k="$1" -v n="$2" -v v="$3" '$1==k && $2==n && $3==v {print $6}' "$OUT/P4-size.txt"; }
tagB=$(echo "scale=2; ($(code rec 100 repo) - $(code rec 100 narrow)) / 100" | bc)
intB=$(echo "scale=2; ($(code int 100 wide) - $(code int 100 repo)) / 100" | bc)
echo "per private function at K=100: tag test = $tagB B Code; int guard (unproved args) = $intB B Code" | tee -a "$OUT/P4-size.txt"
pass_fail P4a "tag test costs 10..18 Code bytes per private function" "yes" "$(echo "$tagB >= 10 && $tagB <= 18" | bc | sed 's/1/yes/;s/0/no/')"
pass_fail P4b "int guard on private (args unproved) costs 3..40 Code bytes per function" "yes" "$(echo "$intB >= 3 && $intB <= 40" | bc | sed 's/1/yes/;s/0/no/')"
pass_fail P4c "NARROW changes int-only modules by 0 bytes; WIDE changes rec-only modules by 0 bytes" "0 0" "$(( $(code int 100 narrow) - $(code int 100 repo) )) $(( $(code rec 100 wide) - $(code rec 100 repo) ))"
# compile time (report only)
{ for v in repo narrow wide; do case $v in repo) E=$SP/bsc/ebin;; *) E=$W/ebin-$v;; esac
    echo "compile time rec K=100 $v: $("$L/ctime.escript" "$E" "$S/Szrec100/x.bs" $CRUNS)"
    echo "compile time int K=100 $v: $("$L/ctime.escript" "$E" "$S/Szint100/x.bs" $CRUNS)"; done; } | tee "$OUT/P4-compile-time.txt" >/dev/null
echo "INFO P4d compile time in $OUT/P4-compile-time.txt (report only, no expectation)"

# ---- P7: the shipped corpus (compiler/examples, 22 modules)
# expect: the asymmetry is UNEXERCISED there (no private function carries a tag test); WIDE adds int guards to abstract code but 0 bytes of Code.
C=$W/corp; rm -rf "$C"; mkdir -p "$C"
for v in repo narrow wide; do for d in "$REPO"/compiler/examples/*/; do n=$(basename "$d"); [ "$n" = exemplars ] && continue
  bsc $v --src-root "$REPO/compiler/examples" -o "$C/$v/$n" "$d" >/dev/null 2>&1 || echo "corpus $v $n failed"; done
  echo "$v: $("$L/corpus.escript" "$C/$v"/*)"; done | tee "$OUT/P7-corpus.txt" >/dev/null
pass_fail P7a "corpus: no private function carries a tag test under the shipped compiler" "private with: tag=0" "$(grep '^repo:' "$OUT/P7-corpus.txt" | grep -o 'private with: tag=[0-9]*')"
RB=$(grep '^repo:' "$OUT/P7-corpus.txt" | grep -o 'code_bytes=[0-9]*'); WB=$(grep '^wide:' "$OUT/P7-corpus.txt" | grep -o 'code_bytes=[0-9]*')
pass_fail P7b "corpus: WIDE Code bytes == base Code bytes, and both were measured (erlc erases the private int guards)" "equal-and-nonempty" "$([ -n "$RB" ] && [ "$RB" = "$WB" ] && echo equal-and-nonempty || echo "base=[$RB] wide=[$WB]")"
pass_fail P7c "corpus: WIDE adds private int guards to the abstract code (count > base)" yes "$(a=$(grep '^repo:' "$OUT/P7-corpus.txt" | grep -o 'private with: tag=[0-9]* kind=[0-9]*' | grep -o 'kind=[0-9]*' | cut -d= -f2); b=$(grep '^wide:' "$OUT/P7-corpus.txt" | grep -o 'private with: tag=[0-9]* kind=[0-9]*' | grep -o 'kind=[0-9]*' | cut -d= -f2); [ -n "$a" ] && [ "${b:-0}" -gt "$a" ] && echo yes || echo "base=$a wide=$b")"

# ---- P3/P5: hot-loop cost, 1e7 self-recursive calls, min/median of N runs ------------------
# Ticket 18 says a guard is below 0.09 ns/call resolution. Stated expectations (a claim of MY OWN, not the ticket's):
#   RecP:  NARROW at least 1 ns/call faster than base   (tag test removed; ticket's claim would make this ~0)
#   IntP:  WIDE at least 0.5 ns/call slower than base   (3 int params guarded per call, args unprovable to erlc in a self-loop)
#   IntE:  exported self-recursive loop at least 1 ns/call slower than the private one in base (one entry label)
# The host is shared, so each variant is measured in 3 attempts of $RUNS runs and the reported figure is the minimum over all attempts (a contended attempt only ever adds time).
for v in repo narrow wide; do bsc $v -o "$W/p3-$v" "$HERE/src/Bench/bench.bs" >/dev/null; : > "$OUT/P3-bench-$v.txt"
  for a in 1 2 3; do echo "# attempt $a" >> "$OUT/P3-bench-$v.txt"; "$L/bench.escript" "$W/p3-$v" $RUNS >> "$OUT/P3-bench-$v.txt"; done; done
b() { grep "$2" "$OUT/P3-bench-$1.txt" | sed -E 's/.*min= *[0-9]+ us +median= *[0-9]+ us +min= *([0-9.]+) ns.*/\1/' | sort -n | head -1; }
gt() { echo "$1 - $2 >= $3" | bc -l | sed 's/1/yes/;s/0/no/'; }
gt() { echo "$1 - $2 >= $3" | bc -l | sed 's/^1$/yes/;s/^0$/no/'; }
show() { echo "     (base $(b repo "$1") / narrow $(b narrow "$1") / wide $(b wide "$1") ns per call, min of $RUNS)"; }
pass_fail P3a "RecP: NARROW >= 1.0 ns/call faster than base"  yes "$(gt "$(b repo RecP)" "$(b narrow RecP)" 1.0)"; show RecP
pass_fail P3b "IntP (unproved): WIDE >= 0.5 ns/call slower than base" yes "$(gt "$(b wide 'private, int unproved')" "$(b repo 'private, int unproved')" 0.5)"; show 'private, int unproved'
pass_fail P3c "IntE: exported self-loop >= 1.0 ns/call slower than private loop (base)" yes "$(gt "$(b repo 'EXPORTED')" "$(b repo 'private, int proved')" 1.0)"
pass_fail P3d "RecP: base and WIDE both pay the tag test (within 15% of each other)" yes "$(echo "r = $(b wide RecP) / $(b repo RecP); r < 1.15 && r > 0.85" | bc -l | sed 's/^1$/yes/;s/^0$/no/')"

# ---- P9: the repo's own eunit suite against each variant ---------------------------------
# No rebar3 here, so the test modules are compiled with erlc and run under eunit against each patched emitter.
# Baseline failures are environmental (OTP 25 lacks maps:iterator/2 and json:decode/1, and no escript is built); only the DIFFERENCE between variants is claimed.
# expect: narrow and refsite fail exactly what base fails (no test pins the private tag test);
#         wide fails exactly base + a_private_function_is_not_guarded_test (F24.6) + a_private_function_carries_no_range_guard_test (F37.5).
T=$W/ctest; rm -rf "$T"; mkdir -p "$T/tebin"; cp -r "$REPO"/compiler/{test,examples,features,bin} "$T/" 2>/dev/null
erlc -o "$T/tebin" -I "$T" "$T"/test/*.erl >/dev/null 2>&1
for v in base narrow wide refsite; do
  (cd "$T" && "$L/runtests.escript" "$W/ebin-$v" > "$W/eunit-$v.txt" 2>&1)
  grep -E '^[a-z_0-9]+:[0-9]*:? .*\*failed\*|^[a-z_0-9]+: .*\*failed\*' "$W/eunit-$v.txt" | sed -E 's/^([a-z_0-9]+:[0-9]*:? ?[^.]*)\.\.\..*/\1/' | sort > "$W/fail-$v.txt"
  echo "$v: $(grep -E 'Failed: [0-9]+' "$W/eunit-$v.txt" | tail -1)"
done | tee "$OUT/P9-eunit-summary.txt"
diff "$W/fail-base.txt" "$W/fail-wide.txt" > "$OUT/P9-wide-vs-base.diff"; cp "$W/fail-base.txt" "$OUT/P9-baseline-failures.txt"
pass_fail P9a "narrow fails the same tests as base" "" "$(diff "$W/fail-base.txt" "$W/fail-narrow.txt")"
pass_fail P9b "refsite fails the same tests as base" "" "$(diff "$W/fail-base.txt" "$W/fail-refsite.txt")"
pass_fail P9c "wide adds exactly the two private-unguarded assertions" "> boundary_kind_tests: a_private_function_is_not_guarded_test > boundary_range_tests: a_private_function_carries_no_range_guard_test" \
  "$(grep '^[<>]' "$OUT/P9-wide-vs-base.diff" | tr '\n' ' ' | sed 's/ $//')"
pass_fail P9d "the baseline was actually measured (>= 100 failing-or-passing lines parsed)" yes "$([ "$(wc -l < "$W/fail-base.txt")" -ge 100 ] && echo yes || echo no)"

# ---- P6: neighbours -------------------------------------------------------------------
# Gleam expect: NO runtime type test on any parameter, exported or private, opaque type or Int:
#   the generated .erl has no `when`/is_*, pub_total({wrong,1,5}) returns 5, pub_int(1.5) returns 2.5.
G=$W/gleam; rm -rf "$G"; mkdir -p "$G"; cp -r "$HERE/neighbours/gleam/." "$G/"
if (cd "$G" && "${GLEAM:-/tmp/claude-0/tools/gleam}" build >"$OUT/P6-gleam-build.txt" 2>&1); then
  cp "$G/build/dev/erlang/probe59/_gleam_artefacts/probe59.erl" "$OUT/P6-gleam-emitted.erl"
  pass_fail P6a "Gleam: emitted Erlang has no guard or is_* test anywhere" "0" "$(grep -cE 'when |is_integer|is_float|is_tuple|is_map' "$OUT/P6-gleam-emitted.erl")"
  GO=$(erl -noshell -pa "$G/build/dev/erlang/probe59/ebin" -eval 'io:format("~p ~p ~p",[probe59:pub_total({wrong,1,5}), probe59:use_it({wrong,1,5}), probe59:pub_int(1.5)]),halt().')
  echo "$GO" > "$OUT/P6-gleam-forged.txt"
  pass_fail P6b "Gleam: forged tuple passes exported AND private; float passes Int param" "5 5 2.5" "$GO"
else echo "NOT-RUN P6 Gleam build failed, see $OUT/P6-gleam-build.txt"; fi
# Elixir expect: def and defp with the SAME written head/guard compile to identical code (the compiler adds nothing by visibility),
#   @spec adds no test (spec_only has no `when` and no __struct__ match), and the written struct pattern / is_struct / is_integer are real tests.
X=$W/elixir; rm -rf "$X"; mkdir -p "$X"; cp "$HERE"/neighbours/elixir/* "$X/"
if (cd "$X" && elixirc probe59.ex -o ebin >/dev/null 2>&1 && elixir dump.exs > "$OUT/P6-elixir-forms.txt" 2>&1); then
  fn() { awk -v n="$1" '$0 ~ "^"n"\\(" {p=1} p {print} p && /\.$/ {exit}' "$OUT/P6-elixir-forms.txt" | sed "s/^$1(/F(/"; }
  for pair in struct guard int; do
    pass_fail "P6c-$pair" "Elixir: pub_$pair and priv_$pair compile to identical code" "same" "$([ "$(fn pub_$pair)" = "$(fn priv_$pair)" ] && [ -n "$(fn pub_$pair)" ] && echo same || echo different)"; done
  pass_fail P6d "Elixir: @spec-only function's head is a bare variable (no test)" "F(_o@1) ->" "$(fn spec_only | head -1)"
else echo "NOT-RUN P6 Elixir compile failed"; fi
# Erlang expect: -spec is not enforced: pub(1.5) and (via priv) use(1.5) both answer 2.5; no test in the emitted asm.
E=$W/erl; rm -rf "$E"; mkdir -p "$E"; erlc -o "$E" "$HERE/neighbours/erlang/e59.erl"
EO=$(erl -noshell -pa "$E" -eval 'io:format("~p ~p",[e59:pub(1.5), e59:use(1.5)]),halt().'); echo "$EO" > "$OUT/P6-erlang.txt"
pass_fail P6e "Erlang: -spec integer() does not stop a float, exported or private" "2.5 2.5" "$EO"
# Elm: cannot compile without package.elm-lang.org.  Recorded, not asserted.
EL=$W/elm; rm -rf "$EL"; mkdir -p "$EL"; cp -r "$SP/work/59/elm/." "$EL/" 2>/dev/null
if (cd "$EL" && HOME="$EL/home" timeout 60 /tmp/claude-0/tools/node_modules/.bin/elm make src/Main.elm --output=/dev/null > "$OUT/P6-elm.txt" 2>&1); then echo "INFO P6f Elm compiled: see $OUT/P6-elm.txt (no claim made in the brief)"
else echo "NOT-RUN P6f Elm cannot fetch packages: $(grep -m1 -o 'PROBLEM LOADING PACKAGE LIST' "$OUT/P6-elm.txt")"; fi

echo; echo "FAILS=$FAILS"; exit $FAILS
