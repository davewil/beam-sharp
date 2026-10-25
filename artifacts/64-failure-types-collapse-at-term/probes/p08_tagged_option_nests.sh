#!/usr/bin/env bash
# P08: does a TAGGED option survive at every T where bare option<T> is refused? (atom, term, option<int> nested, T containing :nothing)
. "$(dirname "$0")/lib.sh"
mk Nest <<'SRC'
module Nest
type Maybe<T> = (:some, T) | :nothing
public Maybe<atom> A(int k)
A(k) -> :nothing
public Maybe<term> B(int k)
B(k) -> (:some, :nothing)
public Maybe<Maybe<int>> C(int k)
C(k) -> (:some, :nothing)
public Maybe<(:some, int)> D(int k)
D(k) -> :nothing
SRC
$BSC "$W/Nest" --api 2>&1 | head
echo "--- bare option at the same T for control"
for t in 'atom' 'option<int>'; do n="B_$(echo $t | tr -c 'a-z\n' _)"; mk $n <<SRC
module $n
public option<$t> A(int k)
A(k) -> :nothing
SRC
$BSC "$W/$n" 2>&1 | head -2 | cut -c1-200 | sed "s#$W/##"; done
