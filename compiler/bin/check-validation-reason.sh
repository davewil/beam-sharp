#!/usr/bin/env bash
#
# F70 / ENG-615 — A `ValidationError` SAYS WHY: IT CARRIES A `Reason`, AND AN
# ABSENT OR UNKNOWN KEY IS BLAMED AT ITS OWN PATH.
#
# Ticket 78 Q16, Q12, Q21 and Q24. Each case is run, and what `bsc` prints is
# compared whole: an accept asserted as an absence would pass a program that
# stopped compiling for an unrelated reason.
#
#   R1  a wrong value: `:mismatch` at the key. Red under `no_reason`, the
#       two-field record F49 built.
#   R2  an absent required key: `:missing` at that key, expecting the key's
#       type. Red under `blames_object`, which reports the whole type at the
#       object, and under `all_mismatch`, which finds the key and cannot say
#       it was absent (the fault Q12's recommendation names in Zod and Gleam).
#   R3  a key an exact type does not name: `:unknown_key` at that key,
#       expecting the keys the type names. Red under the same two.
#   R4  text that is not JSON: `:not_json`. Red under `all_mismatch`.
#   R5  an `Explain` with a clause for four of the five reasons: refused as
#       not exhaustive. Red under `open_reason`, where `Reason` is any atom
#       and no set of clauses is short. The residual prints the record whole,
#       as any record's does, so the fifth reason is not asserted here.
#   R6  exemplar 25f, served `{"answers":{}}`: `(:malformed, e)` with `e`
#       missing `"model"`. Red under `blames_object`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
EXEMPLAR="$HERE/examples/exemplars/25f-llm-evaluation-client"
REPLAY="$HERE/../wayfinder/prototypes/25f_replay.erl"

CASES="R1 R2 R3 R4 R5 R6"

input() {
  case "$1" in
    R1) echo '"{\"a\":\"x\"}"' ;;
    R2) echo '"{}"' ;;
    R3) echo '"{\"a\":1,\"b\":2}"' ;;
    R4) echo '"nope"' ;;
  esac
}

# Written before the build, 2026-10-09, from ticket 78's rounds 8 and 9.
ve() { # expected, path, reason
  echo "(:error, {Kind = :'ValidationError', Expected = $1, Path = $2, Reason = :$3})"
}
expected_value() {
  case "$1" in
    R1) ve '"int"' '["["a"]"]' mismatch ;;
    R2) ve '"int"' '["["a"]"]' missing ;;
    R3) ve '""a""' '["["b"]"]' unknown_key ;;
    R4) ve '"JSON"' '[]' not_json ;;
    R5) echo 'error: Explain is not exhaustive' ;;
    R6) echo 'malformed: ok' ;;
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
      R5) # a refusal: its first line, less the position
          [ "$(head -n 1 "$dir/$v.out" | sed -E 's/^[^ ]+:[0-9]+:[0-9]+: //')" = "$want" ] \
            || echo "$v: wanted the refusal '$want', got '$(head -n 1 "$dir/$v.out")'" ;;
      R6) [ "$(grep '^malformed: ' "$dir/$v.out" || true)" = "$want" ] \
            || echo "$v: wanted '$want', got '$(grep '^malformed: ' "$dir/$v.out" || tail -n 3 "$dir/$v.out")'" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module per case, each run on its input; then the exemplar.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" v lower
  for v in R1 R2 R3 R4 R5; do
    lower="$(echo "$v" | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$dir/$v"
    { printf 'module %s\n\n' "$v"
      printf 'type W = { "a": int }\n\n'
      printf 'public result<W, ValidationError> Read(string body)\n'
      printf 'Read(body) -> FromJson<W>(body)\n\n'
      printf 'public string Explain(ValidationError e)\n'
      printf 'Explain(ValidationError { Reason: :not_json })      -> "not JSON"\n'
      printf 'Explain(ValidationError { Reason: :missing })       -> "absent"\n'
      printf 'Explain(ValidationError { Reason: :unknown_key })   -> "not ours"\n'
      [ "$v" = R5 ] || printf 'Explain(ValidationError { Reason: :duplicate_key }) -> "repeated"\n'
      printf 'Explain(ValidationError { Reason: :mismatch })      -> "wrong type"\n'
    } > "$dir/$v/$lower.bs"
  done
  (cd "$dir" &&
     for v in R1 R2 R3 R4; do
       "$BSC" "$v" Read "$(input "$v")" > "$v.out" 2>&1 || true
     done
     "$BSC" R5 > R5.out 2>&1 || true)
  # The exemplar, copied into a directory its `module` line matches, then
  # driven by the replay, which prints `malformed: ok` or what it got.
  mkdir -p "$dir/R6/Support/Triage" "$dir/R6/ebin"
  cp "$EXEMPLAR"/*.bs "$dir/R6/Support/Triage/"
  { "$BSC" -o "$dir/R6/ebin" --src-root "$dir/R6" "$dir/R6/Support/Triage" \
      && erlc +warnings_as_errors -o "$dir/R6/ebin" "$REPLAY" \
      && erl -noshell -pa "$dir/R6/ebin" -s '25f_replay' main
  } > "$dir/R6.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form.
#
#   no_reason      the record has two fields
#   blames_object  an absent or unknown key is the whole type at the object
#   all_mismatch   every failure is `:mismatch`
#   open_reason    `Reason` is any atom: the four clauses with a fifth for
#                  any other atom compile, and R5's module does too
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() { # name, then an output per case R1..R6
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in $CASES; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  G1="$(expected_value R1)"; G2="$(expected_value R2)"; G3="$(expected_value R3)"
  G4="$(expected_value R4)"
  G5="R5/r5.bs:8:15: $(expected_value R5)
  no clause matches:
    Explain(ValidationError v) -> ..."
  G6="== openrouter, 200, malformed
$(expected_value R6)"
  WHOLE="$(ve '"{ "a": int }"' '[]' mismatch)"
  BAD6='== openrouter, 200, malformed
malformed: WRONG {error,{malformed,#{}}}'

  stub good          "$G1" "$G2" "$G3" "$G4" "$G5" "$G6"
  stub no_reason \
       "(:error, {Kind = :'ValidationError', Expected = \"int\", Path = [\"[\"a\"]\"]})" \
       "(:error, {Kind = :'ValidationError', Expected = \"{ \"a\": int }\", Path = []})" \
       "(:error, {Kind = :'ValidationError', Expected = \"{ \"a\": int }\", Path = []})" \
       "(:error, {Kind = :'ValidationError', Expected = \"JSON\", Path = []})" \
       'R5/r5.bs:8:9: error: Reason is not declared by ValidationError' "$BAD6"
  stub blames_object "$G1" "$WHOLE" "$WHOLE" "$G4" "$G5" "$BAD6"
  stub all_mismatch  "$G1" "$(ve '"int"' '["["a"]"]' mismatch)" \
       "$(ve '""a""' '["["b"]"]' mismatch)" "$(ve '"JSON"' '[]' mismatch)" "$G5" "$BAD6"
  stub open_reason   "$G1" "$G2" "$G3" "$G4" '' "$G6"

  for bad in no_reason blames_object all_mismatch open_reason; do
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
echo "  ok         a ValidationError carries its Reason; an absent or unknown key is blamed at its own path"
