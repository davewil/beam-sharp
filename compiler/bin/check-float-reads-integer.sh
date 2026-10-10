#!/usr/bin/env bash
#
# F73 / ENG-616 — UNDER FromJson, A FLOAT POSITION READS A JSON INTEGER.
#
# Ticket 78 Q18. Each case is run, and what `bsc` prints is compared whole:
# `1` and `1.0` differ by two characters, and a refusal asserted as "not the
# value" would pass a program that stopped compiling.
#
#   R1  a `float` field given `1`: the float `1.0`. Red under `refused`,
#       which is the compiler before F73, and under `unconverted`, which
#       accepts the integer and hands it back as one.
#   R2  `FromJson<float>` given `7`: `7.0`. Red under `refused`, and under
#       `fields_only`, which converts under a key and not at the top.
#   R3  a list element, a map value and a union member, each given an
#       integer: each a float. Red under `refused`, and under `shallow`,
#       which converts a field of the type asked for and nothing beneath it.
#   R4  2^53 + 1, the first integer no float holds: refused, expecting
#       `float`. Red under `rounds`, which hands back the float beside it.
#   R5  an `int` field given `1.0`: refused, as before. Red under
#       `int_reads_float`, which converts the other way too.
#   R6  `ValidateAs` over a term holding the integer `1`: refused, as before.
#       Red under `validate_too`, which converts wherever a validator runs.
#   R7  an `int | float` field given `1`: the integer `1`, as before. Red
#       under `always_float`, which converts ahead of the `int` the type has.
#   R8  exemplar 25f, whose answers are typed `float`, served a reply that
#       writes a confidence as `1`: the answer holds `1.0`. Red under
#       `refused` and under `exemplar_only`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
EXEMPLAR="$HERE/examples/exemplars/25f-llm-evaluation-client"
REPLAY="$HERE/../wayfinder/prototypes/25f_replay.erl"

CASES="R1 R2 R3 R4 R5 R6 R7 R8"

call() { # the function and its argument
  case "$1" in
    R1) echo 'Read "{\"price\":1}"' ;;
    R2) echo 'ReadFloat "7"' ;;
    R3) echo 'ReadDeep "{\"all\":[1],\"by\":{\"k\":2},\"one\":{\"t\":\"a\",\"v\":3}}"' ;;
    R4) echo 'Read "{\"price\":9007199254740993}"' ;;
    R5) echo 'ReadWhole "{\"a\":1.0}"' ;;
    R6) echo 'Check' ;;
    R7) echo 'ReadEither "{\"n\":1}"' ;;
  esac
}

# R1 to R4 written before the build, 2026-10-10, from ENG-616. R5 to R7 are
# what the compiler printed before it, and must not change.
ve() { # expected, path
  echo "(:error, {Kind = :'ValidationError', Expected = $1, Path = $2, Reason = :mismatch})"
}
expected_value() {
  case "$1" in
    R1) echo '{"price" = 1.0}' ;;
    R2) echo '7.0' ;;
    R3) echo '{"all" = [1.0], "by" = {"k" = 2.0}, "one" = {"t" = "a", "v" = 3.0}}' ;;
    R4) ve '"float"' '["["price"]"]' ;;
    R5) ve '"int"' '["["a"]"]' ;;
    R6) ve '"float"' '["["price"]"]' ;;
    R7) echo '{"n" = 1}' ;;
    R8) echo 'whole number: ok' ;;
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
    case "$v" in
      R8) [ "$(grep '^whole number: ' "$dir/$v.out" || true)" = "$want" ] \
            || echo "$v: wanted '$want', got '$(grep '^whole number: ' "$dir/$v.out" || tail -n 3 "$dir/$v.out")'" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module, each case one call into it; then the exemplar.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" v fn arg
  mkdir -p "$dir/Prices"
  { printf 'module Prices\n\n'
    printf 'type F = { "price": float }\n'
    printf 'type Deep = { "all": list<float>, "by": map<string, float>,\n'
    printf '              "one": { "t": "a", "v": float } | { "t": "b" } }\n'
    printf 'type Whole = { "a": int }\n'
    printf 'type Either = { "n": int | float }\n\n'
    printf 'public result<F, ValidationError> Read(string body)\n'
    printf 'Read(body) -> FromJson<F>(body)\n\n'
    printf 'public result<float, ValidationError> ReadFloat(string body)\n'
    printf 'ReadFloat(body) -> FromJson<float>(body)\n\n'
    printf 'public result<Deep, ValidationError> ReadDeep(string body)\n'
    printf 'ReadDeep(body) -> FromJson<Deep>(body)\n\n'
    printf 'public result<Whole, ValidationError> ReadWhole(string body)\n'
    printf 'ReadWhole(body) -> FromJson<Whole>(body)\n\n'
    printf 'public result<Either, ValidationError> ReadEither(string body)\n'
    printf 'ReadEither(body) -> FromJson<Either>(body)\n\n'
    # The term a program built itself, holding an integer where `F` has a float.
    printf 'public result<F, ValidationError> Check()\n'
    printf 'Check() -> ValidateAs<F>(Loose())\n\n'
    printf 'private term Loose()\n'
    printf 'Loose() -> { "price" = 1 }\n'
  } > "$dir/Prices/prices.bs"
  (cd "$dir" &&
     for v in R1 R2 R3 R4 R5 R6 R7; do
       fn="$(call "$v" | cut -d' ' -f1)"
       arg="$(call "$v" | cut -s -d' ' -f2-)"
       if [ -n "$arg" ]; then
         "$BSC" Prices "$fn" "$arg" > "$v.out" 2>&1 || true
       else
         "$BSC" Prices "$fn" > "$v.out" 2>&1 || true
       fi
     done)
  # The exemplar, copied into a directory its `module` line matches, then
  # driven by the replay, which prints `whole number: ok` or what it got.
  mkdir -p "$dir/R8/Support/Triage" "$dir/R8/ebin"
  cp "$EXEMPLAR"/*.bs "$dir/R8/Support/Triage/"
  { "$BSC" -o "$dir/R8/ebin" --src-root "$dir/R8" "$dir/R8/Support/Triage" \
      && erlc +warnings_as_errors -o "$dir/R8/ebin" "$REPLAY" \
      && erl -noshell -pa "$dir/R8/ebin" -s '25f_replay' main
  } > "$dir/R8.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — nine defects and one correct form.
#
#   refused          an integer at a float is refused, as before F73
#   unconverted      the integer is accepted and handed back an integer
#   fields_only      a float under a key converts, a float at the top does not
#   shallow          nothing beneath the first object converts
#   rounds           an integer with no exact float becomes the nearest one
#   int_reads_float  an `int` position reads `1.0`
#   validate_too     `ValidateAs` converts as `FromJson` does
#   always_float     `int | float` given `1` hands back `1.0`
#   exemplar_only    every probe is right and the exemplar is not
#
# Each but `refused` is wrong on one case alone, and is required to be.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() { # name, then an output per case, in the order of CASES
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in $CASES; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  G1="$(expected_value R1)"; G2="$(expected_value R2)"; G3="$(expected_value R3)"
  G4="$(expected_value R4)"; G5="$(expected_value R5)"; G6="$(expected_value R6)"
  G7="$(expected_value R7)"
  G8="== openrouter, 200, a confidence written as 1
$(expected_value R8)"
  BAD8='== openrouter, 200, a confidence written as 1
whole number: WRONG {error,{malformed,#{}}}'

  stub good            "$G1" "$G2" "$G3" "$G4" "$G5" "$G6" "$G7" "$G8"
  stub refused         "$G4" "$(ve '"float"' '[]')" \
                       "$(ve '"float"' '["["all"]", "[0]"]')" "$G4" "$G5" "$G6" "$G7" "$BAD8"
  stub unconverted     '{"price" = 1}' "$G2" "$G3" "$G4" "$G5" "$G6" "$G7" "$G8"
  stub fields_only     "$G1" "$(ve '"float"' '[]')" "$G3" "$G4" "$G5" "$G6" "$G7" "$G8"
  stub shallow         "$G1" "$G2" "$(ve '"float"' '["["all"]", "[0]"]')" \
                       "$G4" "$G5" "$G6" "$G7" "$G8"
  stub rounds          "$G1" "$G2" "$G3" '{"price" = 9.007199254740992e15}' \
                       "$G5" "$G6" "$G7" "$G8"
  stub int_reads_float "$G1" "$G2" "$G3" "$G4" '{"a" = 1}' "$G6" "$G7" "$G8"
  stub validate_too    "$G1" "$G2" "$G3" "$G4" "$G5" "$G1" "$G7" "$G8"
  stub always_float    "$G1" "$G2" "$G3" "$G4" "$G5" "$G6" '{"n" = 1.0}' "$G8"
  stub exemplar_only   "$G1" "$G2" "$G3" "$G4" "$G5" "$G6" "$G7" "$BAD8"

  only() { # stub, the one case it must be red on
    if [ "$(judge "$W/$1" | cut -d: -f1 | tr '\n' ' ')" = "$2 " ]; then
      echo "  ok red on $1, at $2 alone"
    else
      echo "  x SELF-TEST: '$1' was not red on $2 alone"; fail=1
    fi
  }
  if [ -z "$(judge "$W/refused")" ]; then
    echo "  x SELF-TEST: 'refused' produced no complaint - the gate cannot see it"; fail=1
  else
    echo "  ok red on refused"
  fi
  only unconverted R1
  only fields_only R2
  only shallow R3
  only rounds R4
  only int_reads_float R5
  only validate_too R6
  only always_float R7
  only exemplar_only R8
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT set of outputs was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: nine defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         under FromJson, a float position reads a JSON integer"
