#!/usr/bin/env bash
#
# F49 / ticket 79 — `ValidationError` IS A RECORD, AND THE VALUE THE PROGRAM
# RUNS WITH IS THAT RECORD.
#
# THE CHECKER CANNOT SEE EITHER DEFECT THIS GATE EXISTS FOR. The type lives in
# `stratum_two/0`; the value is built in two other places — the validator's
# `error_expr/1` and a construction's `e_record`. Change the type and leave
# either value site alone, and every program below still COMPILES: the record
# pattern resolves, the projection types, the construction types. Only a run
# notices, because the clause head a public `ValidationError` parameter gets is
# guarded on the bare tag and the stale value does not carry it.
#
# SO EVERY PROBE IS A RUN, ASSERTED AS THE EXACT VALUE `bsc` PRINTS.
#   P1  `Where` on a bad order — the validator's value reaches the record
#       pattern. Red under `tuple_emitted`.
#   P2  `Decode` on the same order — the value itself, bare tag and all.
#       Red under `tuple_emitted`. The tag prints quoted, `:'ValidationError'`,
#       because the bare atom sigil takes a lowercase name only.
#   P3  `RoundTrip` — a value built by hand reaches the same pattern. Red under
#       `minted_tag`, and green under `tuple_emitted`, which is why it is a
#       separate probe rather than a third line of P1.
# An absence would pass on a module that stopped compiling for an unrelated
# reason, which `broken` below holds the gate to.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

BAD="{ Kind = :'Orders.Order', Id = 1, Total = :x }"

expected_value() {
  case "$1" in
    P1) echo '[".Total"]' ;;
    P2) echo "(:error, {Kind = :'ValidationError', Expected = \"int\", Path = [\".Total\"]})" ;;
    P3) echo '["x"]' ;;
  esac
}

# ---------------------------------------------------------------------------
# judge — the gate's whole opinion, driven by --self-test against fixtures.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p out want
  for p in P1 P2 P3; do
    out="$(cat "$dir/$p.out")"
    want="$(expected_value "$p")"
    if [ "$out" != "$want" ]; then
      echo "$p: expected '$want', got '${out:-(nothing)}'"
    fi
  done
}

# ---------------------------------------------------------------------------
# probe — ticket 79's program, compiled once and run three times.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1"
  mkdir -p "$dir/Orders"
  cat > "$dir/Orders/orders.bs" <<'EOF'
module Orders

record Order { Id: int, Total: int }

public result<Order, ValidationError> Decode(term t)
Decode(t) -> ValidateAs<Order>(t)

public list<string> Rejected(ValidationError e)
Rejected(ValidationError { Path: p }) -> p

public list<string> Where(term t)
Where(t) -> Decode(t) switch {
    (:error, e) => Rejected(e),
    o           => []
}

public list<string> RoundTrip(list<string> p)
RoundTrip(p) -> Rejected(ValidationError { Path = p, Expected = "int" })
EOF
  (cd "$dir" &&
     { "$BSC" Orders Where "$BAD" > P1.out 2>&1 || true; } &&
     { "$BSC" Orders Decode "$BAD" > P2.out 2>&1 || true; } &&
     { "$BSC" Orders RoundTrip '["x"]' > P3.out 2>&1 || true; })
}

# ---------------------------------------------------------------------------
# --self-test — three defects and one correct form.
#
#   tuple_emitted  the stratum entry changed, `error_expr/1` untouched: the
#                  validator still returns `(list, string)`, so `Rejected`'s
#                  tag guard refuses it (P1) and P2 prints the tuple. P3 is
#                  green, because construction never touched the validator.
#   minted_tag     construction still mints from the module: P1 and P2 green,
#                  P3 crashes on `'Orders.ValidationError'`.
#   broken         nothing compiles, so every probe prints a diagnostic and
#                  none prints a value.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  # What `bsc` prints when `Rejected`'s tag guard refuses the value it is handed.
  CRASH="crashed: error:function_clause"
  REFUSED="Orders/orders.bs:9:10: error: ValidationError is not a record, so it cannot name a pattern"

  stub() { # name, then the output of P1 P2 P3
    local d="$W/$1"
    mkdir -p "$d"
    printf '%s' "$2" > "$d/P1.out"
    printf '%s' "$3" > "$d/P2.out"
    printf '%s' "$4" > "$d/P3.out"
  }
  stub good          "$(expected_value P1)" "$(expected_value P2)" "$(expected_value P3)"
  stub tuple_emitted "$CRASH" '(:error, ([".Total"], "int"))' "$(expected_value P3)"
  stub minted_tag    "$(expected_value P1)" "$(expected_value P2)" "$CRASH"
  stub broken        "$REFUSED" "$REFUSED" "$REFUSED"

  for bad in tuple_emitted minted_tag broken; do
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
  echo "self-test passed: three defects seen, correct form accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         the validator's value, a hand-built value, and the record pattern agree on the bare tag"
