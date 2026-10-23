#!/usr/bin/env bash
# PROBE 65a — what does the compiler reserve TODAY, and what does it leave free?
#
# Ticket 65 (ENG-255) opens with "B# reserves no name today." Tickets 67 (2026-09-03)
# and 96 (2026-09-25) and features F32/F62/F75 landed since. This probe asks the
# compiler, not the ticket. Every case is a real program through $BSC; the output
# line is the compiler's own first line plus the exit status. Controls sit beside
# every refusal: a name of the same SHAPE that is NOT reserved, so a compiler that
# refused everything would fail the control rows.
#
#   source env.sh; bash artifacts/probes/65/65a_what_is_reserved_today.sh
set -uo pipefail
: "${BSC:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
n=0
# case LABEL EXPECT-WORD DIR-PATH FILE-NAME  <<< source   (runs Go 1)
case_() {
  local label="$1" path="$2" file="$3" src; src="$(cat)"
  n=$((n+1)); local root="$W/c$n"; mkdir -p "$root/$path"
  printf '%s\n' "$src" > "$root/$path/$file.bs"
  local out rc
  out="$("$BSC" --src-root "$root" "$root/$path" Go 1 2>&1)"; rc=$?
  printf '%-46s rc=%s  %s\n' "$label" "$rc" "$(printf '%s' "$out" | head -1 | sed "s#$root/##")"
}
echo "--- A. module names (declaration site) ---"
for m in List Map Term Float Enumerable; do
  case_ "module $m (reserved?)" "$m" "$m" <<<"module $m

public int Go(int n)
Go(n) -> n"
done
echo "--- A-controls. same shape, not reserved ---"
for m in String Enum Int Process GenServer Supervisor Logger Shop; do
  case_ "module $m" "$m" "$m" <<<"module $m

public int Go(int n)
Go(n) -> n"
done
echo "--- A-segment. 67 Q6: only the WHOLE name is burned ---"
case_ "module Shop.List"  "Shop/List"  "List"  <<<"module Shop.List

public int Go(int n)
Go(n) -> n"
case_ "module List.Shop"  "List/Shop"  "Shop"  <<<"module List.Shop

public int Go(int n)
Go(n) -> n"
echo "--- B. other declaration kinds named like a qualifier ---"
case_ "type List = int"          T T <<<"module T

type List = int
public int Go(int n)
Go(n) -> n"
case_ "type Map = int"           T T <<<"module T

type Map = int
public int Go(int n)
Go(n) -> n"
case_ "record Map { X: int }"    T T <<<"module T

record Map { X: int }
public int Go(int n)
Go(n) -> n"
case_ "record Widget { X: int } (control)" T T <<<"module T

record Widget { X: int }
public int Go(int n)
Go(n) -> n"
case_ "public int List(int n)"   T T <<<"module T

public int List(int n)
List(n) -> n
public int Go(int n)
Go(n) -> List(n)"
case_ "public int Map(int n)"    T T <<<"module T

public int Map(int n)
Map(n) -> n
public int Go(int n)
Go(n) -> Map(n)"
echo "--- B2. a declaration named like a qualifier, USED beside the qualifier: which does each spelling reach? ---"
case_ "record Map + pattern head Map m + Map.Size" T T <<<"module T

record Map { X: int }
public int Pick(Map m)
Pick(Map m) -> m.X
public int Go(int n)
Go(n) -> Pick(Map{ X = n }) + Map.Size(Map.FromList([(1, n)]))"
case_ "fn List(n)=n+100 ; List.Length([n,n]) + List(n)" T T <<<"module T

public int List(int n)
List(n) -> n + 100
public int Go(int n)
Go(n) -> List.Length([n, n]) + List(n)"
echo "--- D. the lexical case class: builtin names are lowercase, user names are PascalCase (bs_lexer.xrl header) ---"
case_ "type option = int"           T T <<<"module T

type option = int
public int Go(int n)
Go(n) -> n"
case_ "record list { X: int }"      T T <<<"module T

record list { X: int }
public int Go(int n)
Go(n) -> n"
case_ "public int map(int n)"       T T <<<"module T

public int map(int n)
map(n) -> n
public int Go(int n)
Go(n) -> n"
case_ "type Option = int (control)" T T <<<"module T

type Option = int
public int Go(int n)
Go(n) -> n"
case_ "module list" list list <<<"module list

public int Go(int n)
Go(n) -> n"
echo "--- C. a call through the qualifier when a user module also claims it (F32 clause 3) ---"
n=$((n+1)); root="$W/c$n"; mkdir -p "$root/Shop/Text/String" "$root/Shop/Coll/List" "$root/R" "$root/S"
printf 'module Shop.Coll.List\n\npublic int Length(list<int> xs)\nLength(xs) -> 99\n' > "$root/Shop/Coll/List/List.bs"
printf 'module Shop.Text.String\n\npublic int Length(int s)\nLength(s) -> 98\n' > "$root/Shop/Text/String/String.bs"
printf 'module R\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Length([n])\n' > "$root/R/R.bs"
printf 'module S\n\nusing Shop.Text\n\npublic int Go(int n)\nGo(n) -> String.Length(n)\n' > "$root/S/S.bs"
for p in R S; do
  out="$("$BSC" --src-root "$root" "$root/$p" Go 1 2>&1)"; rc=$?
  printf '%-46s rc=%s  %s\n' "using ns + $([ $p = R ] && echo List.Length || echo String.Length)" "$rc" "$(printf '%s' "$out" | head -2 | tr '\n' '|' | sed "s#$root/##g")"
done
