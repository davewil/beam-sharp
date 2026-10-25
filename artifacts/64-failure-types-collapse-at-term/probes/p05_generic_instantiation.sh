#!/usr/bin/env bash
# P05: a user-written generic lookup returning option<V>: is the collapse caught at the declaration (generic) or at the instantiation V=term?
. "$(dirname "$0")/lib.sh"
mk GenOpt <<'SRC'
module GenOpt

private option<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> v
Find([_, ..rest], k) -> Find(rest, k)

public option<int> AtInt(list<(atom, int)> xs)
AtInt(xs) -> Find(xs, :a)

public int Run()
Run() -> AtInt([(:a, 7)]) switch { :nothing => 0, n => n }
SRC
echo "=== generic option<V> used at V=int"; $BSC "$W/GenOpt" Run 2>&1 | head -8
mk GenOptTerm <<'SRC'
module GenOptTerm

private option<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> v
Find([_, ..rest], k) -> Find(rest, k)

public option<term> AtTerm(list<(atom, term)> xs)
AtTerm(xs) -> Find(xs, :a)
SRC
echo "=== same generic used at V=term (return written option<term>)"; $BSC "$W/GenOptTerm" 2>&1 | head -8
mk GenOptTerm2 <<'SRC'
module GenOptTerm2

private option<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> v
Find([_, ..rest], k) -> Find(rest, k)

public term AtTerm(list<(atom, term)> xs)
AtTerm(xs) -> Find(xs, :a)
SRC
echo "=== same generic, caller declares bare term (instantiation V=term not written as option)"; $BSC "$W/GenOptTerm2" AtTerm "[(:a, 5)]" 2>&1 | head -8
echo "=== ... and with the key absent, the caller sees:"; $BSC "$W/GenOptTerm2" AtTerm "[(:b, 5)]" 2>&1 | head -8
echo "=== a STORED :nothing is indistinguishable from absent (the actual harm):"; $BSC "$W/GenOptTerm2" AtTerm "[(:a, :nothing)]" 2>&1 | head -3
echo "=== --api of the caller:"; $BSC "$W/GenOptTerm2" --api 2>&1 | head -4
