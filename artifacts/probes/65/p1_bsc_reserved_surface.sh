#!/bin/sh
# 65 / probe 1 — what does bsc reserve TODAY, at which positions, and what does it let through?
# One tiny module per case, compiled with --api (declaration-level rules) so bodies do not interfere.
set -u
BSC=${BSC:?set BSC}; W=${PROBE_TMP:-$(mktemp -d)}
case_() { # id  dirname  module-line  body
  mkdir -p "$W/$2"; printf '%s\n\n%s\n' "$3" "$4" > "$W/$2/m.bs"
  out=$("$BSC" --src-root "$W" --api "$W/$2" 2>&1); first=$(printf '%s' "$out" | head -1 | sed "s|$W/||")
  printf '%-4s %-46s -> %s\n' "$1" "$(printf '%s' "$3 $4" | tr '\n' ' ' | cut -c1-46)" "$(printf '%s' "$first" | cut -c1-120)"
}
echo '## reserved qualifiers as a module name (bare vs dotted)'
case_ A1 Map     'module Map'                  'public int Go(int x)
Go(x) -> x'
case_ A2 List    'module List'                 'public int Go(int x)
Go(x) -> x'
case_ A3 Term    'module Term'                 'public int Go(int x)
Go(x) -> x'
case_ A4 Shop/Collections/List 'module Shop.Collections.List' 'public int Go(int x)
Go(x) -> x'
echo '## names the standard environment has NOT reserved (but ticket 96 plans to qualify)'
for n in String Int Process GenServer Supervisor Logger Json; do
case_ B_$n "$n" "module $n" 'public int Go(int x)
Go(x) -> x'; done
echo '## other positions: a user TYPE or RECORD, FUNCTION, or generic named like a prelude/reserved word'
case_ C1 TypeOption 'module TypeOption' 'type option<T> = T | :none
public int Go(int x)
Go(x) -> x'
case_ C2 TypeMap    'module TypeMap'    'record Map { Id: int }
public int Go(int x)
Go(x) -> x'
case_ C3 TypeTerm   'module TypeTerm'   'type term = int
public int Go(int x)
Go(x) -> x'
case_ C4 FnList     'module FnList'     'public int List(int x)
List(x) -> x'
case_ C5 FnRaise    'module FnRaise'    'public int Raise(int x)
Raise(x) -> x'
case_ C6 FnMapGet   'module FnMapGet'   'public int Map(int x)
Map(x) -> x'
case_ C7 TypeExit   'module TypeExit'   'record Exit { Id: int }
public int Go(int x)
Go(x) -> x'
case_ C8 TypeDown   'module TypeDown'   'type Down = int
public int Go(int x)
Go(x) -> x'
echo '## the compiler-owned export prefix (ticket 87): can an author spell `bs@type_atoms`?'
case_ D1 AtName 'module AtName' 'public int bs@type_atoms(int x)
bs@type_atoms(x) -> x'
case_ D2 CapName 'module CapName' 'public int Bs(int x)
Bs(x) -> x'
echo '## a module whose dotted path starts with a root another BEAM language owns (flat atom namespace)'
mkdir -p "$W/Elixir/Enum"
printf 'module Elixir.Enum\n\npublic int Go(int x)\nGo(x) -> x\n' > "$W/Elixir/Enum/m.bs"
printf 'E1   module Elixir.Enum -> '; "$BSC" --src-root "$W" -o "$W/out" "$W/Elixir/Enum" 2>&1 | head -2 | tr '\n' ' '; echo; ls "$W/out" 2>/dev/null | tr '\n' ' '; echo
