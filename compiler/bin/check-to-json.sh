#!/usr/bin/env bash
#
# F50 / ticket 77 — `ToJson<T>` PUTS A VALUE ON THE WIRE, AND REFUSES AT THE
# DECLARATION WHAT THE PLATFORM WOULD REFUSE AT RUN TIME.
#
# THREE DEFECTS THIS GATE EXISTS FOR, AND EACH ONE COMPILES THE GOOD PROGRAM:
#
#   written_walk  the encodability walk reads the members as WRITTEN. `Slot` is
#                 `Pair | :empty` and `Pair` is `(int, int)`, so the tuple is two
#                 aliases down and a record field in; a walk that does not
#                 normalise accepts the module, and it crashes in `json:encode`
#                 on the first box with a slot.
#   check_only    the refusal is wired into a compile and not into `--api`. The
#                 obligation sits in a clause body, which the declaration pass
#                 never types, so `bsc --api` prints `string Outcome(...)` for a
#                 module a compile refuses (the ENG-371 class).
#   unguarded     the site encodes without the guard ticket 18 §1(c) owes it.
#                 A public `Order` parameter is guarded on its tag alone, so an
#                 undeclared field reaches the body and goes out on the wire.
#
# THE WIRE IS MATCHED BY FRAGMENT, NEVER AS A WHOLE STRING: `json:encode` writes
# a map's keys in the order the VM created their atoms, so the object's text is
# not a fact about the program.
#
#   P1  `OrderBody` on a good order — its three members are on the wire.
#   P2  `ParcelBody` with no note — `"Note":"nothing"`, key present.
#   P3  `OrderBody` on an order carrying `Secret` — crashes, and `Secret` is not
#       printed. Red under `unguarded`.
#   P4  compiling `Refused` — `result<Order, ValidationError>` is refused.
#   P5  compiling `Hidden` — the tuple behind the aliases is named, at its path.
#       Red under `written_walk`.
#   P6  `--api Refused` — status 1, nothing on stdout. Red under `check_only`.
# `broken` refuses everything, so an absence is never read as a pass.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

GOOD="{ Kind = :'Orders.Order', Id = 1, Total = 5 }"
LEAKY="{ Kind = :'Orders.Order', Id = 1, Total = 5, Secret = 7 }"
PARCEL="{ Kind = :'Orders.Parcel', Id = 1, Note = :nothing }"

REFUSED_LINE="error: Outcome calls ToJson over a type with no wire form"
HIDDEN_LINE='in [_].Slot, `(int, int)` is a tuple'

# ---------------------------------------------------------------------------
# judge — the gate's whole opinion, driven by --self-test against fixtures.
# `has` and `lacks` read a probe's output; P6 also reads its exit status.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  has()   { grep -qF -- "$2" "$dir/$1.out" || echo "$1: expected '$2', got '$(cat "$dir/$1.out")'"; }
  lacks() { if grep -qF -- "$2" "$dir/$1.out"; then echo "$1: '$2' must not appear, got '$(cat "$dir/$1.out")'"; fi; }
  has   P1 '"Kind":"Orders.Order"'
  has   P1 '"Id":1'
  has   P1 '"Total":5'
  has   P2 '"Note":"nothing"'
  has   P3 "crashed: to_json {Kind = :'ValidationError'"
  lacks P3 'Secret'
  has   P4 "$REFUSED_LINE"
  has   P5 "$HIDDEN_LINE"
  [ "$(cat "$dir/P6.rc")" = "1" ] || echo "P6: --api must exit 1, exited $(cat "$dir/P6.rc")"
  lacks P6 'Outcome('
}

# ---------------------------------------------------------------------------
# probe — ticket 77's program and two refused modules.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  mkdir -p "$dir/Orders" "$dir/Refused" "$dir/Hidden"
  cat > "$dir/Orders/orders.bs" <<'EOF'
module Orders

record Order  { Id: int, Total: int }
record Parcel { Id: int, Note: option<int> }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)

public string ParcelBody(Parcel p)
ParcelBody(p) -> ToJson<Parcel>(p)
EOF
  cat > "$dir/Refused/refused.bs" <<'EOF'
module Refused

record Order { Id: int, Total: int }

public string Outcome(result<Order, ValidationError> r)
Outcome(r) -> ToJson<result<Order, ValidationError>>(r)
EOF
  cat > "$dir/Hidden/hidden.bs" <<'EOF'
module Hidden

type Pair = (int, int)
type Slot = Pair | :empty
record Box { Id: int, Slot: Slot }

public string Boxes(list<Box> bs)
Boxes(bs) -> ToJson<list<Box>>(bs)
EOF
  (cd "$dir" &&
     { "$BSC" Orders OrderBody "$GOOD" > P1.out 2>&1 || true; } &&
     { "$BSC" Orders ParcelBody "$PARCEL" > P2.out 2>&1 || true; } &&
     { "$BSC" Orders OrderBody "$LEAKY" > P3.out 2>&1 || true; } &&
     { "$BSC" Refused > P4.out 2>&1 || true; } &&
     { "$BSC" Hidden > P5.out 2>&1 || true; })
  local rc=0
  (cd "$dir" && "$BSC" --src-root . --api Refused > P6.out 2>/dev/null) || rc=$?
  echo "$rc" > "$dir/P6.rc"
}

# ---------------------------------------------------------------------------
# --self-test — three defects, one compiler that refuses everything, and the
# correct form.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  ORDER='"{"Kind":"Orders.Order","Id":1,"Total":5}"'
  PARCELJ='"{"Kind":"Orders.Parcel","Id":1,"Note":"nothing"}"'
  # Both measured, not written to agree: the crash on the built tree, and what
  # `--api` printed for `Refused` before F50 wired the refusal into it.
  CRASH="crashed: to_json {Kind = :'ValidationError', Expected = \"{ Kind: :'Orders.Order', Id: int, Total: int }\", Path = []}"
  API="module Refused
string Outcome((:error, { Kind: :'ValidationError', Expected: string, Path: list<string> }) | { Kind: :'Refused.Order', Id: int, Total: int })"
  # What a compiler that does not know the name prints — measured on the tree
  # before F50, so the stub is a real output and not one written to agree.
  ANY_REFUSAL="Orders/orders.bs:7:17: error: OrderBody writes ToJson<...>, and ToJson is not a codegen obligation"

  stub() { # name, P1..P5 output, P6 output, P6 status
    local d="$W/$1"
    mkdir -p "$d"
    printf '%s' "$2" > "$d/P1.out"
    printf '%s' "$3" > "$d/P2.out"
    printf '%s' "$4" > "$d/P3.out"
    printf '%s' "$5" > "$d/P4.out"
    printf '%s' "$6" > "$d/P5.out"
    printf '%s' "$7" > "$d/P6.out"
    printf '%s' "$8" > "$d/P6.rc"
  }
  stub good         "$ORDER" "$PARCELJ" "$CRASH" "$REFUSED_LINE" "$HIDDEN_LINE" "" 1
  stub written_walk "$ORDER" "$PARCELJ" "$CRASH" "$REFUSED_LINE" ""             "" 1
  stub check_only   "$ORDER" "$PARCELJ" "$CRASH" "$REFUSED_LINE" "$HIDDEN_LINE" "$API" 0
  stub unguarded    "$ORDER" "$PARCELJ" '"{"Kind":"Orders.Order","Id":1,"Total":5,"Secret":7}"' \
                    "$REFUSED_LINE" "$HIDDEN_LINE" "" 1
  stub broken       "$ANY_REFUSAL" "$ANY_REFUSAL" "$ANY_REFUSAL" "$ANY_REFUSAL" "$ANY_REFUSAL" "" 1

  for bad in written_walk check_only unguarded broken; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT outputs were rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: four defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         the wire carries the record, refuses the result and the hidden tuple, and --api agrees"
