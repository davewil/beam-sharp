#!/usr/bin/env bash
#
# `float` IS A PART BESIDE `int`, NOTHING FLOWS BETWEEN THEM, AND `/` LOWERS BY
# ITS OPERAND TYPES. Tickets 69, 80 and 81; F51.
#
# Three rules, each with a defect that fails in the quiet direction, which is
# why the self-test builds four stubs rather than one:
#
# THE LOWERING. `/` on two `int`s is `div` (38) and on two `float`s is the
# BEAM's `/`. Once floats exist the over-informed emitter lowers EVERY `/` to
# the BEAM's `/`, and `-7 / 2` changes from `-3` to `-3.5` in a program whose
# signature says `int` — 38's own trap, and one the checker cannot see because
# the emitter is downstream of it. P2 asserts the value in a module that also
# divides floats, so a lowering decided per module rather than per site fails
# it too.
#
# THE REFUSAL. A `float` beside an `int` at an operator is refused, naming the
# conversion (80). The failure is silent in the direction that matters: the
# BEAM promotes a mixed pair on its own, so a checker that let it through
# prints `3.0` and nothing tells the author the program says something the
# language does not. P3 asserts the refusal by the text a person reads, not
# the tag — F26's gate went red once for matching the tag.
#
# THE TOP. `term` contains the float again: a `term()` whose float part is
# empty stops being the top type, and every residual subtracted from it is
# wrong in the quiet direction (69's fourth measured fact). P4 passes a float
# through a function declared `term`, which the hollow top refuses.
#
# THE ZERO. A `0.0` head lowers to `+0.0`, so `Verdict(0.0)` matches the
# positive zero alone, as the platform does, and `erlc` prints no warning.
# `bsc` reports the compiler's warnings on its own stream, so a bare literal
# shows up as extra lines around P5's `:empty`.
#
# The lexer stub the issue names — `1..5` read as `1.` and `.5` — has no probe
# here: no B# form puts a digit before `..`, so the compiler's own boundary
# cannot reach it. `float_tests` asks the lexer directly.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place. Takes a directory so
# --self-test drives THIS code path against fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p1 p2 p3 p4 p5 p6
  p1="$(cat "$dir/P1.out")"; p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"; p4="$(cat "$dir/P4.out")"
  p5="$(cat "$dir/P5.out")"; p6="$(cat "$dir/P6.out")"

  [ "$p1" = "3.0" ] || \
    echo "P1: Mean([2, 4]) gave '$p1', wanted 3.0 — the ticket's program does not run"
  [ "$p2" = "-3" ] || \
    echo "P2: -7 / 2 gave '$p2', wanted -3 — a float means \`/\` on two ints reached the BEAM's /"
  case "$p3" in
    *"error"*"Float.FromInt"*) ;;
    *) echo "P3: a float beside an int at \`/\` was not refused naming the conversion (got '$p3')" ;;
  esac
  [ "$p4" = "1.5" ] || \
    echo "P4: a float through a \`term\` parameter gave '$p4', wanted 1.5 — the top does not hold the float"
  [ "$p5" = ":empty" ] || \
    echo "P5: Verdict(0.0) gave '$p5', wanted exactly :empty — extra lines are erlc's warning on a bare 0.0 head"
  case "$p6" in
    *"returns a value its signature does not declare"*) ;;
    *) echo "P6: Mean([]) -> 0 under a float signature was not refused (got '$p6')" ;;
  esac
}

## Each module gets a directory of its own NAME (F15), as `check-division.sh`
## learned by going red on `src/`.
probe() {
  local dir="$1"
  mkdir -p "$dir/Stats" "$dir/Mixed" "$dir/Top" "$dir/Bad"
  cat > "$dir/Stats/Stats.bs" <<'EOF'
module Stats

public float Mean(list<int> samples)

Mean([]) -> 0.0
Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))

public int Slash(int a, int b)

Slash(a, b) -> a / b

public atom Verdict(float mean)

Verdict(0.0) -> :empty
Verdict(_)   -> :some
EOF
  cat > "$dir/Mixed/Mixed.bs" <<'EOF'
module Mixed

public float Mean(list<int> samples)

Mean([]) -> 0.0
Mean(xs) -> Float.FromInt(List.Sum(xs)) / List.Length(xs)
EOF
  cat > "$dir/Top/Top.bs" <<'EOF'
module Top

public term Id(float f)

Id(f) -> f
EOF
  cat > "$dir/Bad/Bad.bs" <<'EOF'
module Bad

public float Mean(list<int> samples)

Mean([]) -> 0
Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))
EOF
  "$BSC" "$dir/Stats/Stats.bs" Mean '[2, 4]' > "$dir/P1.out" 2>&1 || true
  "$BSC" "$dir/Stats/Stats.bs" Slash -7 2    > "$dir/P2.out" 2>&1 || true
  "$BSC" "$dir/Mixed/Mixed.bs" Mean '[2, 4]' > "$dir/P3.out" 2>&1 || true
  "$BSC" "$dir/Top/Top.bs" Id 1.5            > "$dir/P4.out" 2>&1 || true
  "$BSC" "$dir/Stats/Stats.bs" Verdict 0.0   > "$dir/P5.out" 2>&1 || true
  "$BSC" "$dir/Bad/Bad.bs" Mean '[]'         > "$dir/P6.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form. The refusal texts in the
# stubs are the compiler's own sentences: P3's from `bs_diag`'s
# `mixed_operands` message, P6's from `return_not_declared`, and the warning
# in `bare_zero` is `erl_lint`'s `match_float_zero` as `bsc` relays it.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  MIXED='Mixed/Mixed.bs:6:39: error: `/` in Mean has a `float` on its left and an `int` on its right
  nothing converts between the two: write the conversion, `Float.FromInt(n)`,
  on the `int` side'
  BAD='Bad/Bad.bs:5:1: error: Mean returns a value its signature does not declare
  not covered by the declared return type:
    0'
  WARN='Stats.abstr:14:9: Warning: matching on the float 0.0 will no longer also match -0.0 in OTP 27.
:empty'
  stub() {
    mkdir -p "$W/$1"
    printf '%s' "$2" > "$W/$1/P1.out"; printf '%s' "$3" > "$W/$1/P2.out"
    printf '%s' "$4" > "$W/$1/P3.out"; printf '%s' "$5" > "$W/$1/P4.out"
    printf '%s' "$6" > "$W/$1/P5.out"; printf '%s' "$7" > "$W/$1/P6.out"
  }
  stub good       "3.0" "-3"   "$MIXED" "1.5" ":empty" "$BAD"
  stub float_div  "3.0" "-3.5" "$MIXED" "1.5" ":empty" "$BAD"
  stub no_refusal "3.0" "-3"   "3.0"    "1.5" ":empty" "$BAD"
  stub hollow_top "3.0" "-3"   "$MIXED" \
       'Top/Top.bs:5:1: error: Id returns a value its signature does not declare' ":empty" "$BAD"
  stub bare_zero  "3.0" "-3"   "$MIXED" "1.5" "$WARN"  "$BAD"

  for bad in float_div no_refusal hollow_top bare_zero; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT form was rejected -"; judge "$W/good"; fail=1
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
echo "  ok         float is a part beside int, nothing flows between them, / lowers by its operands"
