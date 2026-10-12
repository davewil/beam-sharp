#!/usr/bin/env bash
# 57-08 does variant A (parser folds integer literal `-N`) change the verdict on any shipped example?
# Compile every compiler/examples/* module with baseline bsc and with A; diff stdout+exit.
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd); p4="$here/../57-04"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir -p "$work/A/compiler"; (cd "$root/compiler" && tar cf - --exclude=_build --exclude='*.beam' .) | (cd "$work/A/compiler" && tar xf -)
(cd "$work/A" && patch -s -p1 < "$p4/A-parser-fold.patch"); (cd "$work/A/compiler" && rebar3 escriptize >/dev/null 2>&1)
base="$root/compiler/_build/default/bin/bsc"; A="$work/A/compiler/_build/default/bin/bsc"
same=0; diff_=0; neg=0
for d in "$root"/compiler/examples/*/; do n=$(basename "$d"); [ "$n" = exemplars ] && continue
  for v in base A; do b=$base; [ $v = A ] && b=$A; mkdir -p "$work/o$v"; r=$(cd "$work/o$v" && "$b" --src-root "$root/compiler/examples" "$d" 2>&1; echo "exit=$?"); echo "$r" > "$work/$n.$v"; done
  if cmp -s "$work/$n.base" "$work/$n.A"; then same=$((same+1)); else diff_=$((diff_+1)); echo "DIFFERS: $n"; diff "$work/$n.base" "$work/$n.A" | head -5; fi
  printf '  %-12s base: %s\n' "$n" "$(tail -1 "$work/$n.base")"
done
echo "examples with identical verdict/output: $same, different: $diff_"
echo "examples containing a negative integer literal expression:"; grep -rln '[(=,>] *-[0-9]' "$root"/compiler/examples --include=*.bs
echo "== runtime values of negative-literal expressions, base vs A (must be identical) =="
mkdir -p "$work/Neg"; cat > "$work/Neg/a.bs" <<'EOS'
module Neg
public int A()
A() -> -7 / 2
public int B()
B() -> -7 % 3
public int C()
C() -> -2 * 3
public int D()
D() -> - -4
public int E()
E() -> 10 - -5
public int F()
F() -> -(7) / 2
EOS
for fn in A B C D E F; do for v in base A; do b=$base; [ $v = A ] && b=$A; printf '%s %s: %s\n' "$fn" "$v" "$(cd "$work/o$v" && "$b" "$work/Neg" $fn 2>&1 | tr '\n' ' ')"; done; done
