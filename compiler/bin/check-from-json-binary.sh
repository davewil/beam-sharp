#!/usr/bin/env bash
#
# F74 / ENG-611 — `FromJson<T>` TAKES A `binary`.
#
# Ticket 78 Q13 and Q23. Each case is run, and what `bsc` prints is compared
# whole: an accept asserted as an absence would pass a program that stopped
# compiling for an unrelated reason.
#
#   B1  a `binary` argument holding JSON: the value. Red under `refused`,
#       which is the compiler before F74.
#   B2  a `string` argument: the value, as before. Red under `text_refused`,
#       which takes a `binary` and no longer a `string`.
#   B3  bytes that are not UTF-8: `:not_json` at the top, expecting `JSON`.
#       Red under `refused`, under `crashes`, and under `as_string`, which
#       reports what `ValidateAs<string>` reported.
#   B4  the binary piped in: the value. Red under `call_only`, which checks
#       the piped form against `string` still.
#   B5  an `int` argument: refused, and the refusal says `int`. Red under
#       `anything`, which stopped checking the argument.
#   B6  exemplar 25f, its `Parse` a bare `FromJson<ReplyWire>(body)`, served
#       a body with a byte that is not UTF-8: `(:malformed, e)` with `e` the
#       `:not_json` error. Red under `refused` and under `exemplar_only`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
EXEMPLAR="$HERE/examples/exemplars/25f-llm-evaluation-client"
REPLAY="$HERE/../wayfinder/prototypes/25f_replay.erl"

CASES="B1 B2 B3 B4 B5 B6"

call() { # the module, the function and its argument
  case "$1" in
    B1) echo 'Body ReadBytes "{\"a\":1}"' ;;
    B2) echo 'Body ReadText "{\"a\":1}"' ;;
    B3) echo 'Body ReadBytes <<255>>' ;;
    B4) echo 'Body Piped "{\"a\":1}"' ;;
    B5) echo 'Whole Read 1' ;;
  esac
}

# B1, B3 and B4 written before the build, 2026-10-11, from ENG-611. B2 and B5
# are what the compiler printed before it, and must not change.
NOT_JSON="(:error, {Kind = :'ValidationError', Expected = \"JSON\", Path = [], Reason = :not_json})"
expected_value() {
  case "$1" in
    B1|B2|B4) echo '{"a" = 1}' ;;
    B3) echo "$NOT_JSON" ;;
    B5) printf '%s\n' \
          'Whole/whole.bs:4:15: error: Read hands FromJson an argument it does not accept' \
          "  argument 1 is not covered by FromJson's declared type:" \
          '    int' \
          '  the clause to add here:' \
          '    Read(n) -> ...' ;;
    B6) echo 'not utf-8: ok' ;;
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
      B6) [ "$(grep '^not utf-8: ' "$dir/$v.out" || true)" = "$want" ] \
            || echo "$v: wanted '$want', got '$(grep '^not utf-8: ' "$dir/$v.out" || tail -n 3 "$dir/$v.out")'" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — two modules, each case one call into one; then the exemplar.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" v mod fn arg
  mkdir -p "$dir/Body" "$dir/Whole"
  { printf 'module Body\n\n'
    printf 'type W = { "a": int }\n\n'
    printf 'public result<W, ValidationError> ReadBytes(binary body)\n'
    printf 'ReadBytes(body) -> FromJson<W>(body)\n\n'
    printf 'public result<W, ValidationError> ReadText(string body)\n'
    printf 'ReadText(body) -> FromJson<W>(body)\n\n'
    printf 'public result<W, ValidationError> Piped(binary body)\n'
    printf 'Piped(body) -> body |> FromJson<W>()\n'
  } > "$dir/Body/body.bs"
  { printf 'module Whole\n\n'
    printf 'public result<int, ValidationError> Read(int body)\n'
    printf 'Read(body) -> FromJson<int>(body)\n'
  } > "$dir/Whole/whole.bs"
  (cd "$dir" &&
     for v in B1 B2 B3 B4 B5; do
       mod="$(call "$v" | cut -d' ' -f1)"
       fn="$(call "$v" | cut -d' ' -f2)"
       arg="$(call "$v" | cut -d' ' -f3-)"
       "$BSC" "$mod" "$fn" "$arg" > "$v.out" 2>&1 || true
     done)
  # The exemplar, copied into a directory its `module` line matches, then
  # driven by the replay, which prints `not utf-8: ok` or what it got.
  mkdir -p "$dir/B6/Support/Triage" "$dir/B6/ebin"
  cp "$EXEMPLAR"/*.bs "$dir/B6/Support/Triage/"
  { "$BSC" -o "$dir/B6/ebin" --src-root "$dir/B6" "$dir/B6/Support/Triage" \
      && erlc +warnings_as_errors -o "$dir/B6/ebin" "$REPLAY" \
      && erl -noshell -pa "$dir/B6/ebin" -s '25f_replay' main
  } > "$dir/B6.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — seven defects and one correct form.
#
#   refused        a `binary` argument is refused, as before F74
#   text_refused   a `binary` goes in and a `string` no longer does
#   crashes        bytes that are not UTF-8 crash the call
#   as_string      they are reported as `ValidateAs<string>` reported them
#   call_only      the piped form is still checked against `string`
#   anything       the argument is no longer checked
#   exemplar_only  every probe is right and the exemplar is not
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
  G1="$(expected_value B1)"; G3="$(expected_value B3)"; G5="$(expected_value B5)"
  G6="== openrouter, 200, a byte that is not UTF-8
$(expected_value B6)"
  BAD6='== openrouter, 200, a byte that is not UTF-8
not utf-8: WRONG {error,{malformed,#{}}}'
  refusal() { # function, line:column
    printf '%s\n' \
      "Body/body.bs:$2: error: $1 hands FromJson an argument it does not accept" \
      "  argument 1 is not covered by FromJson's declared type:" \
      '    binary \ string'
  }
  REFUSED="$(refusal ReadBytes 6:20)
$(refusal Piped 12:21)"
  AS_STRING="(:error, {Kind = :'ValidationError', Expected = \"string\", Path = [], Reason = :mismatch})"

  stub good          "$G1" "$G1" "$G3" "$G1" "$G5" "$G6"
  stub refused       "$REFUSED" "$REFUSED" "$REFUSED" "$REFUSED" "$G5" "$BAD6"
  stub text_refused  "$G1" "$(refusal ReadText 9:19)" "$G3" "$G1" "$G5" "$G6"
  stub crashes       "$G1" "$G1" "error: {invalid_byte,255}" "$G1" "$G5" "$G6"
  stub as_string     "$G1" "$G1" "$AS_STRING" "$G1" "$G5" "$G6"
  stub call_only     "$G1" "$G1" "$G3" "$(refusal Piped 12:21)" "$G5" "$G6"
  stub anything      "$G1" "$G1" "$G3" "$G1" "$G3" "$G6"
  stub exemplar_only "$G1" "$G1" "$G3" "$G1" "$G5" "$BAD6"

  only() { # stub, the one case it must be red on
    if [ "$(judge "$W/$1" | grep -o '^B[0-9]: wanted' | cut -d: -f1 | tr '\n' ' ')" = "$2 " ]; then
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
  only text_refused B2
  only crashes B3
  only as_string B3
  only call_only B4
  only anything B5
  only exemplar_only B6
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT set of outputs was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: seven defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         FromJson takes a binary, and bytes that are not UTF-8 are not JSON"
