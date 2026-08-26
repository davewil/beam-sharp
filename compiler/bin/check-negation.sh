#!/usr/bin/env bash
#
# THERE IS NO `not`, AND A READER WHO TYPES ONE IS TOLD WHAT TO WRITE INSTEAD.
#
# Ticket 63 refused negation on REDUNDANCY, not on danger: everywhere the
# checker can read a guard, `alternatives/1`'s fragment is already closed under
# complement, so a `not` it had learned would compile into the exact spelling
# the author could have written. The decision came with an obligation attached —
# the absence teaches rather than merely refuses — and this gate is that
# obligation.
#
# WHY THE WORD IS NOT RESERVED, WHICH IS THE DEFECT THE CONTROL EXISTS FOR.
# `not` is a legal identifier today: `Classify(not) when not > 100` compiles and
# runs. Making it a keyword would be the cheap way to get a sharp message, and
# it would silently take a name out of the language — which is ticket 65's
# question, not this ticket's, and 65 is open. So the hint is raised at the
# PARSE-FAILURE site, where it cannot reach a program that parses. P4 is the
# probe that fails if a later session reaches for the keyword instead.
#
# WHY THREE POSITIVE PROBES AND NOT ONE. The two positions David's answer covers
# fail at DIFFERENT tokens, and a rule keyed on the token the parser reported
# would pass P1 and miss P2 entirely:
#
#     when not (n > 100)               -> syntax error before: '('
#     int where not (value > 100)      -> syntax error before: '>'
#
# The ticket's own argument that guards and refinements cannot disagree is about
# `alternatives/1` in the CHECKER — it does not transfer to the parser, which is
# where this hint lives. So the refinement position is asserted, not inherited.
# P3 is the third spelling: `!` fails in the LEXER, not the parser, and the map's
# audience note says a C#/TS reader reaches for it on sight.
#
# WHY AN ABSENCE IS ASSERTED TWICE. P4 and P5 are both "the message must NOT
# appear", and this repo has shipped a check that asserted an absence against a
# run that never compiled. P4 asserts it against a CLEAN COMPILE. P5 asserts it
# against an unrelated syntax error, because a hint that fires on every parse
# failure would satisfy P1-P3 and be worthless.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

TEACH="negation is not an operator here"

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place, so --self-test drives
# THIS code path against fixtures rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" p1 p2 p3 p4 p5
  p1="$(cat "$dir/P1.out")"; p2="$(cat "$dir/P2.out")"; p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"; p5="$(cat "$dir/P5.out")"

  case "$p1" in
    *"$TEACH"*) ;;
    *) echo "P1: \`not\` in a GUARD was not taught (got '$p1')" ;;
  esac
  case "$p2" in
    *"$TEACH"*) ;;
    *) echo "P2: \`not\` in a REFINEMENT was not taught (got '$p2') — this position fails at a different token than P1, so it must be asserted separately" ;;
  esac
  case "$p3" in
    *"$TEACH"*) ;;
    *) echo "P3: a bare \`!\` was not taught (got '$p3') — this one fails in the lexer, not the parser" ;;
  esac
  ## The two absences. P4 is the reserved-word control: `not` is a legal
  ## identifier and must stay one until ticket 65 says otherwise.
  ## EXACT, not a substring. A diagnostic about this program would itself
  ## contain `:small`, so a substring match here is green against a module that
  ## never compiled — which is what the first draft did.
  case "$p4" in
    *"$TEACH"*) echo "P4: the hint fired on a program that COMPILES (got '$p4')" ;;
    ":small") ;;
    *) echo "P4: \`not\` is no longer a working identifier (got '$p4', wanted exactly ':small') — either the word was reserved, which is ticket 65's decision and not this one's, or the program did not compile at all" ;;
  esac
  case "$p5" in
    *"$TEACH"*) echo "P5: the hint fired on an UNRELATED syntax error (got '$p5') — it is keyed on parse failure alone, not on \`not\`" ;;
    *) ;;
  esac
}

probe() {
  local dir="$1"
  mkdir -p "$dir/G" "$dir/R" "$dir/B" "$dir/K" "$dir/U"
  # P1 — `not` in a guard. Fails before '('.
  printf 'module G\n\npublic :atom Go(int n)\nGo(n) when not (n > 100) -> :small\nGo(n) -> :big\n' > "$dir/G/G.bs"
  # P2 — `not` in a refinement. Fails before '>'.
  printf 'module R\n\ntype S = int where not (value > 100)\n\npublic :atom Go(S n)\nGo(n) -> :small\n' > "$dir/R/R.bs"
  # P3 — the C#/TS spelling. Fails in the lexer.
  printf 'module B\n\npublic :atom Go(int n)\nGo(n) when !n -> :small\nGo(n) -> :big\n' > "$dir/B/B.bs"
  # P4 — THE CONTROL. `not` as an ordinary identifier; this compiles and RUNS,
  # and the probe below asserts the value it returns. The first draft declared
  # `public :atom Go(...)`, which does not cover `:big` — so P4 held a
  # return-type diagnostic whose own text contains `:small`, and a substring
  # match on it went green against a module that never compiled. That is this
  # repo's oldest recurring defect and it reappeared here inside the gate
  # written to prevent it.
  printf 'module K\n\ntype Size = :big | :small\n\npublic Size Go(int not)\nGo(not) when not > 100 -> :big\nGo(not) -> :small\n' > "$dir/K/K.bs"
  # P5 — an unrelated syntax error, with no `not` anywhere in the file.
  printf 'module U\n\npublic :atom Go(int n)\nGo(n) when n > -> :small\nGo(n) -> :big\n' > "$dir/U/U.bs"
  "$BSC" "$dir/G/G.bs" Go 5 > "$dir/P1.out" 2>&1 || true
  "$BSC" "$dir/R/R.bs" Go 5 > "$dir/P2.out" 2>&1 || true
  "$BSC" "$dir/B/B.bs" Go 5 > "$dir/P3.out" 2>&1 || true
  "$BSC" "$dir/K/K.bs" Go 5 > "$dir/P4.out" 2>&1 || true
  "$BSC" "$dir/U/U.bs" Go 5 > "$dir/P5.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form. A check that fires on
# everything passes the red half and is worthless, so the green half is not
# optional.
#
#   silent    nothing teaches — the plain "we never built it" failure
#   half      guards taught, refinements missed — the defect a token-keyed
#             rule actually produces, and the reason P2 exists
#   reserved  `not` became a keyword: P1-P3 teach, and P4 stops compiling
#   cry_wolf  every parse failure teaches, including the unrelated one
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0
  T="error: beam-sharp has no \`not\`
  $TEACH"
  RAW1="G.bs:4: error: syntax error before: '('"
  RAW2="R.bs:3: error: syntax error before: '>'"
  RAW3="B.bs:4: error: illegal characters \"!n\""
  RAW5="U.bs:4: error: syntax error before: '->'"
  stub() {
    mkdir -p "$W/$1"
    printf '%s' "$2" > "$W/$1/P1.out"; printf '%s' "$3" > "$W/$1/P2.out"
    printf '%s' "$4" > "$W/$1/P3.out"; printf '%s' "$5" > "$W/$1/P4.out"
    printf '%s' "$6" > "$W/$1/P5.out"
  }
  stub good     "$T"   "$T"   "$T"   ":small" "$RAW5"
  stub silent   "$RAW1" "$RAW2" "$RAW3" ":small" "$RAW5"
  stub half     "$T"   "$RAW2" "$T"   ":small" "$RAW5"
  stub reserved "$T"   "$T"   "$T"   "K.bs:3: error: syntax error before: 'not'" "$RAW5"
  stub cry_wolf "$T"   "$T"   "$T"   ":small" "$T"

  for bad in silent half reserved cry_wolf; do
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
echo "  ok         no \`not\` and no \`!\`, both taught in guard and refinement; \`not\` is still an identifier"
