#!/usr/bin/env bash
#
# F72 / ENG-618 — A UNION TAGGED BY A STRING-LITERAL KEY IS VALIDATED BY THAT
# KEY FIRST.
#
# Ticket 78 Q19 and Q22. Each case is run, and what `bsc` prints is compared
# whole: an accept asserted as an absence would pass a program that stopped
# compiling for an unrelated reason.
#
#   T1  a tag no member names: `:mismatch` at the tag, expecting the tags.
#       Red under `whole_union`, which reports the union at the object.
#   T2  a named tag with a wrong value beside it: the error the named member
#       gives, at that value. Red under `whole_union`, and under
#       `first_member`, which asks the first member whatever the tag says.
#   T3  no tag: `:missing` at the tag. Red under `whole_union`, and under
#       `no_missing`, which finds the tag and cannot say it was absent.
#   T4  the union as a map's value: the entry's path, then the tag's. Red
#       under `top_only`, which reads the tag only where the union is the
#       whole value.
#   T5  `AnswerWire | :null` given `null`: the atom. Red under `maps_only`,
#       which sends everything to the tag.
#   T6  a union whose members share no key: the whole union at the object,
#       as before. Red under `always_tag`, which blames a key regardless.
#   T7  exemplar 25f, served a reply whose answer has `"type":"tri"`:
#       `(:malformed, e)` with `e` at the answer's tag. Red under
#       `whole_union` and under `exemplar_only`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
EXEMPLAR="$HERE/examples/exemplars/25f-llm-evaluation-client"
REPLAY="$HERE/../wayfinder/prototypes/25f_replay.erl"

CASES="T1 T2 T3 T4 T5 T6 T7"

call() { # the function and its argument
  case "$1" in
    T1) echo 'Read "{\"type\":\"tri\",\"choice\":\"x\"}"' ;;
    T2) echo 'Read "{\"type\":\"score\",\"score\":\"x\"}"' ;;
    T3) echo 'Read "{\"choice\":\"x\"}"' ;;
    T4) echo 'ReadReply "{\"answers\":{\"q\":{\"type\":\"tri\"}}}"' ;;
    T5) echo 'ReadMaybe "null"' ;;
    T6) echo 'ReadNoTag "{\"c\":1}"' ;;
  esac
}

# T1 to T4 written before the build, 2026-10-10, from ENG-618. T5 and T6 are
# what the compiler printed before it, and must not change.
ve() { # expected, path, reason
  echo "(:error, {Kind = :'ValidationError', Expected = $1, Path = $2, Reason = :$3})"
}
TAGS='""choice" | "score""'
UNION='"{ "choice": string, "type": "choice", .. } | { "score": int, "type": "score", .. }"'
expected_value() {
  case "$1" in
    T1) ve "$TAGS" '["["type"]"]' mismatch ;;
    T2) ve '"int"' '["["score"]"]' mismatch ;;
    T3) ve "$TAGS" '["["type"]"]' missing ;;
    T4) ve "$TAGS" '["["answers"]", "["q"]", "["type"]"]' mismatch ;;
    T5) echo ':null' ;;
    T6) ve '"{ "a": int } | { "b": int }"' '[]' mismatch ;;
    T7) echo 'unknown tag: ok' ;;
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
      T7) [ "$(grep '^unknown tag: ' "$dir/$v.out" || true)" = "$want" ] \
            || echo "$v: wanted '$want', got '$(grep '^unknown tag: ' "$dir/$v.out" || tail -n 3 "$dir/$v.out")'" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — one module, each case one call into it; then the exemplar.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" v fn arg
  mkdir -p "$dir/Tagged"
  { printf 'module Tagged\n\n'
    printf 'type AnswerWire = { "type": "choice", "choice": string, .. }\n'
    printf '                | { "type": "score", "score": int, .. }\n'
    printf 'type Reply = { "answers": map<string, AnswerWire> }\n'
    printf 'type NoTag = { "a": int } | { "b": int }\n\n'
    printf 'public result<AnswerWire, ValidationError> Read(string body)\n'
    printf 'Read(body) -> FromJson<AnswerWire>(body)\n\n'
    printf 'public result<Reply, ValidationError> ReadReply(string body)\n'
    printf 'ReadReply(body) -> FromJson<Reply>(body)\n\n'
    printf 'public result<AnswerWire | :null, ValidationError> ReadMaybe(string body)\n'
    printf 'ReadMaybe(body) -> FromJson<AnswerWire | :null>(body)\n\n'
    printf 'public result<NoTag, ValidationError> ReadNoTag(string body)\n'
    printf 'ReadNoTag(body) -> FromJson<NoTag>(body)\n'
  } > "$dir/Tagged/tagged.bs"
  (cd "$dir" &&
     for v in T1 T2 T3 T4 T5 T6; do
       fn="$(call "$v" | cut -d' ' -f1)"
       arg="$(call "$v" | cut -d' ' -f2-)"
       "$BSC" Tagged "$fn" "$arg" > "$v.out" 2>&1 || true
     done)
  # The exemplar, copied into a directory its `module` line matches, then
  # driven by the replay, which prints `unknown tag: ok` or what it got.
  mkdir -p "$dir/T7/Support/Triage" "$dir/T7/ebin"
  cp "$EXEMPLAR"/*.bs "$dir/T7/Support/Triage/"
  { "$BSC" -o "$dir/T7/ebin" --src-root "$dir/T7" "$dir/T7/Support/Triage" \
      && erlc +warnings_as_errors -o "$dir/T7/ebin" "$REPLAY" \
      && erl -noshell -pa "$dir/T7/ebin" -s '25f_replay' main
  } > "$dir/T7.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — seven defects and one correct form.
#
#   whole_union    the union is reported at the object, as before F72
#   first_member   the first member is asked whatever the tag says
#   no_missing     an absent tag is called a mismatch
#   top_only       the tag is read only where the union is the whole value
#   maps_only      a member that is not a map is sent to the tag
#   always_tag     a union with no tag blames a key anyway
#   exemplar_only  every probe is right and the exemplar is not
#
# Each of the last five is wrong on one case alone, and is required to be.
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
  G1="$(expected_value T1)"; G2="$(expected_value T2)"; G3="$(expected_value T3)"
  G4="$(expected_value T4)"; G5="$(expected_value T5)"; G6="$(expected_value T6)"
  G7="== openrouter, 200, an answer of type \"tri\"
$(expected_value T7)"
  BAD7='== openrouter, 200, an answer of type "tri"
unknown tag: WRONG {error,{malformed,#{}}}'
  WHOLE="$(ve "$UNION" '[]' mismatch)"

  stub good          "$G1" "$G2" "$G3" "$G4" "$G5" "$G6" "$G7"
  stub whole_union   "$WHOLE" "$WHOLE" "$WHOLE" \
                     "$(ve "$UNION" '["["answers"]", "["q"]"]' mismatch)" "$G5" "$G6" "$BAD7"
  stub first_member  "$G1" "$(ve '"string"' '["["choice"]"]' missing)" "$G3" "$G4" "$G5" "$G6" "$G7"
  stub no_missing    "$G1" "$G2" "$G1" "$G4" "$G5" "$G6" "$G7"
  stub top_only      "$G1" "$G2" "$G3" \
                     "$(ve "$UNION" '["["answers"]", "["q"]"]' mismatch)" "$G5" "$G6" "$G7"
  stub maps_only     "$G1" "$G2" "$G3" "$G4" "$G3" "$G6" "$G7"
  stub always_tag    "$G1" "$G2" "$G3" "$G4" "$G5" "$(ve '"int"' '["["a"]"]' missing)" "$G7"
  stub exemplar_only "$G1" "$G2" "$G3" "$G4" "$G5" "$G6" "$BAD7"

  only() { # stub, the one case it must be red on
    if [ "$(judge "$W/$1" | cut -d: -f1 | tr '\n' ' ')" = "$2 " ]; then
      echo "  ok red on $1, at $2 alone"
    else
      echo "  x SELF-TEST: '$1' was not red on $2 alone"; fail=1
    fi
  }
  if [ -z "$(judge "$W/whole_union")" ]; then
    echo "  x SELF-TEST: 'whole_union' produced no complaint - the gate cannot see it"; fail=1
  else
    echo "  ok red on whole_union"
  fi
  only first_member T2
  only no_missing T3
  only top_only T4
  only maps_only T5
  only always_tag T6
  only exemplar_only T7
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
echo "  ok         a union tagged by a string-literal key is validated by that key first"
