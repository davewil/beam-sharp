#!/bin/bash
# Ticket 57 (ENG-239): a refinement cannot say -5, though a pattern can.
. "$(dirname "$0")/../env.sh"
work 57
mk() { mkdir -p $1; cat > $1/$1.bs; }

echo "### P1 repro: refinement with -5 (ticket says refused)"
mk A <<'B'
module A
type T = int where value >= -5
public int F(T t)
F(t) -> t
B
bsc --src-root . A 2>&1 | head -2

echo "### P2 same literal, same operator, as a pattern (ticket says compiles)"
mk B <<'B'
module B
public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos
B
bsc --src-root . B Sign -7 2>&1 | head -2

echo "### P3 the same comparison as a GUARD (does the guard path read -5?)"
mk C <<'B'
module C
public int G(int n)
G(n) when n >= -5 -> n
G(n) -> 0
B
bsc --src-root . C G -3 2>&1 | head -3

echo "### P4 guard vs refinement on 2 + 3 (is the split only about negation?)"
mk D <<'B'
module D
public int G(int n)
G(n) when n >= 2 + 3 -> n
G(n) -> 0
B
bsc --src-root . D G 9 2>&1 | head -3
mk E <<'B'
module E
type T = int where value >= 2 + 3
public int F(T t)
F(t) -> t
B
bsc --src-root . E 2>&1 | head -1

echo "### P5 other spellings of a negative bound in a refinement"
for spell in '(-5)' '0 - 5' '-(5)' '- 5'; do
  mk S <<B
module S
type T = int where value >= $spell
public int F(T t)
F(t) -> t
B
  printf '%-8s -> ' "$spell"; bsc --src-root . S 2>&1 | head -1 | cut -c1-70; echo
done

echo "### P6 does the GUARD path read -5? Exhaustiveness is the witness: two guards that cover int."
mk G <<'B'
module G
public atom H(int n)
H(n) when n >= 5 -> :hi
H(n) when n < 5 -> :lo
B
echo "  with 5:"; bsc --src-root . G H 0 2>&1 | head -3
mk G <<'B'
module G
public atom H(int n)
H(n) when n >= -5 -> :hi
H(n) when n < -5 -> :lo
B
echo "  with -5:"; bsc --src-root . G H 0 2>&1 | head -6

echo "### P7 what the parser hands the checker for -5 (term shape)"
erl -noshell -pa $S/c/ebin -eval '
{ok,T,_}=bs_lexer:string("module M\ntype T = int where value >= -5\n"),
R=bs_parser:parse(T), io:format("~p~n",[R]), halt().' 2>&1 | head -12

echo "### P8 Erlang: how the real compiler treats -5 (guard + pattern), parse form then core"
cat > e57.erl <<'B'
-module(e57).
-export([g/1, p/1]).
g(N) when N >= -5 -> ok; g(_) -> no.
p(-5) -> a; p(_) -> b.
B
erl -noshell -eval '
{ok,T,_}=erl_scan:string("X >= -5."), {ok,[E]}=erl_parse:parse_exprs(T), io:format("parse: ~p~n",[E]),
{ok,T2,_}=erl_scan:string("f(-5) -> a."), {ok,F}=erl_parse:parse_form(T2), io:format("pattern parse: ~p~n",[F]),
halt().'
erlc +to_core e57.erl && grep -n -- '-5' e57.core | head -4
erlc -S e57.erl && grep -n 'is_ge\|gc_bif.*-\|{integer,-5}\|-5' e57.S | head -6
