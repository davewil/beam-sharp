#!/usr/bin/env bash
#
# THE RESIDUAL IS A HEAD YOU CAN PASTE, AND UNTIL NOW NOTHING CHECKED IT.
#
# `README.md:26-28` — the compiler "hands back the clause head you have not
# written, IN THE SYNTAX YOU WOULD WRITE IT IN. That is the whole bet of the
# language." `LANGUAGE.md:348` and `:359` say the same in shorter words. Nothing
# tested any of it, and the defect has now been rediscovered three times:
# ticket 42 decided the interval spelling on 2026-08-15, ticket 43 §0 measured
# the printer still ignoring it on 2026-08-16, and ENG-263 filed it as new on
# 2026-08-27.
#
# WHY THIS GATE IS GREEN WHILE SIX OF TEN SHAPES ARE BROKEN.
#
# The printer is F29's job, not this gate's. A gate that simply demanded "every
# head pastes" would be red on master from the moment it landed until F29 ships,
# which is a gate nobody can act on and everybody learns to ignore. So the floor
# is an EXPECTED-VERDICT TABLE: every shape carries the verdict it produces
# today, and the gate is red if any shape moves IN EITHER DIRECTION. A shape
# that starts pasting is red exactly as loudly as a shape that stops, because
# both mean the table is now lying about the compiler.
#
# That makes F29's done-when concrete and checkable: F29 is finished when every
# entry in `expected` reads `clean`. Not "the gate is green" — it is green now.
#
# WHY `spelling` IS A VERDICT AND NOT A PASS.
#
# Three shapes COMPILE and are still wrong, and a pasteability gate that asked
# only "does it compile" would bless all three:
#
#   RecordUnion  `Which({ Kind: :'M.Invoice' })`  the hand-written minted tag.
#                `bs_parser.yrl:499-501` says writing it by hand "makes an
#                erasure detail load-bearing in source" — F22 exists to replace
#                exactly this spelling.
#   OpenList     `Shape([int])`                   `int` is lowercase in pattern
#                position, so it is a BINDER NAMED int, not a type. For
#                `list<int>` the declared parameter already constrains the
#                element, so the pasted clause behaves correctly and nothing
#                ever noticed. No filing had caught this row.
#   TopString    `Kind(string)`                   the same defect without a
#                list: any type the algebra cannot enumerate prints bare.
#
# The spelling test is a rule about the TEXT of the head, not a lookup keyed on
# the fixture's name. That is deliberate and the `over_informed` self-test stub
# is what holds it to it.
#
# WHY THE FLOOR IS A ROSTER AND NOT A COUNT.
#
# `check-language.sh` counts its blocks and never floors them, so `seq 1 0`
# iterates nothing and it exits 0 — a green run that looked at nothing. Here the
# ten shape names are written down, and a roster entry with no result in the run
# is a failure. A result with no roster entry is also a failure, which is the
# half that makes the gate read the head text rather than a table of names.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"
FIXTURES="$HERE/bin/fixtures/residual"

# The roster. A name here with no result in the run is red.
ROSTER="Atom Interval IntervalUnion RecordUnion RecordInList TupleNested OpenList BinTag TopString ManyHeads"

# ---------------------------------------------------------------------------
# expected — the table F29 empties. Every entry that is not `clean` is a
# defect the printer still has, recorded so that fixing it is visible.
# ---------------------------------------------------------------------------
expected() {
  case "$1" in
    Atom)           echo "clean" ;;
    Interval)       echo "syntax:.." ;;
    IntervalUnion)  echo "syntax:<=" ;;
    RecordUnion)    echo "spelling" ;;
    RecordInList)   echo "binds" ;;
    TupleNested)    echo "syntax:<=" ;;
    OpenList)       echo "spelling" ;;
    BinTag)         echo "syntax:|" ;;
    TopString)      echo "spelling" ;;
    ManyHeads)      echo "syntax:|" ;;
    *)              echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# refused_spelling — the preferred-form rule, as a property of the HEAD TEXT.
#
# Keyed on content so that an unfamiliar shape is still judged. A version that
# switched on the fixture name would pass every stub below except
# `over_informed`, which exists for precisely this.
# ---------------------------------------------------------------------------
refused_spelling() {
  local head="$1"
  # The minted tag, written out by hand. F22 replaced this spelling.
  case "$head" in
    *"Kind: :'"*) echo "the minted tag is written out by hand; F22's type-prefixed form is the spelling"; return ;;
  esac
  # A bare primitive type name standing in pattern position is a BINDER.
  if printf '%s' "$head" | grep -Eq '(^|[^A-Za-z0-9_])(int|string|binary|bool|float)([^A-Za-z0-9_]|$)'; then
    echo "a bare type name in pattern position is a binder, not a type"
    return
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# classify — one shape's verdict, from the paste-back result alone.
#
# `unrun` is not a nicety. This repo has shipped a check that asserted an
# absence against a run that never compiled, and an empty `.paste` looks
# identical whether the compiler said nothing or was never invoked. The exit
# status is what separates them, so it is recorded and read.
# ---------------------------------------------------------------------------
classify() {
  local dir="$1" shape="$2" rc out head
  if [ ! -f "$dir/$shape.rc" ]; then echo "unrun"; return; fi
  rc="$(cat "$dir/$shape.rc")"
  out="$(cat "$dir/$shape.paste" 2>/dev/null || true)"
  head="$(cat "$dir/$shape.head" 2>/dev/null || true)"

  if [ -z "$head" ]; then echo "nohead"; return; fi

  if [ "$rc" = "0" ]; then
    if [ -n "$out" ]; then echo "other"; return; fi
    if [ -n "$(refused_spelling "$head")" ]; then echo "spelling"; else echo "clean"; fi
    return
  fi

  # Non-zero. Empty output means the compiler never ran, NOT that it was happy.
  if [ -z "$out" ]; then echo "unrun"; return; fi
  case "$out" in
    *"twice in one head"*) echo "binds"; return ;;
  esac
  case "$out" in
    *"syntax error before:"*)
      # BSD sed has no \|, and bash 3.2 eats a quoted # inside $( ) — so the
      # token is cut with parameter expansion rather than a regex.
      local t="${out#*syntax error before: \'}"
      t="${t%%\'*}"
      echo "syntax:$t"
      return ;;
  esac
  echo "other"
}

# ---------------------------------------------------------------------------
# channels — `bs_diag.erl:1100-1101` says the prose and the term channel
# "cannot say different things". On CONTENT that is true. On COMPLETENESS it is
# false by design: the prose caps at three heads and appends `... (N more)`.
# Nothing tested either half. Only ManyHeads reaches the cap, which is why that
# fixture exists — without it this branch would ship never having run.
# ---------------------------------------------------------------------------
channels() {
  local dir="$1" shape="$2" t p more want
  [ -f "$dir/$shape.term" ] || { echo "$shape: no term channel captured"; return; }
  t="$(grep -c . "$dir/$shape.term" 2>/dev/null || echo 0)"
  p="$(grep -c . "$dir/$shape.prose" 2>/dev/null || echo 0)"
  more="$(cat "$dir/$shape.more" 2>/dev/null || true)"

  if [ "$t" -le 3 ]; then
    [ "$p" = "$t" ] || echo "$shape: prose shows $p head(s), the term channel carries $t"
    [ -z "$more" ] || echo "$shape: prose printed a '... ($more more)' line for only $t head(s)"
  else
    [ "$p" = "3" ] || echo "$shape: prose shows $p head(s) above the cap, expected 3"
    want=$((t - 3))
    [ "$more" = "$want" ] || echo "$shape: prose says '$more more', the term channel has $t of which $want are past the cap"
  fi
  # Content: the prose lines must be the term list's first p, verbatim.
  if [ "$p" -gt 0 ] && ! head -n "$p" "$dir/$shape.term" 2>/dev/null | diff -q - "$dir/$shape.prose" >/dev/null 2>&1; then
    echo "$shape: the prose heads are not the term channel's first $p verbatim"
  fi
}

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place, so --self-test drives
# THIS code and not a copy of it. Silence is a pass.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1" shape got want f base

  # The floor. A roster name with no result is red.
  for shape in $ROSTER; do
    if [ ! -f "$dir/$shape.rc" ] && [ ! -f "$dir/$shape.head" ]; then
      echo "$shape: in the roster and never measured"
      continue
    fi
    got="$(classify "$dir" "$shape")"
    want="$(expected "$shape")"
    if [ "$got" != "$want" ]; then
      echo "$shape: verdict is '$got', the table says '$want'"
      if [ "$want" != "clean" ] && [ "$got" = "clean" ]; then
        echo "    ^ this shape now PASTES. If F29 fixed it, set its entry to 'clean' in the same commit."
      fi
    fi
    channels "$dir" "$shape"
  done

  # The other half of the floor: a result with no roster entry. Without this,
  # a verdict function that is a lookup table on shape names passes everything.
  for f in "$dir"/*.head; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .head)"
    case " $ROSTER " in
      *" $base "*) ;;
      *) echo "$base: measured but not in the roster (verdict '$(classify "$dir" "$base")') - add it or remove the fixture" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# probe — run the corpus and record what it said. Fixtures are copied out
# because the paste-back appends to the source.
# ---------------------------------------------------------------------------
probe() {
  local dir="$1" shape src out head
  for shape in $ROSTER; do
    [ -d "$FIXTURES/$shape" ] || { echo "missing fixture: $FIXTURES/$shape" >&2; continue; }
    rm -rf "$dir/src/$shape"
    mkdir -p "$dir/src/$shape"
    cp -R "$FIXTURES/$shape" "$dir/src/$shape/"
    src="$dir/src/$shape/$shape/$shape.bs"

    # Term channel: every pasteable head, one per line. Extracted by matching
    # the quoted head strings rather than by bracket-balancing, because a head
    # can itself contain `]`.
    "$BSC" --diagnostics term "$src" 2>&1 \
      | grep -o '"[A-Za-z_][A-Za-z0-9_]*([^"]*) -> \.\.\."' \
      | sed 's/^"//; s/"$//' > "$dir/$shape.term" || true

    # Prose channel: the head lines, and the cap line if there is one.
    out="$("$BSC" "$src" 2>&1 || true)"
    printf '%s\n' "$out" | grep -- '-> \.\.\.$' | sed 's/^ *//' > "$dir/$shape.prose" || true
    printf '%s\n' "$out" | sed -n 's/^ *\.\.\. (\([0-9][0-9]*\) more)$/\1/p' > "$dir/$shape.more" || true

    head="$(head -n 1 "$dir/$shape.term" 2>/dev/null || true)"
    printf '%s' "$head" > "$dir/$shape.head"
    [ -n "$head" ] || continue

    # Paste it back with a real body. Every fixture returns `atom`, so one body
    # serves all of them.
    printf '%s\n' "$head" | sed 's/-> \.\.\./-> :pasted/' >> "$src"
    out="$("$BSC" "$src" 2>&1)"
    printf '%s' "$?" > "$dir/$shape.rc"
    printf '%s' "$out" > "$dir/$shape.paste"
  done
}

# ---------------------------------------------------------------------------
# --self-test — four defects and one correct form, over fabricated text, with
# no compiler involved. A check that fires on everything passes the red half
# and is worthless, so the green half is not optional.
#
#   type_notation  a shape the table calls `clean` starts printing type
#                  notation. The plain regression.
#   silent         the run measured almost nothing. The roster floor is the
#                  only thing that catches this, and it is the failure
#                  check-language.sh actually has.
#   cry_wolf       a paste-back that NEVER RAN, reported as clean: empty output
#                  with a non-zero status. Without the rc channel this is
#                  indistinguishable from success and the gate is decorative.
#   over_informed  every roster shape correct, plus one shape the table has
#                  never heard of whose head is type notation. A verdict
#                  function keyed on fixture names says nothing here.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  fail=0

  # one/1 — a single-head shape: head, paste output, rc.
  one() { # one DIR SHAPE HEAD PASTE RC
    local d="$W/$1"; mkdir -p "$d"
    printf '%s' "$3" > "$d/$2.head"
    printf '%s\n' "$3" > "$d/$2.term"
    printf '%s\n' "$3" > "$d/$2.prose"
    : > "$d/$2.more"
    printf '%s' "$4" > "$d/$2.paste"
    printf '%s' "$5" > "$d/$2.rc"
  }
  # many/1 — the capped shape: five heads in the term channel, three in prose.
  many() { # many DIR
    local d="$W/$1"; mkdir -p "$d"
    cat > "$d/ManyHeads.term" <<'T'
Trip(:a3, :b1 | :b2 | :b3, :c1 | :c2 | :c3) -> ...
Trip(:a2, :b1 | :b3, :c1 | :c2 | :c3) -> ...
Trip(:a2, :b2, :c1 | :c3) -> ...
Trip(:a1, :b1, :c2 | :c3) -> ...
Trip(:a1, :b2 | :b3, :c1 | :c2 | :c3) -> ...
T
    head -n 3 "$d/ManyHeads.term" > "$d/ManyHeads.prose"
    printf '2' > "$d/ManyHeads.more"
    head -n 1 "$d/ManyHeads.term" | tr -d '\n' > "$d/ManyHeads.head"
    printf '%s' "x.bs:9: error: syntax error before: '|'" > "$d/ManyHeads.paste"
    printf '1' > "$d/ManyHeads.rc"
  }

  SY_DD="x.bs:7: error: syntax error before: '..'"
  SY_LE="x.bs:7: error: syntax error before: '<='"
  SY_OR="x.bs:9: error: syntax error before: '|'"
  BINDS="x.bs:7: error: Ship binds int twice in one head"

  # The correct form: today's table, exactly.
  today() { # today DIR
    one "$1" Atom          "Name(:blue) -> ..."                                  ""       0
    one "$1" Interval      "Big(0..128) -> ..."                                  "$SY_DD" 1
    one "$1" IntervalUnion "Classify(int <= 199 | 300..399) -> ..."              "$SY_LE" 1
    one "$1" RecordUnion   "Which({ Kind: :'RecordUnion.Invoice' }) -> ..."      ""       0
    one "$1" RecordInList  "Ship([{ Kind: :'M.Order', Id: int, Total: int }, ..]) -> ..." "$BINDS" 1
    one "$1" TupleNested   "Step((:ok, int <= 0)) -> ..."                        "$SY_LE" 1
    one "$1" OpenList      "Shape([int]) -> ..."                                 ""       0
    one "$1" BinTag        "Classify(0 | 4..255) -> ..."                         "$SY_OR" 1
    one "$1" TopString     "Kind(string) -> ..."                                 ""       0
    many "$1"
  }

  today good

  today type_notation
  one type_notation Atom "Name(int <= 5) -> ..." "" 0

  mkdir -p "$W/silent"
  one silent Atom "Name(:blue) -> ..." "" 0

  today cry_wolf
  one cry_wolf Interval "Big(0..128) -> ..." "" 2

  today over_informed
  one over_informed Extra "Extra(int) -> ..." "" 0

  for bad in type_notation silent cry_wolf over_informed; do
    if [ -z "$(judge "$W/$bad")" ]; then
      echo "  x SELF-TEST: '$bad' produced no complaint - the gate cannot see it"; fail=1
    else
      echo "  ok red on $bad"
    fi
  done
  if [ -n "$(judge "$W/good")" ]; then
    echo "  x SELF-TEST: today's table was rejected -"; judge "$W/good"; fail=1
  else
    echo "  ok green on the correct form"
  fi
  [ "$fail" -eq 0 ] || { echo "self-test FAILED"; exit 1; }
  echo "self-test passed: four defects seen, today's table accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
[ -d "$FIXTURES" ] || { echo "no fixture corpus at $FIXTURES"; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then
  echo "$out"
  echo
  echo "the residual round-trip moved. Every shape's verdict is written down in"
  echo "\`expected\` in this script; if the printer changed, change the table with it."
  exit 1
fi
echo "  ok         10 residual shapes round-tripped, each to the verdict recorded for it"
echo "             (4 clean-or-spelling, 6 refused - F29 is done when all ten read 'clean')"
