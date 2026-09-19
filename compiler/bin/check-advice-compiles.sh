#!/usr/bin/env bash
#
# A REFUSAL'S ADVICE MUST BE A PROGRAM THAT COMPILES. Tickets 83 and 84; F53.
#
# Ticket 83 refuses an `int | float` operand at an operator, and the only
# correct advice it can give is "dispatch the parts" — ticket 84's type prefix,
# `Post(float a)`. The two ship together for one reason: `mixed_operands`, the
# refusal next door, advises the author to write the int literal as a float
# (`write 0.0`), and over a union THAT SPELLING IS REFUSED TOO by the symmetry
# of ticket 80's no-flow rule. A refusal printing it would be telling the author
# to write a program the same compiler rejects.
#
# THIS HAS SHIPPED ONCE ALREADY. F19's refusal recommended a workaround that
# carried the exact lie the refusal existed to prevent, and nothing was looking.
# The suite cannot catch it either: a unit test asserts the WORDS of the advice,
# and words that read well are precisely what the defect looks like.
#
# So this gate does what an author does. It compiles the refused program, reads
# the clause heads out of the diagnostic the compiler printed, PASTES THEM INTO
# A PROGRAM, and compiles that. Green means the advice is a program. Red means
# the compiler is giving instructions it will not accept.
#
# WHY THE TEXT RULES SIT BESIDE THE PASTE-BACK. Two of them, and each names a
# spelling this feature's own answer refuses:
#
#   `0.0`             the int literal's float spelling — `a < 0.0` over an
#                     `int | float` compiles TODAY and is refused under 83.
#   `Float.FromInt`   the conversion, which converts a VALUE and cannot convert
#                     a union's part: there is no int in hand to convert.
#
# Both are right in `mixed_operands`' own case, where one side is one literal,
# and wrong here. A gate that only pasted would bless advice that compiled by
# accident while still sending the author down a road the language closed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# derive — the step that makes this a gate rather than a spell-check.
#
# Reads the advice text, lifts every line shaped like a clause head with an
# elided body, and writes the program an author would have after following it.
# Used by the probe against the real compiler AND by --self-test against
# fabricated advice, so both drive this code path rather than a copy of it.
# ---------------------------------------------------------------------------
derive() {
  local advice="$1" dir="$2"
  mkdir -p "$dir/Pence"
  {
    echo "module Pence"
    echo
    echo "public int Owed(int | float amount)"
    echo
    # `Owed(int n)   -> ...` becomes `Owed(int n) -> 0`. The body is the gate's,
    # because the diagnostic elides it — what is under test is the HEAD.
    sed -n 's/^[[:space:]]*\(Owed(.*)\)[[:space:]]*->[[:space:]]*\.\.\..*$/\1 -> 0/p' "$advice"
  } > "$dir/Pence/Pence.bs"
  grep -c '^Owed' "$dir/Pence/Pence.bs" > "$dir/heads.count" || true
  "$BSC" "$dir/Pence/Pence.bs" Owed 250 > "$dir/derived.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" advice derived heads table
  advice="$(cat "$dir/advice.txt")"
  derived="$(cat "$dir/derived.out")"
  heads="$(cat "$dir/heads.count" 2>/dev/null || echo 0)"
  table="$(cat "$dir/table.out" 2>/dev/null || echo "")"

  case "$advice" in
    *"error"*) ;;
    *) echo "A1: the union operand at an operator was not refused at all (got '$advice')" ;;
  esac

  # One head per part, or the advice is not a dispatch. A single head leaves the
  # other part uncovered, which the paste-back below then reports as
  # inexhaustive — asserted here too, so the reason is named rather than
  # inferred from a compile failure.
  [ "${heads:-0}" -ge 2 ] || \
    echo "A2: the advice named $heads clause head(s); a dispatch over two parts needs two"

  case "$advice" in
    *"0.0"*) echo "A3: the advice offers the float literal spelling, which ticket 83 refuses over a union" ;;
  esac
  case "$advice" in
    *"Float.FromInt"*) echo "A4: the advice offers the conversion, which has no value in hand to convert" ;;
  esac

  # THE PASTE-BACK. The derived program must compile and RUN: a program that
  # compiles and crashes is not advice either. `0` is the body `derive` wrote,
  # so this says "the heads the compiler printed are a function" and nothing
  # about what it computes — A6 below is where the behaviour is asserted.
  [ "$derived" = "0" ] || \
    echo "A5: the advised program did not compile and run (got '$derived', wanted 0)"

  # Ticket 83's own table, on the dispatch the advice names: the £2.50 refund
  # that posted as a debit is the defect this whole feature exists to close.
  [ -z "$table" ] || [ "$table" = ":credit" ] || \
    echo "A6: Post(-2.50) gave '$table', wanted :credit — the float part is not reaching its clause"
}

probe() {
  local dir="$1"
  mkdir -p "$dir/Owed" "$dir/Ledger"
  cat > "$dir/Owed/Owed.bs" <<'EOF'
module Owed

public int Owed(int | float amount)

Owed(a) -> a * 100
EOF
  "$BSC" "$dir/Owed/Owed.bs" Owed 250 > "$dir/advice.txt" 2>&1 || true
  derive "$dir/advice.txt" "$dir"

  cat > "$dir/Ledger/Ledger.bs" <<'EOF'
module Ledger

type Side = :debit | :credit

public Side Post(int | float amount)

Post(int a)   when a < 0   -> :credit
Post(int a)                -> :debit
Post(float f) when f < 0.0 -> :credit
Post(float f)              -> :debit
EOF
  "$BSC" "$dir/Ledger/Ledger.bs" Post -2.50 > "$dir/table.out" 2>&1 || true
}

# ---------------------------------------------------------------------------
# --self-test — four fabricated advices, three of them defective, one correct.
#
# THE STUBS ARE ADVICE TEXTS AND THE DERIVATION IS REAL. Each stub goes through
# `derive` and is compiled by the built `bsc`, so a red here is a program the
# compiler actually refused rather than a string this script disliked. That is
# what makes `plausible` the sharp one: it reads like help, names a form C# and
# TypeScript really have, and does not parse.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  [ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  stub() {
    local name="$1" advice="$2"
    mkdir -p "$W/$name"
    printf '%s\n' "$advice" > "$W/$name/advice.txt"
    derive "$W/$name/advice.txt" "$W/$name"
    printf '%s' ":credit" > "$W/$name/table.out"
  }

  stub good 'Owed/Owed.bs:5:12: error: `*` in Owed has `int | float` on its left
  a union whose parts are all numeric is the mixed pair wherever one part
  would be. Dispatch the parts in the head and write the operator where the
  part is known:
    Owed(int n)   -> ...
    Owed(float f) -> ...'

  # The advice `mixed_operands` gives in its own case, which is refused here.
  stub literal 'Owed/Owed.bs:5:12: error: `*` in Owed has an `int` on its left and a `float` on its right
  nothing converts between the two: write the conversion, `Float.FromInt(n)`,
  on the `int` side, or write `100.0` to make the literal a float'

  # Half a dispatch: it compiles as far as the parser and leaves `float`
  # uncovered, so the paste-back reports inexhaustive.
  stub half 'Owed/Owed.bs:5:12: error: `*` in Owed has `int | float` on its left
  dispatch the part:
    Owed(int n) -> ...'

  # F19'S OWN SHAPE. Reads like help, names the type test C# and TypeScript
  # both have, and is a syntax error in B#.
  stub plausible 'Owed/Owed.bs:5:12: error: `*` in Owed has `int | float` on its left
  test the part in a guard and write the operator there:
    Owed(a) when a is int -> ...
    Owed(a) when a is float -> ...'

  for bad in literal half plausible; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: the CORRECT advice was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct advice"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: three defective advices seen, the dispatch accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "  ok         the numeric-union refusal's advice is a program that compiles and runs"
