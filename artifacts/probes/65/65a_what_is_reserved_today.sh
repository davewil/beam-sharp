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
n=0; PASS=0; FAIL=0; MARK=""
# check WANT GOT — sets MARK and the tally; a probe that only prints cannot fail
check() { if [ "$1" = "$2" ]; then PASS=$((PASS+1)); MARK="[ok]"; else FAIL=$((FAIL+1)); MARK="[MISMATCH want rc=$1]"; fi; }
# case LABEL EXPECT-WORD DIR-PATH FILE-NAME  <<< source   (runs Go 1)
case_() {
  local label="$1" path="$2" file="$3" src; src="$(cat)"
  n=$((n+1)); local root="$W/c$n"; mkdir -p "$root/$path"
  printf '%s\n' "$src" > "$root/$path/$file.bs"
  local out rc
  out="$("$BSC" --src-root "$root" "$root/$path" Go 1 2>&1)"; rc=$?
  local want=0
  case "$label" in *"(reserved?)"*|"type ValidationError"*|"type Down"*|"type Exit"*|"public int ToExistingAtom"*|"type option"*|"record list"*|"public int map"*|"module list"*) want=1;; esac
  check "$want" "$rc"
  printf '%-46s rc=%s %s %s\n' "$label" "$rc" "$MARK" "$(printf '%s' "$out" | head -1 | sed "s#$root/##")"
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
echo "--- E. compiler-known TYPES and FUNCTIONS: user-loses already exists outside the qualifier set (bs_check.erl:1372 stratum_two, :1832, :3486) ---"
for t in ValidationError Down Exit; do
  case_ "type $t = int"             T T <<<"module T

type $t = int
public int Go(int n)
Go(n) -> n"
done
case_ "type Foo = int (control)"   T T <<<"module T

type Foo = int
public int Go(int n)
Go(n) -> n"
case_ "public int ToExistingAtom(int n)"  T T <<<"module T

public int ToExistingAtom(int n)
ToExistingAtom(n) -> n
public int Go(int n)
Go(n) -> n"
for f in ValidateAs Raise ToJson FromJson Frobnicate; do
  case_ "public int $f(int n) ($([ $f = Frobnicate ] && echo control || echo other obligation names))"  T T <<<"module T

public int $f(int n)
$f(n) -> n
public int Go(int n)
Go(n) -> n"
done
echo "--- F. module names that shadow OTP / Erlang modules (ticket 87:166-170, F54:171, F55:172-174 hand these to 65) ---"
for m in Lists Maps Erlang Peer Json; do
  case_ "module $m (accepted = nothing stops it)"  "$m" "$m" <<<"module $m

public int Go(int n)
Go(n) -> n"
done
echo "   (the emitted beam is named $(printf 'Peer.beam') — on a case-INsensitive disk it shadows OTP's peer.beam; that failure (ENG-391 / F54:171) cannot be reproduced on this case-sensitive Linux fs, so it is cited, not run)"
echo "--- G. 'not' is a legal identifier (F27:40-46, LANGUAGE.md:334, ticket 63:406 hand it to 65) ---"
case_ "F(not) when not > 100 -> :big" T T <<<"module T

public atom Go(int not)
Go(not) when not > 100 -> :big
Go(not) -> :small"
echo "--- C. a call through the qualifier when a user module also claims it (F32 clause 3) ---"
n=$((n+1)); root="$W/c$n"; mkdir -p "$root/Shop/Text/String" "$root/Shop/Coll/List" "$root/R" "$root/S"
printf 'module Shop.Coll.List\n\npublic int Length(list<int> xs)\nLength(xs) -> 99\n' > "$root/Shop/Coll/List/List.bs"
printf 'module Shop.Text.String\n\npublic int Length(int s)\nLength(s) -> 98\n' > "$root/Shop/Text/String/String.bs"
printf 'module R\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Length([n])\n' > "$root/R/R.bs"
printf 'module S\n\nusing Shop.Text\n\npublic int Go(int n)\nGo(n) -> String.Length(n)\n' > "$root/S/S.bs"
for p in R S; do
  out="$("$BSC" --src-root "$root" "$root/$p" Go 1 2>&1)"; rc=$?
  check "$([ $p = R ] && echo 1 || echo 0)" "$rc"
  printf '%-46s rc=%s %s %s\n' "using ns + $([ $p = R ] && echo List.Length || echo String.Length)" "$rc" "$MARK" "$(printf '%s' "$out" | head -2 | tr '\n' '|' | sed "s#$root/##g")"
done
echo "--- tally: $PASS as expected, $FAIL mismatched"
[ "$FAIL" = 0 ]
