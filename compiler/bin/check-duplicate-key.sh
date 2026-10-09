#!/usr/bin/env bash
#
# F71 / ENG-617 — `FromJson` REFUSES JSON WITH A REPEATED KEY, AND TEXT AFTER
# THE VALUE.
#
# Ticket 78 Q15 and Q20. Each case is run, and what `bsc` prints is compared
# whole: an accept asserted as an absence would pass a program that stopped
# compiling for an unrelated reason.
#
#   D1  `{"a":1,"a":"x"}`: `:duplicate_key` at `[]`, expecting `"a" once`.
#       Red under `first_wins`, which keeps the 1 and never looks at the
#       second value; under `last_wins`, which validates the second and
#       calls it a mismatch; and under `no_key`, which refuses it without
#       saying which key.
#   D2  the repeat inside a list element: the same value, `Path` still `[]`.
#       Red under `first_wins` and `last_wins`.
#   D3  `{"a":1,"a":1}`: refused though the two agree. Red under
#       `unequal_only`, which compares the values before complaining.
#   D4  `{"a":1} x`: `:not_json`. Red under `prefix`, which reads the value
#       and drops what follows it.
#   D5  `{"a":1}` then a space: the value. Red under `strict_end`, which
#       refuses any remainder at all.
#   D6  exemplar 25f, served a good reply with `"model"` a second time:
#       `(:malformed, e)` with `e` naming `"model"`. Red under `first_wins`
#       and `last_wins`, which hand back an evaluation.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
EXEMPLAR="$HERE/examples/exemplars/25f-llm-evaluation-client"
REPLAY="$HERE/../wayfinder/prototypes/25f_replay.erl"

CASES="D1 D2 D3 D4 D5 D6"

call() { # the function and its argument
  case "$1" in
    D1) echo 'Read "{\"a\":1,\"a\":\"x\"}"' ;;
    D2) echo 'ReadAll "[{\"a\":1},{\"a\":1,\"a\":2}]"' ;;
    D3) echo 'Read "{\"a\":1,\"a\":1}"' ;;
    D4) echo 'Read "{\"a\":1} x"' ;;
    D5) echo 'Read "{\"a\":1} "' ;;
  esac
}

# Written before the build, 2026-10-09, from ticket 78's Q20.
ve() { # expected, path, reason
  echo "(:error, {Kind = :'ValidationError', Expected = $1, Path = $2, Reason = :$3})"
}
expected_value() {
  case "$1" in
    D1|D2|D3) ve '""a" once"' '[]' duplicate_key ;;
    D4)       ve '"JSON"' '[]' not_json ;;
    D5)       echo '{"a" = 1}' ;;
    D6)       echo 'repeated: ok' ;;
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
      D6) [ "$(grep '^repeated: ' "$dir/$v.out" || true)" = "$want" ] \
            || echo "$v: wanted '$want', got '$(grep '^repeated: ' "$dir/$v.out" || tail -n 3 "$dir/$v.out")'" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module, each case one call into it; then the exemplar.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" v fn arg
  mkdir -p "$dir/Repeat"
  { printf 'module Repeat\n\n'
    printf 'type W = { "a": int }\n\n'
    printf 'public result<W, ValidationError> Read(string body)\n'
    printf 'Read(body) -> FromJson<W>(body)\n\n'
    printf 'public result<list<W>, ValidationError> ReadAll(string body)\n'
    printf 'ReadAll(body) -> FromJson<list<W>>(body)\n'
  } > "$dir/Repeat/repeat.bs"
  (cd "$dir" &&
     for v in D1 D2 D3 D4 D5; do
       fn="$(call "$v" | cut -d' ' -f1)"
       arg="$(call "$v" | cut -d' ' -f2-)"
       "$BSC" Repeat "$fn" "$arg" > "$v.out" 2>&1 || true
     done)
  # The exemplar, copied into a directory its `module` line matches, then
  # driven by the replay, which prints `repeated: ok` or what it got.
  mkdir -p "$dir/D6/Support/Triage" "$dir/D6/ebin"
  cp "$EXEMPLAR"/*.bs "$dir/D6/Support/Triage/"
  { "$BSC" -o "$dir/D6/ebin" --src-root "$dir/D6" "$dir/D6/Support/Triage" \
      && erlc +warnings_as_errors -o "$dir/D6/ebin" "$REPLAY" \
      && erl -noshell -pa "$dir/D6/ebin" -s '25f_replay' main
  } > "$dir/D6.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — six defects and one correct form.
#
#   first_wins    the first value is kept, as `json:decode/1` kept it
#   last_wins     the last value is kept and validated
#   no_key        a repeat is refused as text that is not JSON
#   unequal_only  a repeat is refused only where its values differ
#   prefix        the value is read and the text after it is dropped
#   strict_end    whitespace after the value is refused
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() { # name, then an output per case D1..D6
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in $CASES; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  G1="$(expected_value D1)"; G4="$(expected_value D4)"; G5="$(expected_value D5)"
  ONE='{"a" = 1}'
  LIST='[{"a" = 1}, {"a" = 1}]'
  G6="== openrouter, 200, \"model\" twice
$(expected_value D6)"
  BAD6='== openrouter, 200, "model" twice
repeated: WRONG #{}'

  stub good         "$G1" "$G1" "$G1" "$G4" "$G5" "$G6"
  stub first_wins   "$ONE" "$LIST" "$ONE" "$G4" "$G5" "$BAD6"
  stub last_wins    "$(ve '"int"' '["["a"]"]' mismatch)" '[{"a" = 1}, {"a" = 2}]' \
                    "$ONE" "$G4" "$G5" "$BAD6"
  stub no_key       "$G4" "$G4" "$G4" "$G4" "$G5" "$BAD6"
  stub unequal_only "$G1" "$G1" "$ONE" "$G4" "$G5" "$G6"
  stub prefix       "$G1" "$G1" "$G1" "$ONE" "$G5" "$G6"
  stub strict_end   "$G1" "$G1" "$G1" "$G4" "$G4" "$G6"

  for bad in first_wins last_wins no_key unequal_only prefix strict_end; do
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
  echo "self-test passed: six defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         FromJson refuses a repeated key and text after the value"
