#!/usr/bin/env bash
# ticket 57 probes. usage: run.sh [--no-setup] [--quick] [--regress]. Prints PASS/FAIL per (case, compiler) against the
# expectation written in cases.sh, then the run-time agreement and residual probes. Exit 1 on any FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}
case " $* " in *" --no-setup "*) ;; *) "$here/setup.sh" || exit 1;; esac
COMPS="base Ag Amut Bx B0 Bn"
out=$W/run; rm -rf "$out"; mkdir -p "$out"
fails=0; total=0
bsc () { local eb=$1; shift; "$here/bsc-with.sh" "$W/$eb/ebin" "$@"; }

c () {   # c ID "exp x6" desc  (source on stdin)
    local id=$1 exp=($2) desc=$3 i=0 v got d mark
    mkdir -p "$out/src/$id"; { printf 'module %s\n' "$id"; cat; } > "$out/src/$id/a.bs"
    printf '\n[%s] %s\n' "$id" "$desc"
    for v in $COMPS; do
        d="$out/obj/$v/$id"; mkdir -p "$d"
        if msg=$(bsc "$v" -o "$d" "$out/src/$id/a.bs" 2>&1) && [ -z "$msg" ]; then got=a; else got=r; fi
        printf '%s\n' "$msg" > "$out/diag_${id}_$v.txt"
        total=$((total+1)); mark=PASS
        [ "$got" = "${exp[$i]}" ] || { mark=FAIL; fails=$((fails+1)); }
        printf '  %-4s %-6s expected %s observed %s   %s\n' $mark $v "${exp[$i]}" $got \
            "$(printf '%s' "$msg" | head -1 | sed "s#$out/src/##;s/^.*error: //" | cut -c1-70)"
        i=$((i+1))
    done
}
. "$here/cases.sh"

# --- run-time agreement: the same predicate as a guard and as a refinement ---------------------------
# EXPECTED before run (A, Aprod, B0, Bn, Ba): in [-5,5] both say :in; outside, R crashes with
# function_clause at the exported boundary (F37) and G returns :out. base: module refused (R1 shape).
echo; echo "[AGREE] refinement D = -5..5 at an exported boundary vs guard n >= -5 and n <= 5"
mkdir -p "$out/src/Agree"; cat > "$out/src/Agree/a.bs" <<'EOF'
module Agree
type D = int where value >= -5 and value <= 5
public atom R(D d)
R(d) -> :in
public atom G(int n)
G(n) when n >= -5 and n <= 5 -> :in
G(n) when n < -5 or n > 5    -> :out
EOF
for v in $COMPS; do
    d="$out/obj/$v/Agree"; mkdir -p "$d"; total=$((total+1))
    if [ $v = base ]; then
        if bsc $v -o "$d" "$out/src/Agree/a.bs" >/dev/null 2>&1; then echo "  FAIL base expected refused"; fails=$((fails+1)); else echo "  PASS base refused (as expected)"; fi
        continue
    fi
    row=""; ok=1
    for n in -6 -5 0 5 6; do
        r=$(bsc $v -o "$d" "$out/src/Agree/a.bs" R $n 2>&1 | head -1)
        g=$(bsc $v -o "$d" "$out/src/Agree/a.bs" G $n 2>&1 | head -1)
        case $n in -6|6) er="crashed: error:function_clause"; eg=":out";; *) er=":in"; eg=":in";; esac
        [ "$r" = "$er" ] && [ "$g" = "$eg" ] || ok=0
        row="$row $n:R=$r,G=$g"
    done
    [ $ok = 1 ] && echo "  PASS $v$row" || { echo "  FAIL $v$row"; fails=$((fails+1)); }
done

# --- guard alone, run-time, with a catch-all (compiles in every compiler, incl. base) --------------
# EXPECTED: the emitted guard is right in every compiler: -6:out -5:in 0:in 5:in 6:out
echo; echo "[GUARD-RUNS] G(n) when n >= -5 and n <= 5 -> :in ; G(_) -> :out, run on each compiler"
mkdir -p "$out/src/GuardRuns"; printf 'module GuardRuns\npublic atom G(int n)\nG(n) when n >= -5 and n <= 5 -> :in\nG(_) -> :out\n' > "$out/src/GuardRuns/a.bs"
for v in $COMPS; do
    d="$out/obj/$v/GuardRuns"; mkdir -p "$d"; total=$((total+1)); row=""
    for n in -6 -5 0 5 6; do row="$row $n:$(bsc $v -o "$d" "$out/src/GuardRuns/a.bs" G $n 2>&1 | head -1)"; done
    [ "$row" = " -6::out -5::in 0::in 5::in 6::out" ] && echo "  PASS $v$row" || { echo "  FAIL $v$row"; fails=$((fails+1)); }
done

# --- residual doctrine -------------------------------------------------------------------------------
# EXPECTED: (1) under A and B* the residual of Kind(0) over Delta = -10..10 prints as two head lines
# with negative bounds, `Kind(>= -10 and <= -1)` and `Kind(>= 1 and <= 10)`; base cannot declare Delta.
# (2) pasting those printed heads back as clauses is ACCEPTED (patterns already read negatives).
# (3) the printed TYPE of a mismatch is `int <= -11 | int >= 11`, which is not a type spelling in any
# compiler here: pasting it as `type T = int <= -11 | int >= 11` is REFUSED everywhere.
echo; echo "[RESIDUAL] subtract(-10..10, 0)"
mkdir -p "$out/src/Res"; printf 'module Res\ntype Delta = int where value >= -10 and value <= 10\npublic atom Kind(Delta d)\nKind(0) -> :zero\n' > "$out/src/Res/a.bs"
for v in $COMPS; do
    d="$out/obj/$v/Res"; mkdir -p "$d"; total=$((total+1))
    msg=$(bsc $v -o "$d" "$out/src/Res/a.bs" 2>&1)
    if [ $v = base ]; then
        case "$msg" in *"not a predicate the checker can read"*) echo "  PASS base cannot declare Delta (opaque_refinement)";; *) echo "  FAIL base: $msg"; fails=$((fails+1));; esac
        continue
    fi
    heads=$(printf '%s\n' "$msg" | grep -o 'Kind(.*) ->' | sed 's/ ->$//')
    want=$'Kind(>= -10 and <= -1)\nKind(>= 1 and <= 10)'
    if [ "$heads" = "$want" ]; then
        mkdir -p "$out/src/Res2"; { printf 'module Res2\ntype Delta = int where value >= -10 and value <= 10\npublic atom Kind(Delta d)\nKind(0) -> :zero\n'; printf '%s\n' "$heads" | sed 's/$/ -> :other/'; } > "$out/src/Res2/a.bs"
        if m2=$(bsc $v -o "$d" "$out/src/Res2/a.bs" 2>&1) && [ -z "$m2" ]; then echo "  PASS $v residual heads printed and re-accepted: $(echo $heads | tr '\n' ' ')"; else echo "  FAIL $v pasted residual refused: $m2"; fails=$((fails+1)); fi
    else echo "  FAIL $v heads: $heads"; fails=$((fails+1)); fi
done
total=$((total+1))
printf 'module Ty\ntype T = int <= -11 | int >= 11\n' > "$out/src/Res/ty.bs"; mkdir -p "$out/src/Ty"; mv "$out/src/Res/ty.bs" "$out/src/Ty/a.bs"
n=0; for v in $COMPS; do bsc $v -o "$out/obj/$v/Ty" "$out/src/Ty/a.bs" >/dev/null 2>&1 || n=$((n+1)); done
[ $n = 6 ] && echo "  PASS the printed type text 'int <= -11 | int >= 11' is refused as a type in all 6 compilers" || { echo "  FAIL printed type text accepted by some compiler"; fails=$((fails+1)); }

# --- the ticket's five rows on the REFERENCE compiler (scratchpad bsc.sh), not on my rebuild ---------
# EXPECTED (ticket 57 table): R1 refused, R2 refused, R3 refused, R4 accepted, R5 accepted.
REF=${REF:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/bsc.sh}
echo; echo "[REF] ticket table on $REF"
if [ -x "$REF" ]; then
  for pair in R1:r R2:r R3:r R4:a R5:a; do
    id=${pair%%:*}; want=${pair##*:}; total=$((total+1))
    if m=$("$REF" -o "$out/obj/ref_$id" "$out/src/$id/a.bs" 2>&1) && [ -z "$m" ]; then got=a; else got=r; fi
    [ $got = $want ] && echo "  PASS $id reference compiler: expected $want observed $got" || { echo "  FAIL $id expected $want observed $got"; fails=$((fails+1)); }
  done
else echo "  SKIP reference bsc.sh not found at $REF"; fi

# --- arithmetic with negative literals: value must not change under any variant ---------------------
# EXPECTED (all six compilers): -7 / 2 = -3 ; -7 % 2 = -1 ; - 2 * 3 + -4 - -1 = -9 ; 10 - -3 = 13
echo; echo "[ARITH] run-time values of expressions containing negative literals"
mkdir -p "$out/src/Arith"; cat > "$out/src/Arith/a.bs" <<'EOF'
module Arith
public int Div()
Div() -> -7 / 2
public int Rem()
Rem() -> -7 % 2
public int Mix()
Mix() -> - 2 * 3 + -4 - -1
public int Sub()
Sub() -> 10 - -3
EOF
for v in $COMPS; do
    d="$out/obj/$v/Arith"; mkdir -p "$d"; total=$((total+1)); row=""
    for f in Div Rem Mix Sub; do row="$row $f=$(bsc $v -o "$d" "$out/src/Arith/a.bs" $f 2>&1 | head -1)"; done
    [ "$row" = " Div=-3 Rem=-1 Mix=-9 Sub=13" ] && echo "  PASS $v$row" || { echo "  FAIL $v$row"; fails=$((fails+1)); }
done

# --- what does `value >= -5` parse to at HEAD? -------------------------------------------------------
# The ticket says {e_op,'-',{e_int,0},{e_int,5}} (unary minus desugared to 0 - 5). F51 replaced that
# desugaring with an e_neg node (bs_parser.yrl negate/2). EXPECTED: base, B0, Bn, Ba parse the comparand
# to {e_neg,_,{e_int,_,5}}; A and Aprod parse it to {e_int,_,-5}.
echo; echo "[AST] comparand of  value >= -5"
for v in $COMPS; do
    total=$((total+1))
    got=$(erl -noshell -pa "$W/$v/ebin" -eval '{ok,T,_}=bs_lexer:string("module M\ntype T = int where value >= -5\n"), {ok,[_,{type_refined,_,_,_,{e_op,_,_,_,R}}]}=bs_parser:parse(T), io:format("~s",[case R of {e_neg,_,{e_int,_,5}} -> "e_neg(e_int 5)"; {e_int,_,-5} -> "e_int -5"; Other -> io_lib:format("~p",[Other]) end]), halt().')
    case $v in A|Aprod) want="e_int -5";; *) want="e_neg(e_int 5)";; esac
    [ "$got" = "$want" ] && echo "  PASS $v comparand = $got" || { echo "  FAIL $v comparand = $got (expected $want)"; fails=$((fails+1)); }
done

echo; echo "TOTAL $total checks, $fails FAIL"
[ $fails = 0 ] && echo "ALL PASS" || echo "SOME FAIL"
rc=0; [ $fails = 0 ] || rc=1
# Everything else, headless. Flags: --no-setup (reuse builds), --quick (skip the rest), --regress (add the
# ~5 min/variant eunit suites, run one variant at a time; compare $W/reg_<v>.failset against reg_base.failset).
case " $* " in *" --quick "*) exit $rc;; esac
echo; echo "=== abstract format"; "$here/abstr.sh" || rc=1
echo; echo "=== neighbours"; "$here/neighbours/run.sh" || rc=1
echo; echo "=== measure (M1 yecc, M2 lines, M3 compile time; expectations in measure.sh header)"; "$here/measure.sh" || rc=1
case " $* " in *" --regress "*)
  echo; echo "=== regress (sequential)"
  for v in base A Aprod B0 Bn Ba; do "$here/regress.sh" $v; done
  for v in A Aprod B0 Bn Ba; do printf '%-6s failset differs from base: ' $v; comm -3 "$W/reg_base.failset" "$W/reg_$v.failset" | wc -l; done;;
esac
exit $rc
