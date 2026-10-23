#!/usr/bin/env bash
# PROBE 64a — which return types does the checker refuse today, and with what words?
# Ticket 64 Open Q2/Q3. Each row writes a one-function module and asks `bsc --api`.
# CONTROLS (must compile): option<int>, result<int,binary>, tagged hand-rolled shapes.
# TREATMENT (collapse): anything where a member is a subset of the others.
# SCOPE: every row below asks `bsc --api`, i.e. whether the DECLARATION is accepted. The placeholder body `:nothing` is
# wrong for most declared types and would fail a full compile, so 'accepted' is not 'a program that runs'. The final section
# ('full compile') gives correct bodies for the rows the brief relies on and compiles AND runs them.
# Usage: source env.sh; ./64a_refusal_matrix.sh
set -uo pipefail
: "${BSC:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
row() { # id, return-type, extra-decl
  mkdir -p "$W/$1"
  { printf 'module %s\n\n' "$1"
    [ -n "$3" ] && printf '%s\n\n' "$3"
    printf 'public %s Go(int id)\n' "$2"
    printf 'Go(id) -> :nothing\n'
  } > "$W/$1/$1.bs"
  out="$("$BSC" --api "$W/$1/$1.bs" 2>&1 | tr '\n' ' ' | sed 's/  */ /g')"
  printf '%-4s %-40s => %s\n' "$1" "$2" "${out:0:260}"
}
echo "== controls (declaration must be ACCEPTED by --api; bodies are placeholders) =="
row C1 'option<int>'                       ''
row C2 'option<binary>'                    ''
row C3 'result<int, binary>'               ''
row C4 'result<int, atom>'                 ''
row C5 'F'                                 'type F = (:ok, term) | :absent'
row C6 'P'                                 'type P = (:some, term) | :nothing'
echo "== option side =="
row O1 'option<atom>'                      ''
row O2 'option<term>'                      ''
row O3 'option<option<int>>'               ''
row O4 'option<(:ok, int)>'                ''
echo "== result side (open Q3) =="
row R1 'result<term, binary>'              ''
row R2 'result<term, atom>'                ''
row R3 'result<int, term>'                 ''
row R4 'result<atom, binary>'              ''
row R5 'result<int, (:error, term)>'       ''
echo "== a user union spelled by hand =="
row U1 'R'                                 'type R = int | (:error, term)'
row U2 'R'                                 'type R = term | (:error, atom)'
echo "== the ticket-48 shape: a lookup over map<string, term> =="
row M1 'option<term>'                      ''
row M2 'F'                                 'type F = (:ok, term) | :absent'
echo "== other declaration positions (where the refusal reaches) =="
src() { # id, full module body after the module line
  mkdir -p "$W/$1"
  { printf 'module %s\n\n%s\n' "$1" "$2"; } > "$W/$1/$1.bs"
  out="$("$BSC" --api "$W/$1/$1.bs" 2>&1 | tr '\n' ' ' | sed 's/  */ /g')"
  printf '%-4s %-40s => %s\n' "$1" "$3" "${out:0:200}"
}
src P1 $'public int Go(option<term> x)\nGo(x) -> 1'                              'param option<term>'
src F1 $'record Row { Note: option<term> }\n\npublic int Go(int i)\nGo(i) -> 1' 'record field Note: option<term>'
src F2 $'record Row { Note: option<int> }\n\npublic int Go(int i)\nGo(i) -> 1' 'record field Note: option<int> (control)'
src L1 $'public list<option<term>> Go(int i)\nGo(i) -> []'                         'list<option<term>>'
src K1 $'public map<string, option<term>> Go(int i)\nGo(i) -> Map.FromList([])'     'map<string, option<term>>'
src K2 $'public map<string, term> Go(int i)\nGo(i) -> Map.FromList([])'             'map<string, term>  (control: the map itself)'
echo "== the repair the diagnostic itself suggests for result: narrow the success type =="
row N1 'result<int | binary, atom>'        ''
row N2 'result<atom | int, binary>'        ''
row N3 'result<list<term>, binary>'        ''
row N4 'result<map<string, term>, binary>' ''
row N5 'option<list<term>>'                ''
row N6 'option<map<string, term>>'         ''
row N7 'option<(int, term)>'               ''
row N8 'option<(:ok, term)>'               ''
echo "== open Q3, completed: result<T,E> is refused when T CONTAINS (:error, E), not when E is term =="
row Q1 'result<(atom, term), atom>'        ''
row Q2 'result<(int, term), atom>'         ''
row Q3 'result<(atom, binary), binary>'    ''
row Q4 'result<(atom, binary), atom>'      ''
echo "== full compile + run, correct bodies (declaration accepted AND program runs) =="
full() { # id, return-type, body-expr, expected-output
  mkdir -p "$W/$1"; printf 'module %s\n\npublic %s Go(int id)\nGo(id) -> %s\n' "$1" "$2" "$3" > "$W/$1/$1.bs"
  out="$("$BSC" "$W/$1/$1.bs" Go 1 2>&1 | tail -1)"
  [ "$out" = "$4" ] && v=OK || v="MISMATCH (wanted $4)"
  printf '%-4s %-34s Go(1) = %-22s %s\n' "$1" "$2" "$out" "$v"
}
full X1 'result<int, term>'            '(:error, :boom)'           '(:error, :boom)'
full X2 'result<list<term>, binary>'   '[:nothing, :error]'        '[:nothing, :error]'
full X3 'option<map<string, term>>'    ':nothing'                  ':nothing'
full X4 'option<int>'                  '7'                         '7'
full X5 'result<(int, term), atom>'    '(1, :nothing)'             '(1, :nothing)'
