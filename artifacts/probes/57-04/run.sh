#!/usr/bin/env bash
# 57/04 three prototype fixes, built from patches in THIS directory against a COPY of compiler/
# (the real tree is never edited). Runs the same cases against baseline, A, B, C.
#   A = parser: negate/2 folds an integer literal (as it already does for floats)
#   B = checker: comparison/1 folds  -<int literal>  only
#   C = checker: comparison/1 folds  + - * and unary - over int literals
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
build () { local v=$1 p=$2
  mkdir -p "$work/$v/compiler"; (cd "$root/compiler" && tar cf - --exclude=_build --exclude='*.beam' .) | (cd "$work/$v/compiler" && tar xf -)
  [ -n "$p" ] && (cd "$work/$v" && patch -s -p1 < "$here/$p")
  (cd "$work/$v/compiler" && rebar3 escriptize >/dev/null 2>&1); }
build base ""; build A A-parser-fold.patch; build B B-checker-fold.patch; build C C-checker-fold.patch
cases () { # $1 = bsc
  local bsc=$1 n src out
  c () { n=$1; src=$2; mkdir -p "$work/c/$n"; printf 'module %s\n%s\n' "$n" "$src" > "$work/c/$n/a.bs"
    out=$(cd "$work" && "$bsc" "$work/c/$n/a.bs" 2>&1); if [ -z "$out" ]; then printf '  %-14s accepted\n' "$n"; else printf '  %-14s refused: %s\n' "$n" "$(echo "$out" | sed -n 's/.*error: //p;' | head -1 | cut -c1-70)"; fi; rm -rf "$work/c/$n"; }
  c RGeNeg   'type T = int where value >= -5'
  c RBoth    'type T = int where value >= -5 and value <= 5'
  c ROrNeg   'type T = int where value >= 1 or value <= -1'
  c RFlip    'type T = int where -5 <= value'
  c RParen   'type T = int where value >= (-5)'
  c RSum     'type T = int where value >= 2 + 3'
  c RSumNeg  'type T = int where value >= 2 - 8'
  c RProd    'type T = int where value >= 2 * 3'
  c RNegNeg  'type T = int where value >= - -5'
  c RDiv     'type T = int where value >= 6 / 2'
  c RFloat   'type T = float where value >= -5.0'
  c RVar     'public int F(int n)
F(n) -> n
type T = int where value >= n'
  c GNeg 'public atom S(int n)
S(n) when n <= -1 -> :neg
S(n) when n >= 0 -> :nonneg'
  c GSum 'public atom S(int n)
S(n) when n <= 2 + 3 -> :lo
S(n) when n >= 6 -> :hi'
  c RetNeg 'type NonPos = int where value <= 0
public NonPos F()
F() -> -5'
  c DeltaOk 'type Delta = int where value >= -100 and value <= 100
public Delta F(Delta d)
F(d) -> d
public Delta G()
G() -> F(-3)'
  c DeltaBad 'type Delta = int where value >= -100 and value <= 100
public Delta F(Delta d)
F(d) -> d
public Delta G()
G() -> F(-300)'
  c DeltaLoseNeg 'type Delta = int where value >= -100 and value <= 100
public atom S(Delta d)
S(>= 1) -> :pos
S(0) -> :zero' 
}
for v in base A B C; do echo "== $v =="; cases "$work/$v/compiler/_build/default/bin/bsc"; done
echo "== residual text for a signed bounded domain: Delta = -100..100 with clauses S(>= 1), S(0) =="
for v in base A B C; do echo "-- $v"; mkdir -p "$work/r/$v/R"; printf 'module R\ntype Delta = int where value >= -100 and value <= 100\npublic atom S(Delta d)\nS(>= 1) -> :pos\nS(0) -> :zero\n' > "$work/r/$v/R/a.bs"; (cd "$work" && "$work/$v/compiler/_build/default/bin/bsc" "$work/r/$v/R/a.bs") 2>&1 | sed "s#$work/r/$v/##" | head -6; done
echo "== same residual, then the clause the residual says to add (S(<= -1) -> ...) =="
for v in A; do mkdir -p "$work/r2/$v/R"; printf 'module R\ntype Delta = int where value >= -100 and value <= 100\npublic atom S(Delta d)\nS(>= 1) -> :pos\nS(0) -> :zero\nS(<= -1) -> :neg\n' > "$work/r2/$v/R/a.bs"; (cd "$work" && "$work/$v/compiler/_build/default/bin/bsc" "$work/r2/$v/R/a.bs") 2>&1 | head -3; echo "(empty line above = accepted)"; done
echo "== emitted Code chunk for bodies using -5: base vs A (same md5 = same machine code) =="
for v in base A; do mkdir -p "$work/e/$v/E"; printf 'module E\npublic int F()\nF() -> -5\npublic int G(int n)\nG(n) -> n + -5\n' > "$work/e/$v/E/a.bs"
  (cd "$work/e/$v" && "$work/$v/compiler/_build/default/bin/bsc" -o "$work/e/$v/out" "$work/e/$v/E" 2>&1 | head -3); f=$(find "$work/e/$v/out" -name '*.beam' | head -1)
  echo "$v: $(wc -c < "$f") bytes, code-md5=$(cd "$work" && erl -noshell -eval '{ok,{_,[{_,C}]}}=beam_lib:chunks("'"$f"'",["Code"]),io:format("~s~n",[binary:encode_hex(crypto:hash(md5,C))]),halt().')"; done
