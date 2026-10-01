#!/usr/bin/env bash
# Verifier's own probes. Usage: BSC=<bsc> bash v6_new_probes.sh
set -u; BSC=${BSC:?}; here=$(cd "$(dirname "$0")" && pwd); . "$here/../lib.sh"
run() { # name source fn arg...   -> compile+run
  local n=$1 src=$2; shift 2; local d=$(mktemp -d)/$n; mkdir -p $d; printf 'module %s\n%s\n' "$n" "$src" > $d/a.bs
  printf '  %s(%s) -> ' "$1" "${*:2}"; "$BSC" $d/a.bs "$@" 2>&1 | head -2 | tr '\n' ' ' | cut -c1-160; echo; }
echo "== N1 minus-zero / bignum refinements"
try N1 'type T = int where value >= -0'
try N2 'type T = int where value >= -1000000000000000000000'
echo "== N3 union with negative: runtime boundaries"
S='type U = int where value >= -5 and value <= -2 or value == 100
public int Id(U u)
Id(u) -> u'
try N3 "$S"
for a in -6 -5 -2 -1 99 100; do run N3 "$S" Id $a; done
echo "== N4 negated forms"
try N4a 'type T = int where value >= -(2 + 3)'
try N4b 'type T = int where value >= - -5'
S='type T = int where value >= - -5
public int Id(T u)
Id(u) -> u'
for a in 4 5; do run N4c "$S" Id $a; done
echo "== N5 guards: exhaustive splits that MUST be accepted"
try G1 'public atom F(int n)
F(n) when -5 <= n -> :a
F(n) when -5 > n -> :b'
try G2 'public atom F(int n)
F(n) when n > -5 -> :a
F(n) when n <= -5 -> :b'
try G3 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < 5 -> :b'
echo "== N5 guards that MUST be refused (gap)"
try H1 'public atom F(int n)
F(n) when n > -5 -> :a
F(n) when n < -5 -> :b'
try H2 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < -6 -> :b'
try H3 'public atom F(int n)
F(n) when n >= 5 -> :a
F(n) when n < -5 -> :b'
try H4 'public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < -4 -> :b
F(n) when n == 7 -> :c'
echo "== N6 guard semantics at runtime"
S='public atom F(int n)
F(n) when n >= -5 -> :a
F(n) when n < -5 -> :b'
for a in -6 -5 0; do run N6 "$S" F $a; done
S='public atom F(int n)
F(n) when -5 > n -> :lo
F(n) when n >= -5 -> :hi'
for a in -6 -5 ; do run N6b "$S" F $a; done
echo "== N7 ordinary arithmetic with negative literals (does A's fold change codegen?)"
S='public int G(int n)
G(n) -> n - -5 + -3 * 2'
for a in 0 10; do run N7 "$S" G $a; done
S='public int H()
H() -> -2147483648 - 1'
run N7b "$S" H
S='public int K(int n)
K(-5) -> 1
K(n) -> 2'
for a in -5 5; do run N7c "$S" K $a; done
echo "== N8 literal singleton: pass a negative literal where a refinement is required"
S='type Neg = int where value <= -1
public int Take(Neg n)
Take(n) -> n
public int Go()
Go() -> Take(-3)
public int Bad()
Bad() -> Take(3)'
try N8 "$S"
S='type Pos = int where value >= 1
public int Take(Pos n)
Take(n) -> n
public int Go()
Go() -> Take(3)'
try N8b "$S"
echo "== N9 float in refinement/guard"
try N9 'public atom F(float x)
F(x) when x >= -5.0 -> :a
F(x) when x < -5.0 -> :b'
