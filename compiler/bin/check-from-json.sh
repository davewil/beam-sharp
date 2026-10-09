#!/usr/bin/env bash
#
# F69 / ENG-410 — `FromJson<T>(text)` IS `json:decode` THEN `ValidateAs<T>`:
# TEXT THAT IS NOT JSON IS A VALUE, NOT A CRASH, AND A RECORD IS REFUSED.
#
# Ticket 78 Q10. Each case is run, and what `bsc` prints is compared whole: an
# accept asserted as an absence would pass a program that stopped compiling
# for an unrelated reason.
#
#   J1  JSON that inhabits an open wire type, its option key absent: the
#       value, with `:nothing` filled as `ValidateAs` fills it. Red under
#       `decode_only`, which hands back what `json:decode` returned.
#   J2  text that is not JSON: a `ValidationError`, `Path = []`,
#       `Expected = "JSON"`. Red under `crash`, where the decoder's exception
#       escapes, and under `blames_type`, which reports the failed parse as a
#       failed validation of the whole type.
#   J3  JSON that does not inhabit the type: refused at its key. Red under
#       `decode_only`.
#   J4  `FromJson` over a type holding a record: refused at the compile,
#       naming ticket 78 Q4. Red under `record_admitted`, which compiles it
#       and validates against a `Kind` no JSON this program reads carries.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

CASES="J1 J2 J3 J4"

input() {
  case "$1" in
    J1) echo '"{\"model\":\"jev\",\"cost\":2}"' ;;
    J2) echo '"{\"model\":"' ;;
    J3) echo '"{\"model\":7}"' ;;
    J4) echo '"{\"Id\":1}"' ;;
  esac
}

# Copied from `bsc`'s output on the correct build, 2026-10-09. J4 is the
# refusal's first line after the position.
expected_value() {
  case "$1" in
    J1) echo '{"cost" = 2, "id" = :nothing, "model" = "jev"}' ;;
    J2) echo "(:error, {Kind = :'ValidationError', Expected = \"JSON\", Path = []})" ;;
    J3) echo "(:error, {Kind = :'ValidationError', Expected = \"string\", Path = [\"[\"model\"]\"]})" ;;
    J4) echo 'error: Decode calls FromJson over a type that holds a record' ;;
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
      J4) # a refusal: its first line, less the position, and Q4 named below it
          [ "$(head -n 1 "$dir/$v.out" | sed -E 's/^[^ ]+:[0-9]+:[0-9]+: //')" = "$want" ] \
            || echo "$v: wanted the refusal '$want', got '$(head -n 1 "$dir/$v.out")'"
          grep -q 'ticket 78 Q4' "$dir/$v.out" \
            || echo "$v: the refusal does not name ticket 78 Q4" ;;
      *)  [ "$out" = "$want" ] || echo "$v: wanted '$want', got '$out'" ;;
    esac
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
      printf 'public result<%s, ValidationError> Decode(string text)\n' "$3"
      printf 'Decode(text) -> FromJson<%s>(text)\n' "$3"
    } > "$dir/$1/$lower.bs"
  }
  WIRE='type W = { "id": option<string>, "model": string, .. }'
  emit J1 "$WIRE" 'W'
  emit J2 "$WIRE" 'W'
  emit J3 "$WIRE" 'W'
  emit J4 'record Order { Id: int }' 'list<Order>'
  (cd "$dir" &&
     for v in $CASES; do
       "$BSC" "$v" Decode "$(input "$v")" > "$v.out" 2>&1 || true
     done)
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form.
#
#   decode_only      the decoded term is returned unvalidated
#   crash            the decoder's exception escapes
#   blames_type      a failed parse is reported as a failed validation
#   record_admitted  a record target compiles
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() { # name, then an output per case J1..J4
    local d="$W/$1"; shift
    mkdir -p "$d"
    local i=1 v
    for v in $CASES; do
      eval "printf '%s' \"\${$i}\"" > "$d/$v.out"
      i=$((i + 1))
    done
  }
  G1="$(expected_value J1)"; G2="$(expected_value J2)"; G3="$(expected_value J3)"
  G4="J4/j4.bs:6:17: $(expected_value J4)
  reading a record back from JSON is deferred (ticket 78 Q4)"

  stub good            "$G1" "$G2" "$G3" "$G4"
  stub decode_only     '{"cost" = 2, "model" = "jev"}' "$G2" '{"model" = 7}' "$G4"
  stub crash           "$G1" 'error: Decode crashed: unexpected_end' "$G3" "$G4"
  stub blames_type     "$G1" \
       "(:error, {Kind = :'ValidationError', Expected = \"{ \"id\": :nothing | string, \"model\": string, .. }\", Path = []})" \
       "$G3" "$G4"
  stub record_admitted "$G1" "$G2" "$G3" \
       "(:error, {Kind = :'ValidationError', Expected = \"{ Kind: :'J4.Order', Id: int }\", Path = [\"[0]\"]})"

  for bad in decode_only crash blames_type record_admitted; do
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
echo "  ok         FromJson decodes then validates; bad text is a ValidationError; a record is refused"
