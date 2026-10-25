#!/usr/bin/env bash
# P07: can a user spell a tagged option as a generic alias, or a generic record Some<T>? (candidate: option2<T> = (:some, T) | :nothing)
. "$(dirname "$0")/lib.sh"
mk Opt2 <<'SRC'
module Opt2

type maybe<T> = (:some, T) | :nothing

private maybe<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> (:some, v)
Find([_, ..rest], k) -> Find(rest, k)

public maybe<term> AtTerm(list<(atom, term)> xs)
AtTerm(xs) -> Find(xs, :a)

public atom Kind(list<(atom, term)> xs)
Kind(xs) -> AtTerm(xs) switch { (:some, :nothing) => :stored_nothing, (:some, v) => :present, :nothing => :absent }

public maybe<int> AtInt(list<(atom, int)> xs)
AtInt(xs) -> Find(xs, :a)
SRC
echo "--- (:some, T) | :nothing as a user alias, generic Find"; $BSC "$W/Opt2" --api 2>&1 | head
for a in '[(:a, 1)]' '[(:a, :nothing)]' '[(:b, 1)]'; do printf 'Kind %s -> ' "$a"; $BSC "$W/Opt2" Kind "$a" 2>&1 | tail -1; done
mk RecSome <<'SRC'
module RecSome

record Some<T> { Value: T }

type found<T> = Some<T> | :nothing

private found<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> Some{ Value = v }
Find([_, ..rest], k) -> Find(rest, k)

public atom Kind(list<(atom, term)> xs)
Kind(xs) -> Find(xs, :a) switch { Some{ Value: :nothing } => :stored_nothing, Some{ Value: v } => :present, :nothing => :absent }
SRC
echo "--- generic record Some<T>"; $BSC "$W/RecSome" --api 2>&1 | head -8
for a in '[(:a, 1)]' '[(:a, :nothing)]' '[(:b, 1)]'; do printf 'Kind %s -> ' "$a"; $BSC "$W/RecSome" Kind "$a" 2>&1 | tail -1; done
