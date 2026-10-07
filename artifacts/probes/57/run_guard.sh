#!/usr/bin/env bash
# Does a guard with a negative literal credit coverage? Compare `when n >= -5` against `when n >= 5`.
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W"
try() { # name body
  mkdir -p "$W/$1"; printf 'module %s\n\npublic atom F(int n)\n\n%s\n' "$1" "$2" > "$W/$1/$(echo $1|tr A-Z a-z).bs"
  echo "== $1:"; echo "$2" | sed 's/^/   /'; "$BSC" "$W/$1" 2>&1 | head -12 | sed 's/^/   > /'; echo "   rc=${PIPESTATUS[0]}"; }
try Pos 'F(n) when n >= 5 -> :hi
F(n) when n < 5  -> :lo'
try Neg 'F(n) when n >= -5 -> :hi
F(n) when n < -5  -> :lo'
try NegRun 'F(n) when n >= -5 -> :hi
F(n) when n < -5  -> :lo
F(_) -> :x'
try PatNeg 'F(<= -1) -> :neg
F(0) -> :zero
F(>= 1) -> :pos'
