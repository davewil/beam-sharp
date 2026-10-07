#!/usr/bin/env bash
# 57e: Claim: each candidate fix (patches/*.patch, applied to a COPY of compiler/src; the repo is not
# touched) turns the refused refinements into accepted ones, and the answer to "where does the fold
# stop" differs by variant. Measures, per variant: the case matrix, the emitted abstract code for a
# module using `-5`, whether the BEAM Code chunk differs from the unpatched build, .beam size,
# and compile time (min/median of N=7 runs of one bsc invocation incl. VM boot).
#   v0   unpatched (the CONTROL: must reproduce 57a's refusals, else the harness lies)
#   v1   parser: negate/2 folds an int literal like it already folds a float literal   (1 line)
#   v2   checker: comparison/1 reads a comparand through const_int/1 (literal, under unary minus)
#   v2b  v2 + type_of(e_neg(e_int)) is the singleton range (so `Id(-3)` is accepted)
#   v2c  v2b + const_int folds + - * of constants (`value >= 2 + 3`)
#   v3   grammar narrowing: `refinement` is a real nonterminal over `value <op> int_lit` (ticket's option 1)
# Run from repo root with scratchpad env.sh sourced.   Usage: 57e_variants.sh [WORKDIR]
set -u
here=$(cd "$(dirname "$0")" && pwd); root=$(pwd)
W=${1:-$(mktemp -d)}; mkdir -p "$W"
for v in v0 v1 v2 v2b v2c v3; do
  mkdir -p "$W/$v"; cp -r "$root/compiler/src" "$W/$v/src"
  case $v in v1|v3) f=bs_parser.yrl;; v0) f=;; *) f=bs_check.erl;; esac
  [ -n "$f" ] && patch -s "$W/$v/src/$f" < "$here/patches/$v.patch"
  "$here/build_variant.sh" "$W/$v/src" "$W/$v/ebin"
  printf '#!/usr/bin/env bash\nexec erl -noshell -pa %s -eval '"'"'bsc:main(init:get_plain_arguments())'"'"' -extra "$@"\n' "$W/$v/ebin" > "$W/$v/bsc.sh"; chmod +x "$W/$v/bsc.sh"
done
# `Neg_eq_single*` is refused in EVERY variant for an unrelated reason: a singleton refinement crashes -spec emission (probe 57g).
cases() {  # prints "NAME got" lines using $BSC
  . "$here/lib.sh" >/dev/null 2>&1
  WORK=$(mktemp -d)
  R='public int Id(T b)
Id(b) -> b'
  c() { probe "$1" x "$2" | awk '{print $1" "$2" "$3}' | sed 's/^\(ok\|!!\) *//' | awk '{print $1, $2}'; }
  c Neg_ge_5        "type T = int where value >= -5
$R"
  c Neg_and_range   "type T = int where value >= -5 and value <= 5
$R"
  c Neg_or_split    "type T = int where value >= 1 or value <= -1
$R"
  c Neg_eq_single*  "type T = int where value == -1
$R"
  c Neg_ne          "type T = int where value != -1
$R"
  c Lit_on_left     "type T = int where -5 <= value
$R"
  c Parenthesised   "type T = int where (value >= -5) and (value <= 5)
$R"
  c Sum_2plus3      "type T = int where value >= 2 + 3
$R"
  c ParenNeg        "type T = int where value >= -(5)
$R"
  c DoubleNeg       "type T = int where value >= - -5
$R"
  c Zero_minus_5    "type T = int where value >= 0 - 5
$R"
  c Product_2x3     "type T = int where value >= 2 * 3
$R"
  c Var_comparand   "public int Go(int n)
type T = int where value >= n
Go(n) -> n"
  c Atom_eq_ctl     "type T = :a | :b | :c
type U = T where value == :a
public T Id(U b)
Id(b) -> b"
  c Call_refinement "type T = int where Foo(value)
$R"
  c Pos_ctl         "type T = int where value >= 5
$R"
  c Guard_neg_cover "public atom S(int n)
S(n) when n >= -5 -> :a
S(n) when n < -5 -> :b"
  c NegLit_argument "type T = int where value <= 3
public int Id(T b)
public int Go()
Id(b) -> b
Go() -> Id(-3)"
  c Neg_domain_ok   "type Delta = int where value >= -100 and value <= 100
public Delta Id(Delta d)
Id(d) -> d"
  c Neg_residual    "type D = int where value >= -10 and value <= 10
public atom Sign(D d)
Sign(0) -> :zero
Sign(>= 1) -> :pos"
}
for v in v0 v1 v2 v2b v2c v3; do BSC="$W/$v/bsc.sh" cases > "$W/$v.cases"; done
echo "== case matrix (accepted/refused), measured =="
{ printf 'case v0 v1 v2 v2b v2c v3\n'
  paste -d' ' "$W/v0.cases" <(cut -d' ' -f2 "$W/v1.cases") <(cut -d' ' -f2 "$W/v2.cases") <(cut -d' ' -f2 "$W/v2b.cases") <(cut -d' ' -f2 "$W/v2c.cases") <(cut -d' ' -f2 "$W/v3.cases"); } | awk '{printf "%-18s",$1; for(i=2;i<=NF;i++) printf " %-9s",$i; print ""}'
echo
echo "== first diagnostic for a negative literal on the left of a bare '=' (57b NegBare), per variant =="
mkdir -p "$W/nb/NegBare"; printf 'module NegBare\npublic int F((int, int) p)\nF(p) ->\n    (_, -1) = p\n    0\n' > "$W/nb/NegBare/a.bs"
for v in v0 v1 v2 v2b v2c v3; do printf '  %-4s ' $v; "$W/$v/bsc.sh" --src-root "$W/nb" -o "$W/nbo" "$W/nb/NegBare" 2>&1 | head -1 | sed "s#$W/nb/##" | cut -c1-110; done
echo
echo "== abstract code for a module using -5 (guard, literal body, arithmetic), diff vs v0 =="
mkdir -p "$W/ab/M"; cat > "$W/ab/M/a.bs" <<'EOT'
module M

public atom G(int n)
G(n) when n >= -5 -> :a
G(n) -> :b

public int Neg()
Neg() -> -5

public int Calc(int n)
Calc(n) -> n + -5
EOT
for v in v0 v1 v2 v2b v2c v3; do "$W/$v/bsc.sh" --src-root "$W/ab" -o "$W/ab_$v" "$W/ab/M" 2>&1 | head -2; done
for v in v1 v2 v2b v2c v3; do
  echo "-- $v vs v0 (.abstr, positions stripped):"
  diff <(sed 's/{[0-9]*,[0-9]*}/P/g;s#"/[^"]*"#F#' "$W/ab_v0/M.abstr") <(sed 's/{[0-9]*,[0-9]*}/P/g;s#"/[^"]*"#F#' "$W/ab_$v/M.abstr") && echo "   identical"
done
echo
echo "== precedent: v0 ALREADY emits a negative {integer,_,-N} node for a negative PATTERN literal and relational pattern bound =="
mkdir -p "$W/pt/P"; printf 'module P\npublic atom Sign(int n)\nSign(-7) -> :seven\nSign(<= -1) -> :neg\nSign(_) -> :other\n' > "$W/pt/P/a.bs"
"$W/v0/bsc.sh" --src-root "$W/pt" -o "$W/pto" "$W/pt/P" 2>&1 | head -2; grep -n -- "-7}\|,-1}" "$W/pto/P.abstr" | sed 's/^/  /'
echo
echo "== BEAM Code chunk and .beam size, vs v0 =="
for v in v0 v1 v2 v2b v2c v3; do
  erl -noshell -eval '{ok,{_,[{"Code",C}]}} = beam_lib:chunks("'"$W/ab_$v/M.beam"'",["Code"]), io:format("  '$v' Code-chunk-md5=~s beam_bytes=~p~n",[binary:encode_hex(crypto:hash(md5,C)), filelib:file_size("'"$W/ab_$v/M.beam"'")]), halt().'
done
echo
echo "== compile time, N=7 per variant (ms, whole bsc invocation incl. VM boot) =="
for v in v0 v1 v2 v2b v2c v3; do
  ts=(); for i in 1 2 3 4 5 6 7; do s=$(date +%s%N); "$W/$v/bsc.sh" --src-root "$W/ab" -o "$W/abt" "$W/ab/M" >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n)); echo "  $v min=${sorted[0]} median=${sorted[3]} max=${sorted[6]}"
done
echo "(timing is boot-dominated; the point is 'no measurable difference', not a speed claim)"
