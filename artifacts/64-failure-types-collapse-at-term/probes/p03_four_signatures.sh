#!/usr/bin/env bash
# P03 (FindR/FindT rows of the ticket's table are now REFUSED, see p01; an earlier draft of this file included FindR and the compiler refused the whole module, output not kept): the ticket's four-signature table off `bsc --api`, plus tuple-shape and nested controls.
. "$(dirname "$0")/lib.sh"
mk Four <<'SRC'
module Four

// hand-rolled tagged
public (:ok, term) | :absent FindF(list<(atom, term)> xs, atom k)
FindF([], k) -> :absent
FindF([(kk, v), ..rest], k) when kk == k -> (:ok, v)
FindF([_, ..rest], k) -> FindF(rest, k)

public option<int> FindI(list<(atom, int)> xs, atom k)
FindI([], k) -> :nothing
FindI([(kk, v), ..rest], k) when kk == k -> v
FindI([_, ..rest], k) -> FindI(rest, k)
SRC
$BSC "$W/Four" --api 2>&1 | head -20
echo "--- result<(atom, binary), binary> and option<option<int>> (F31's two non-atom-top cases)"
mk Nested <<'SRC'
module Nested
public option<option<int>> A(int k)
A(k) -> :nothing
SRC
$BSC "$W/Nested" --api 2>&1 | head -8
mk Tup <<'SRC'
module Tup
public result<(atom, binary), binary> A(int k)
A(k) -> (:error, "x")
SRC
$BSC "$W/Tup" --api 2>&1 | head -8
