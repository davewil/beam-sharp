#!/usr/bin/env bash
#
# F61 / ENG-409 — `ValidateAs<T>` READS AN ABSENT KEY AT AN `option<T>` FIELD
# AS `:nothing`, AT EVERY DEPTH, AND NOWHERE ELSE.
#
# Ticket 26 §4 decided that a record has no absent fields and that the boundary
# turns an absent key into `:nothing`; ticket 78 Q8 extended it to wire types
# and kept JSON `null` apart. Each case is run, and its printed value compared
# whole: an accept asserted as an absence would pass a program that stopped
# compiling for an unrelated reason.
#
#   V1  a field set with its option key absent — filled.
#   V2  a record inside a record inside a list, the inner key absent — filled
#       at depth. Red under `top_only`, the fix that fills where the validator
#       starts and hands back its children's input unchanged.
#   V3  `null` at an `option<string>` — refused at its key. Red under
#       `null_as_absent`.
#   V4  an absent `atom` field — refused. `atom` contains `:nothing` only by
#       absorption, so no `option` was written. Red under `subtype_fill`, the
#       fix that asks "is `:nothing` a subtype of the field" instead.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

CASES="V1 V2 V3 V4"

input() {
  case "$1" in
    V1) echo '{ Model = "m" }' ;;
    V2) echo "[{ Kind = :'V2.Outer', Inner = { Kind = :'V2.R', Model = \"m\" } }]" ;;
    V3) echo '{ Id = :null, Model = "m" }' ;;
    V4) echo '{ Model = "m" }' ;;
  esac
}

# Copied from `bsc`'s output on the correct build, 2026-09-25.
expected_value() {
  case "$1" in
    V1) echo '{Id = :nothing, Model = "m"}' ;;
    V2) echo "[{Kind = :'V2.Outer', Inner = {Kind = :'V2.R', Id = :nothing, Model = \"m\"}}]" ;;
    V3) echo "(:error, {Kind = :'ValidationError', Expected = \":nothing | string\", Path = [\".Id\"]})" ;;
    V4) echo "(:error, {Kind = :'ValidationError', Expected = \"{ Model: string, Tag: atom }\", Path = []})" ;;
  esac
}

# ---------------------------------------------------------------------------
# judge — the gate's whole opinion, driven by --self-test against fixtures.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" v out want
  for v in $CASES; do
    out="$(cat "$dir/$v.out")"
    want="$(expected_value "$v")"
    [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'"
  done
}

# ---------------------------------------------------------------------------
# probe — one module per case, each run on its input.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  emit() { # name, decls, target type
    local lower
    lower="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$dir/$1"
    { printf 'module %s\n\n%s\n\n' "$1" "$2"
      printf 'public result<%s, ValidationError> Decode(term t)\n' "$3"
      printf 'Decode(t) -> ValidateAs<%s>(t)\n' "$3"
    } > "$dir/$1/$lower.bs"
  }
  emit V1 'type W = { Id: option<string>, Model: string }' 'W'
  emit V2 $'record R { Id: option<string>, Model: string }\nrecord Outer { Inner: R }' \
       'list<Outer>'
  emit V3 'type W = { Id: option<string>, Model: string }' 'W'
  emit V4 'type W = { Tag: atom, Model: string }' 'W'
  (cd "$dir" &&
     for v in $CASES; do
       "$BSC" "$v" Decode "$(input "$v")" > "$v.out" 2>&1 || true
     done)
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form.
#
#   silent          nothing is filled: master before ENG-409
#   top_only        the top level is filled, a child's fill is dropped
#   null_as_absent  `null` is read as absent too
#   subtype_fill    any field `:nothing` inhabits is filled, `atom` too
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() { # name, then an output per case V1..V4
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in $CASES; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  G1="$(expected_value V1)"; G2="$(expected_value V2)"
  G3="$(expected_value V3)"; G4="$(expected_value V4)"
  # What master printed for V1 and V2, 2026-09-25.
  R1="(:error, {Kind = :'ValidationError', Expected = \"{ Id: :nothing | string, Model: string }\", Path = []})"
  R2="(:error, {Kind = :'ValidationError', Expected = \"{ Kind: :'V2.R', Id: :nothing | string, Model: string }\", Path = [\"[0]\", \".Inner\"]})"

  stub good           "$G1" "$G2" "$G3" "$G4"
  stub silent         "$R1" "$R2" "$G3" "$G4"
  stub top_only       "$G1" "$R2" "$G3" "$G4"
  stub null_as_absent "$G1" "$G2" "$G1" "$G4"
  stub subtype_fill   "$G1" "$G2" "$G3" '{Model = "m", Tag = :nothing}'

  for bad in silent top_only null_as_absent subtype_fill; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT set of outputs was rejected -"; judge "$W/good"; fail=1
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
echo "  ok         an absent option key is :nothing at depth; null and an absent atom field stay refused"
