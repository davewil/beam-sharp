#!/usr/bin/env bash
# 57_residual -- ticket claim: "subtract(-10..10, 0) is -10..-1 | 1..10 -- a residual the compiler
# prints and the surface cannot accept." Test: (a) what bsc really prints for a signed bounded
# domain, (b) whether pasting the printed heads back makes the program compile, on stock
# and on the grammar-fix build (needed only to NAME the domain -10..10 as a type).
# REFUTED (claim false) by: the pasted program compiling on stock for the pattern-position heads.
# CONFIRMED by: the printed head containing a negative bound that is refused when pasted.
# Also: the residual when a guard contains `-5` (guard unread -> residual is the whole domain).
# usage: 57_residual.sh [STOCK_BSC [FIXED_BSC]]
. "$(dirname "$0")/env.sh"; here=$(cd "$(dirname "$0")" && pwd)
stock=${1:-${V57:+$V57/stock/_build/default/bin/bsc}}; stock=${stock:-$BSC}
fixed=${2:-${V57:+$V57/gramA/_build/default/bin/bsc}}
mk () { local d; d=$(mktemp -d "${TMPDIR:-/tmp}/p57r.XXXXXX"); mkdir "$d/M"; printf 'module M\n%s\n' "$1" > "$d/M/a.bs"; echo "$d/M"; }
paste_back () {   # $1 bsc  $2 source ; prints the diag, then the result of pasting its heads
  local bsc=$1 src=$2 d out heads
  d=$(mk "$src"); out=$("$bsc" "$d" 2>&1) || true
  echo "$out" | sed 's#^[^ ]*/a.bs#a.bs#'
  heads=$(printf '%s\n' "$out" | grep -E '^    [A-Za-z]+\(.*\) -> \.\.\.$' | sed 's/ -> \.\.\.$/ -> :new/; s/^    //')
  if [ -z "$heads" ]; then echo "  (no pasteable heads in the diagnostic)"; return; fi
  d=$(mk "$src"$'\n'"$heads"); echo "  pasted:"; printf '%s\n' "$heads" | sed 's/^/    /'
  if out=$("$bsc" "$d" 2>&1) && [ -z "$out" ]; then echo "  -> pasted program: ACCEPTED"; else echo "  -> pasted program: REFUSED: $(echo "$out" | head -2 | tr '\n' ' ')"; fi
}
echo "## A. stock: bare int, signed bounded complement written with patterns (-10..10 is the gap)"
paste_back "$stock" $'public atom F(int n)\nF(<= -11) -> :n\nF(>= 11) -> :p\nF(0) -> :z'
echo; echo "## B. stock: the same domain as a TYPE (what the ticket wants to be able to write)"
paste_back "$stock" $'type D = int where value >= -10 and value <= 10\npublic atom F(D d)\nF(0) -> :z'
echo; echo "## C. stock: a guard containing -5 (unread guard credits nothing)"
paste_back "$stock" $'public atom F(int n)\nF(n) when n >= -5 -> :a\nF(n) when n < -5 -> :b'
echo; echo "## D. stock control: the same guards with 0 instead of -5"
paste_back "$stock" $'public atom F(int n)\nF(n) when n >= 0 -> :a'
if [ -n "$fixed" ]; then
 echo; echo "## E. grammar-fix build: D = -10..10, only 0 handled -> residual, then paste"
 paste_back "$fixed" $'type D = int where value >= -10 and value <= 10\npublic atom F(D d)\nF(0) -> :z'
 echo; echo "## F. grammar-fix build: D = -10..10, F(<= -1) and F(>= 2) handled -> residual 0..1"
 paste_back "$fixed" $'type D = int where value >= -10 and value <= 10\npublic atom F(D d)\nF(<= -1) -> :n\nF(>= 2) -> :p'
fi
echo; echo "## G. the algebra itself (bs_types), independent of any printer"
"$here/57_algebra.escript" "${V57:-}" 2>&1
