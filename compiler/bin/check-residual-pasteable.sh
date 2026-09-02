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
# WHY THIS GATE WAS GREEN WHILE SIX OF TEN SHAPES WERE BROKEN.
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
# WHY THE PASTE-BACK IS EVERY HEAD AND NOT THE FIRST. Corrected 2026-08-27 when
# F29 landed.
#
# This script was built pasting `head -n 1` back and demanding rc 0 from it,
# while `channels()` two functions below asserts that `ManyHeads` carries FIVE
# term heads and a `... (2 more)` prose line. Those two cannot both be satisfied
# by any correct compiler: one of five heads leaves the other four uncovered, so
# the function is still inexhaustive and the paste-back cannot exit 0.
#
# The contradiction was unreachable before F29 and that is why it shipped. The
# old printer `|`-joined a residual's parts into ONE line, and that line did not
# parse — so every multi-head shape stopped at `syntax:|` and the rc-0 demand was
# never exercised against a head that compiles. F29.2 splits the parts onto their
# own lines because a clause head has no `|`, and the first head then covers only
# the first part.
#
# So the paste-back is the WHOLE suggestion. That is also what an author does
# with it: the diagnostic says "no clause matches" and lists the clauses, and
# writing one of them down is not the fix. `refused_spelling` runs over every
# head for the same reason — a shape whose second head is type notation and whose
# first is clean would otherwise go green, which is the `over_informed` stub's
# defect one level down.
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
EXAMPLES="$HERE/examples"

# The roster. A name here with no result in the run is red.
ROSTER="Atom Interval IntervalUnion RecordUnion RecordInList TupleNested OpenList BinTag TopString ManyHeads WholeList"

# ---------------------------------------------------------------------------
# THE MUTATION STAGE — `examples/Wire`, one clause at a time (ENG-263, 2026-09-02).
#
# `wire.bs:15` has said since F2 that deleting `Classify(>= 4 and <= 7)` makes
# the compiler hand "the same line straight back". The fixtures above prove the
# printer's spelling shape by shape; nothing ran that sentence against the file
# it is written in, and it went false once already — TOUR.md told the reader to
# delete a `4..7` clause that F29 had respelled, and the two files disagreed
# for days about which spelling was the refused one.
#
# So every `Classify` clause in `wire.bs` is deleted in turn, the residual read
# off the term channel, and the head pasted back with the clause's own body.
# Two verdicts are correct, and the table below says which clause earns which:
#
#   same        one head, and it IS the deleted line — the sentence at wire.bs:15
#   respelled:H one head, pastes clean, but the compiler spelled it H rather
#               than the line deleted. `Classify(>= 9)` comes back with the
#               domain's top on it, `>= 9 and <= 255`, because the residual is
#               computed from `Octet` and not from the clause that used to be
#               there. Correct, and not the same line.
#
# Everything else is red: `split` (the residual came back as several heads),
# `nohead`, `refused` (the paste-back did not compile), `unrun`. The roster is
# the clause list itself, so a clause added to or removed from `wire.bs` is red
# until this table says what it should do.
# ---------------------------------------------------------------------------
WIRE="$HERE/examples/Wire/wire.bs"
WIRE_ROSTER='Classify(1)
Classify(2)
Classify(3)
Classify(8)
Classify(0)
Classify(>= 4 and <= 7)
Classify(>= 9)'

wire_expected() {
  case "$1" in
    "Classify(>= 9)") echo "respelled:Classify(>= 9 and <= 255) -> ..." ;;
    *)                echo "same" ;;
  esac
}

# classify_wire DIR K — one deleted clause's verdict, from the recorded files.
classify_wire() {
  local dir="$1" k="$2" deleted n rc out head
  [ -f "$dir/wire/c$k.deleted" ] || { echo "unrun"; return; }
  deleted="$(cat "$dir/wire/c$k.deleted")"
  n="$(grep -c . "$dir/wire/c$k.term" 2>/dev/null || true)"
  [ -n "$n" ] || n=0
  if [ "$n" -eq 0 ]; then echo "nohead"; return; fi
  if [ "$n" -gt 1 ]; then echo "split"; return; fi
  [ -f "$dir/wire/c$k.rc" ] || { echo "unrun"; return; }
  rc="$(cat "$dir/wire/c$k.rc")"
  out="$(cat "$dir/wire/c$k.paste" 2>/dev/null || true)"
  if [ "$rc" != "0" ]; then
    if [ -z "$out" ]; then echo "unrun"; else echo "refused"; fi
    return
  fi
  head="$(cat "$dir/wire/c$k.term")"
  if [ "$head" = "$deleted -> ..." ]; then echo "same"; else echo "respelled:$head"; fi
}

# judge_wire DIR — the stage's opinion. Silence is a pass. Both halves of the
# floor, as for the shapes: a roster clause never deleted, and a deleted clause
# the roster does not know.
judge_wire() {
  local dir="$1" h f k got want
  [ -d "$dir/wire" ] || { echo "Wire: the mutation stage never ran"; return; }
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    f="$(grep -lxF -- "$h" "$dir"/wire/c*.deleted 2>/dev/null | head -n 1)"
    if [ -z "$f" ]; then echo "Wire $h: in the roster and never deleted"; continue; fi
    k="$(basename "$f" .deleted)"; k="${k#c}"
    got="$(classify_wire "$dir" "$k")"
    want="$(wire_expected "$h")"
    [ "$got" = "$want" ] || echo "Wire $h: deleted, the verdict is '$got', the table says '$want'"
  done <<< "$WIRE_ROSTER"
  for f in "$dir"/wire/c*.deleted; do
    [ -e "$f" ] || continue
    h="$(cat "$f")"
    grep -qxF -- "$h" <<< "$WIRE_ROSTER" \
      || echo "Wire $h: deleted but not in the roster - wire.bs gained a Classify clause; say what it should do"
  done
}

# probe_wire DIR — delete each clause in a copy, record the residual and the
# paste-back. The clause's own body goes back with the head: `Classify` returns
# `FrameType`, so the fixtures' `:pasted` body would be a type error here.
probe_wire() {
  local dir="$1" k=0 entry ln line head body root out rc
  mkdir -p "$dir/wire"
  grep -n '^Classify(' "$WIRE" > "$dir/wire/clauses"
  while IFS= read -r entry; do
    k=$((k + 1))
    ln="${entry%%:*}"; line="${entry#*:}"
    head="$(printf '%s' "${line%%->*}" | tr -s '[:blank:]' ' ' | sed 's/ *$//')"
    body="$(printf '%s' "${line#*->}" | sed 's/^ *//; s/ *$//')"
    printf '%s\n' "$head" > "$dir/wire/c$k.deleted"
    root="$dir/wire/c$k"
    rm -rf "$root"; mkdir -p "$root"
    cp -R "$HERE/examples" "$root/examples"
    sed "${ln}d" "$WIRE" > "$root/examples/Wire/wire.bs"
    (cd "$root" && "$BSC" --diagnostics term --src-root examples examples/Wire 2>&1) \
      | grep -o '"[A-Za-z_][A-Za-z0-9_]*([^"]* -> \.\.\."' \
      | sed 's/^"//; s/"$//' > "$dir/wire/c$k.term" || true
    [ -s "$dir/wire/c$k.term" ] || continue
    sed "s/-> \.\.\./-> $body/" "$dir/wire/c$k.term" >> "$root/examples/Wire/wire.bs"
    out="$(cd "$root" && "$BSC" --src-root examples examples/Wire 2>&1)"; rc=$?
    printf '%s' "$rc" > "$dir/wire/c$k.rc"
    printf '%s' "$out" > "$dir/wire/c$k.paste"
  done < "$dir/wire/clauses"
}

# ---------------------------------------------------------------------------
# expected — the table F29 empties. Every entry that is not `clean` is a
# defect the printer still has, recorded so that fixing it is visible.
# ---------------------------------------------------------------------------
expected() {
  case "$1" in
    Atom)           echo "clean" ;;
    Interval)       echo "clean" ;;
    IntervalUnion)  echo "clean" ;;
    RecordUnion)    echo "clean" ;;
    RecordInList)   echo "clean" ;;
    TupleNested)    echo "clean" ;;
    OpenList)       echo "clean" ;;
    BinTag)         echo "clean" ;;
    TopString)      echo "clean" ;;
    ManyHeads)      echo "clean" ;;
    WholeList)      echo "clean" ;;
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
  local dir="$1" shape="$2" rc out head h
  if [ ! -f "$dir/$shape.rc" ]; then echo "unrun"; return; fi
  rc="$(cat "$dir/$shape.rc")"
  out="$(cat "$dir/$shape.paste" 2>/dev/null || true)"
  head="$(cat "$dir/$shape.head" 2>/dev/null || true)"

  if [ -z "$head" ]; then echo "nohead"; return; fi

  if [ "$rc" = "0" ]; then
    if [ -n "$out" ]; then echo "other"; return; fi
    # EVERY head, not the first. A suggestion is only as good as its worst line.
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      if [ -n "$(refused_spelling "$h")" ]; then echo "spelling"; return; fi
    done < "$dir/$shape.term"
    echo "clean"
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
  # `grep -c` PRINTS 0 AND EXITS 1 on no match, so `|| echo 0` appended a second
  # zero and every arithmetic test below took a two-line string. Found 2026-08-27
  # when an empty term channel reached it for the first time.
  t="$(grep -c . "$dir/$shape.term" 2>/dev/null || true)"
  p="$(grep -c . "$dir/$shape.prose" 2>/dev/null || true)"
  [ -n "$t" ] || t=0
  [ -n "$p" ] || p=0
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

  judge_wire "$dir"
  judge_promise "$dir"
}

# ---------------------------------------------------------------------------
# THE PROMISE STAGE — the sentence, not just the behaviour (ENG-263, 2026-09-02).
#
# The Wire stage above runs `wire.bs:15`'s CLAIM. It does not read the sentence,
# and a stage that checks behaviour cannot see a stale one. `shop.bs:22` is the
# proof: it promised the compiler writes
#
#     Which({ Kind: :'Shop.Invoice' }) -> ...
#
# against a compiler that writes `Which(Invoice i) -> ...`. It quoted the
# hand-written minted tag — the form ticket 55 calls "the one place the surface
# makes an erasure detail load-bearing", and the one `refused_spelling` above
# rejects when the PRINTER emits it. Nothing applied that judgement to prose,
# and the Wire stage could not: it never reads a comment, and never touches Shop.
#
# So an entry here is a THREE-WAY agreement, and any two of the three parting
# company is red:
#
#   the compiler   the residual head produced when the clause is deleted
#   this table     `promise_head`, the head both of the others must carry
#   the comment    the promise in the source, which is what a reader believes
#
# WHY THE PROMISE IS READ FROM COMMENT LINES ONLY.
#
# `Classify(>= 4 and <= 7)` occurs TWICE in `wire.bs` — at `:15` in the comment
# and at `:49` as a clause. A whole-file search for the promise matches the
# clause, so it would pass with the comment deleted outright, and the half of
# this stage that is its whole point would ship never having been exercised.
# `promise_unclaimed` below is the stub that holds this to it.
# ---------------------------------------------------------------------------
PROMISES="Wire Shop"

promise_file()   { case "$1" in Wire) echo "Wire/wire.bs" ;; Shop) echo "Shop/shop.bs" ;; *) echo "" ;; esac; }
promise_module() { case "$1" in Wire) echo "Wire" ;;         Shop) echo "Shop" ;;         *) echo "" ;; esac; }

# The clause deleted, matched as a LITERAL PREFIX at column 1 — see probe_promise.
promise_clause() {
  case "$1" in
    Wire) echo "Classify(>= 4 and <= 7)" ;;
    Shop) echo "Which(Invoice i)" ;;
    *)    echo "" ;;
  esac
}

# The head the compiler must produce AND the source comment must promise.
promise_head() {
  case "$1" in
    Wire) echo "Classify(>= 4 and <= 7) -> ..." ;;
    Shop) echo "Which(Invoice i) -> ..." ;;
    *)    echo "" ;;
  esac
}

# The body pasted onto the suggested head. Not one body for both: `Classify`
# returns `FrameType`, a closed atom union, so an invented atom is a type error
# and the paste-back would go red for a reason that is not this stage's.
promise_body() {
  case "$1" in
    Wire) echo ":reserved" ;;
    Shop) echo ":invoice" ;;
    *)    echo "" ;;
  esac
}

expected_promise() { case "$1" in Wire|Shop) echo "clean" ;; *) echo "" ;; esac; }

# classify_promise DIR P — the order of the tests is the order of blame.
# `moved` outranks a paste failure because a head that is not the one promised
# is the finding whatever the paste then does; `unclaimed` outranks a clean
# paste because a comment that no longer describes the compiler is the defect
# this stage exists for.
classify_promise() {
  local dir="$1" p="$2" rc out head want claim n
  [ -f "$dir/promise/$p.rc" ] || { echo "unrun"; return; }
  rc="$(cat "$dir/promise/$p.rc")"
  out="$(cat "$dir/promise/$p.paste" 2>/dev/null || true)"
  head="$(cat "$dir/promise/$p.head" 2>/dev/null || true)"
  claim="$(cat "$dir/promise/$p.claim" 2>/dev/null || true)"
  want="$(promise_head "$p")"

  [ -n "$head" ] || { echo "nohead"; return; }
  n="$(grep -c . "$dir/promise/$p.term" 2>/dev/null || true)"
  [ -n "$n" ] || n=0
  [ "$n" = "1" ] || { echo "split:$n"; return; }
  [ "$head" = "$want" ]  || { echo "moved"; return; }
  [ "$claim" = "found" ] || { echo "unclaimed"; return; }

  if [ "$rc" = "0" ]; then
    [ -z "$out" ] || { echo "other"; return; }
    echo "clean"; return
  fi
  [ -n "$out" ] || { echo "unrun"; return; }
  case "$out" in *"twice in one head"*) echo "binds"; return ;; esac
  case "$out" in
    *"syntax error before:"*)
      local t="${out#*syntax error before: \'}"; t="${t%%\'*}"; echo "syntax:$t"; return ;;
  esac
  echo "other"
}

# judge_promise DIR — both halves of the floor, as everywhere else here.
judge_promise() {
  local dir="$1" p got want f base
  for p in $PROMISES; do
    if [ ! -f "$dir/promise/$p.rc" ] && [ ! -f "$dir/promise/$p.head" ]; then
      echo "$p: in the promise roster and never measured"
      continue
    fi
    got="$(classify_promise "$dir" "$p")"
    want="$(expected_promise "$p")"
    [ "$got" = "$want" ] && continue
    echo "$p: promise verdict is '$got', the table says '$want'"
    case "$got" in
      moved)
        echo "    ^ deleted \`$(promise_clause "$p")\` and the compiler suggested"
        echo "      '$(cat "$dir/promise/$p.head" 2>/dev/null || true)', not '$(promise_head "$p")'." ;;
      unclaimed)
        echo "    ^ the compiler is right and the PROSE is stale: no comment line in"
        echo "      examples/$(promise_file "$p") promises '$(promise_head "$p")'." ;;
    esac
  done
  for f in "$dir"/promise/*.head; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .head)"
    case " $PROMISES " in
      *" $base "*) ;;
      *) echo "$base: promise measured but not in the roster - add it or drop it" ;;
    esac
  done
}

# probe_promise DIR — the claim is read from the PRISTINE source, before the edit.
probe_promise() {
  local dir="$1" p file mod clause want src out head
  mkdir -p "$dir/promise"
  for p in $PROMISES; do
    file="$(promise_file "$p")"; mod="$(promise_module "$p")"
    clause="$(promise_clause "$p")"; want="$(promise_head "$p")"
    [ -f "$EXAMPLES/$file" ] || { echo "missing example: $EXAMPLES/$file" >&2; continue; }

    # Comment lines only. Compared without the ` -> ...` tail, because prose
    # quotes the head and not the arrow — `wire.bs:15` does exactly this.
    if grep '^//' "$EXAMPLES/$file" | grep -qF "${want% -> ...}"; then
      printf 'found' > "$dir/promise/$p.claim"
    else
      : > "$dir/promise/$p.claim"
    fi

    rm -rf "$dir/ex/$p"; mkdir -p "$dir/ex/$p"
    cp -R "$EXAMPLES/." "$dir/ex/$p/"
    src="$dir/ex/$p/$file"

    # A LITERAL PREFIX at column 1. `awk index($0,c)==1` rather than `grep -v`,
    # because the Shop clause carries `{`, `}` and a `.` that a basic regular
    # expression reads as metacharacters — and because anchoring is what keeps
    # the comment at `wire.bs:15`, which holds the same text, out of the cut.
    awk -v c="$clause" 'index($0, c) == 1 { next } { print }' "$src" > "$src.cut"
    mv "$src.cut" "$src"

    "$BSC" --diagnostics term --src-root "$dir/ex/$p" "$dir/ex/$p/$mod" 2>&1 \
      | grep -o '"[A-Za-z_][A-Za-z0-9_]*([^"]* -> \.\.\."' \
      | sed 's/^"//; s/"$//' > "$dir/promise/$p.term" || true

    head="$(head -n 1 "$dir/promise/$p.term" 2>/dev/null || true)"
    printf '%s' "$head" > "$dir/promise/$p.head"
    [ -n "$head" ] || continue

    sed "s/-> \.\.\./-> $(promise_body "$p")/" "$dir/promise/$p.term" >> "$src"
    out="$("$BSC" --src-root "$dir/ex/$p" "$dir/ex/$p/$mod" 2>&1)"
    printf '%s' "$?" > "$dir/promise/$p.rc"
    printf '%s' "$out" > "$dir/promise/$p.paste"
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
    #
    # ANCHORED ON THE ARROW, NOT ON A CLOSING PAREN. The first form of this
    # required `) -> ...`, which silently captured nothing the moment a head
    # carried a `when` clause — and F29 emits one wherever a span sits below
    # argument position, because a relational pattern is legal only at the top.
    # An empty capture reads as `unrun`, so the failure was at least loud.
    "$BSC" --diagnostics term "$src" 2>&1 \
      | grep -o '"[A-Za-z_][A-Za-z0-9_]*([^"]* -> \.\.\."' \
      | sed 's/^"//; s/"$//' > "$dir/$shape.term" || true

    # Prose channel: the head lines, and the cap line if there is one.
    out="$("$BSC" "$src" 2>&1 || true)"
    printf '%s\n' "$out" | grep -- '-> \.\.\.$' | sed 's/^ *//' > "$dir/$shape.prose" || true
    printf '%s\n' "$out" | sed -n 's/^ *\.\.\. (\([0-9][0-9]*\) more)$/\1/p' > "$dir/$shape.more" || true

    head="$(head -n 1 "$dir/$shape.term" 2>/dev/null || true)"
    printf '%s' "$head" > "$dir/$shape.head"
    [ -n "$head" ] || continue

    # Paste back the WHOLE suggestion — see the header. Every fixture returns
    # `atom`, so one body serves all of them.
    sed 's/-> \.\.\./-> :pasted/' "$dir/$shape.term" >> "$src"
    out="$("$BSC" "$src" 2>&1)"
    printf '%s' "$?" > "$dir/$shape.rc"
    printf '%s' "$out" > "$dir/$shape.paste"
  done
}

# ---------------------------------------------------------------------------
# --self-test — seven defects and one correct form, over fabricated text, with
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
  # two/1 — a shape whose residual is TWO heads. F29.2 made this the ordinary
  # case rather than the exceptional one, and a stub set that only ever built
  # single-head shapes could not drive the per-line spelling check.
  two() { # two DIR SHAPE HEAD1 HEAD2
    local d="$W/$1"; mkdir -p "$d"
    printf '%s\n%s\n' "$3" "$4" > "$d/$2.term"
    cp "$d/$2.term" "$d/$2.prose"
    : > "$d/$2.more"
    printf '%s' "$3" > "$d/$2.head"
    : > "$d/$2.paste"
    printf '0' > "$d/$2.rc"
  }
  # many/1 — the capped shape: five heads in the term channel, three in prose.
  many() { # many DIR
    local d="$W/$1"; mkdir -p "$d"
    cat > "$d/ManyHeads.term" <<'T'
Trip(:a3, :b1, :c1) -> ...
Trip(:a3, :b1, :c2) -> ...
Trip(:a3, :b1, :c3) -> ...
Trip(:a3, :b2, :c1) -> ...
Trip(:a3, :b2, :c2) -> ...
T
    head -n 3 "$d/ManyHeads.term" > "$d/ManyHeads.prose"
    printf '2' > "$d/ManyHeads.more"
    head -n 1 "$d/ManyHeads.term" | tr -d '\n' > "$d/ManyHeads.head"
    : > "$d/ManyHeads.paste"
    printf '0' > "$d/ManyHeads.rc"
  }

  # The two failures the printer used to produce, kept as stubs rather than
  # deleted with the table entries that used to expect them. Every row reads
  # `clean` now, so nothing in `today` reaches `classify`'s syntax or binder
  # branches — and a verdict branch no stub drives is a branch that ships
  # untested. These are the regressions, not the history.
  SY_DD="x.bs:7: error: syntax error before: '..'"
  BINDS="x.bs:7: error: Ship binds int twice in one head"

  # The correct form: F29's printer, which is what the table now says. Updated
  # 2026-08-27 when F29 emptied the table — the stub set is the SPELLING the gate
  # is defending, so it moves when the defended spelling moves, and `good` is red
  # if it does not.
  today() { # today DIR
    one "$1" Atom          "Name(:blue) -> ..."                     "" 0
    one "$1" Interval      "Big(>= 0 and <= 128) -> ..."            "" 0
    two "$1" IntervalUnion "Classify(<= 199) -> ..."                "Classify(>= 300 and <= 399) -> ..."
    one "$1" RecordUnion   "Which(Invoice i) -> ..."                "" 0
    one "$1" RecordInList  "Ship([Order o, ..]) -> ..."             "" 0
    one "$1" TupleNested   "Step((:ok, n)) when n <= 0 -> ..."      "" 0
    one "$1" OpenList      "Shape([n]) -> ..."                      "" 0
    two "$1" BinTag        "Classify(0) -> ..."                     "Classify(>= 4 and <= 255) -> ..."
    one "$1" TopString     "Kind(s) -> ..."                         "" 0
    two "$1" WholeList     "Ship([]) -> ..."                       "Ship([Order o, ..]) -> ..."
    many "$1"
    wire_ok "$1"
    promise_ok "$1"
  }
  # promise_ok/1 — both promise entries agreeing with compiler and comment.
  # `today` must lay these down for EVERY stub set: with the promise floor
  # inside `judge`, a set carrying no promise data is red on the floor rather
  # than on its own defect, and each `bad` case below would print "ok red"
  # while testing nothing. `good` is what holds this honest, since it is the
  # one that must come out silent.
  promise_ok() { # promise_ok DIR
    local d="$W/$1/promise" p; mkdir -p "$d"
    for p in $PROMISES; do
      printf '%s\n' "$(promise_head "$p")" > "$d/$p.term"
      printf '%s'   "$(promise_head "$p")" > "$d/$p.head"
      printf 'found' > "$d/$p.claim"
      : > "$d/$p.paste"
      printf '0' > "$d/$p.rc"
    done
  }
  # wire_ok/1 — the seven Wire clauses at the verdicts the table records.
  wire_ok() { # wire_ok DIR
    local d="$W/$1/wire" k=0 h; mkdir -p "$d"
    while IFS= read -r h; do
      k=$((k + 1))
      printf '%s\n' "$h" > "$d/c$k.deleted"
      if [ "$h" = "Classify(>= 9)" ]; then
        printf '%s\n' "Classify(>= 9 and <= 255) -> ..." > "$d/c$k.term"
      else
        printf '%s\n' "$h -> ..." > "$d/c$k.term"
      fi
      : > "$d/c$k.paste"
      printf '0' > "$d/c$k.rc"
    done <<< "$WIRE_ROSTER"
  }

  today good

  today type_notation
  one type_notation Atom "Name(int <= 5) -> ..." "" 0

  # THE SECOND LINE, WHICH IS THE HALF `head -n 1` COULD NOT SEE. A shape whose
  # first head is clean and whose second is type notation went green while the
  # spelling check read only the first line.
  #
  # The second head has to carry a TYPE WORD and not a `..`: a span that does not
  # parse is caught by the paste-back, so a `..` here would go red for the wrong
  # reason and prove nothing about the per-line spelling check. Found by the stub
  # failing to fire on its first spelling.
  today second_line
  two second_line IntervalUnion "Classify(<= 199) -> ..." "Classify(int >= 300) -> ..."

  mkdir -p "$W/silent"
  one silent Atom "Name(:blue) -> ..." "" 0

  today cry_wolf
  one cry_wolf Interval "Big(0..128) -> ..." "" 2

  # THE SPAN REGRESSES TO TYPE NOTATION AND STOPS PARSING. Ticket 42 settled the
  # relational spelling in 2026-08-15 and the printer ignored it for twelve days;
  # this is what that looked like, and it is the shape that comes back if
  # `i_pat/2` is ever routed through `i_str/1` again.
  today dot_dot
  one dot_dot Interval "Big(0..128) -> ..." "$SY_DD" 1

  # THE LIST ELEMENT REGRESSES TO ITS FIELD TYPES AND BINDS `int` TWICE. The
  # original `RecordInList` defect: `pat_parts/1` reached `l_str/1`, whose
  # element printer was hardwired to `to_string`.
  today rebinds
  one rebinds RecordInList \
      "Ship([{ Kind: :'M.Order', Id: int, Total: int }, ..]) -> ..." "$BINDS" 1

  today over_informed
  one over_informed Extra "Extra(int) -> ..." "" 0

  # THE MUTATION STAGE'S STUBS. `c6` is `Classify(>= 4 and <= 7)` in roster
  # order — the clause wire.bs:15 makes its claim about.
  #
  #   wire_paraphrase  the residual pastes and is not the deleted line: the
  #                    `4..7` spelling coming back, which is F29 regressing and
  #                    the sentence at wire.bs:15 going false while compiling.
  #   wire_split       the one clause came back as two heads.
  #   wire_refused     the head did not compile when pasted.
  #   wire_unrun       the paste-back never ran.
  #   wire_missing     six clauses measured; the roster's seventh never deleted.
  #   wire_extra       an eighth clause deleted that the table has no row for.
  #   wire_never       the stage produced nothing at all.
  today wire_paraphrase
  printf '%s\n' "Classify(4..7) -> ..." > "$W/wire_paraphrase/wire/c6.term"
  today wire_split
  printf '%s\n%s\n' "Classify(>= 4 and <= 5) -> ..." "Classify(>= 6 and <= 7) -> ..." > "$W/wire_split/wire/c6.term"
  today wire_refused
  printf '%s' "$SY_DD" > "$W/wire_refused/wire/c6.paste"; printf '1' > "$W/wire_refused/wire/c6.rc"
  today wire_unrun
  rm -f "$W/wire_unrun/wire/c6.rc"
  today wire_missing
  rm -f "$W/wire_missing/wire/c6".*
  today wire_extra
  printf '%s\n' "Classify(255)" > "$W/wire_extra/wire/c8.deleted"
  printf '%s\n' "Classify(255) -> ..." > "$W/wire_extra/wire/c8.term"
  : > "$W/wire_extra/wire/c8.paste"; printf '0' > "$W/wire_extra/wire/c8.rc"
  today wire_never
  rm -rf "$W/wire_never/wire"

  # ---- the promise stage's own six -------------------------------------
  #
  # promise_unclaimed  THE ONE THIS STAGE EXISTS FOR, and the defect shop.bs:22
  #                    actually had: the compiler is right and the prose is
  #                    stale. Without it the comment check ships unexercised,
  #                    because `Classify(>= 4 and <= 7)` sits in wire.bs twice
  #                    and a whole-file search would match the clause.
  # promise_moved      the printer regresses to the minted tag, so the comment
  #                    is now right about a compiler that changed under it.
  # promise_unpasteable the promised head comes back and does not compile.
  # promise_cry_wolf   the paste-back never ran, reported as success: empty
  #                    output with a non-zero status.
  # promise_missing    a roster entry never measured — the floor.
  # promise_extra      one measured and not in the roster. The over-informed
  #                    control: a verdict keyed on entry NAME rather than on
  #                    the recorded head and claim passes everything else here.

  today promise_unclaimed
  : > "$W/promise_unclaimed/promise/Shop.claim"

  today promise_moved
  printf '%s\n' "Which({ Kind: :'Shop.Invoice' }) -> ..." > "$W/promise_moved/promise/Shop.term"
  printf '%s'   "Which({ Kind: :'Shop.Invoice' }) -> ..." > "$W/promise_moved/promise/Shop.head"

  today promise_unpasteable
  printf '%s' "$SY_DD" > "$W/promise_unpasteable/promise/Wire.paste"
  printf '1'           > "$W/promise_unpasteable/promise/Wire.rc"

  today promise_cry_wolf
  : > "$W/promise_cry_wolf/promise/Wire.paste"
  printf '2' > "$W/promise_cry_wolf/promise/Wire.rc"

  today promise_missing
  rm -f "$W/promise_missing/promise/Shop."*

  today promise_extra
  printf '%s\n' "Nope(:x) -> ..." > "$W/promise_extra/promise/Bogus.term"
  printf '%s'   "Nope(:x) -> ..." > "$W/promise_extra/promise/Bogus.head"
  printf 'found' > "$W/promise_extra/promise/Bogus.claim"
  : > "$W/promise_extra/promise/Bogus.paste"
  printf '0' > "$W/promise_extra/promise/Bogus.rc"

  for bad in type_notation second_line silent cry_wolf over_informed dot_dot rebinds \
             wire_paraphrase wire_split wire_refused wire_unrun wire_missing wire_extra wire_never \
             promise_unclaimed promise_moved promise_unpasteable promise_cry_wolf \
             promise_missing promise_extra; do
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
  echo "self-test passed: twenty defects seen, today's tables accepted"
  exit 0
fi

[ -x "$BSC" ] || { echo "no built bsc at $BSC - run rebar3 escriptize"; exit 2; }
[ -d "$FIXTURES" ] || { echo "no fixture corpus at $FIXTURES"; exit 2; }

[ -f "$WIRE" ] || { echo "no examples/Wire/wire.bs at $WIRE"; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
probe "$W"
probe_wire "$W"
probe_promise "$W"
out="$(judge "$W")"
if [ -n "$out" ]; then
  echo "$out"
  echo
  echo "the residual round-trip moved. Every shape's verdict is written down in"
  echo "\`expected\` in this script, and every Wire clause's in \`wire_expected\`;"
  echo "if the printer changed, change the table with it."
  exit 1
fi
echo "  ok         11 residual shapes round-tripped, each to the verdict recorded for it"
echo "             (every entry in \`expected\` reads 'clean' - F29's done-when, met)"
echo "  ok         $(grep -c . "$W/wire/clauses") Wire clauses deleted in turn: six handed back as the same line,"
echo "             the open span closed on the domain's top - wire.bs:15's sentence, run"
echo "  ok          2 source comments promise the head the compiler actually prints,"
echo "             and it pasted clean - the sentence checked, not only the behaviour"
