#!/usr/bin/env bash
#
# A RETURN-MISMATCH DIAGNOSTIC MUST HAND THE AGENT THE SIGNATURE TO PASTE.
#
# Ticket 23 §8: "when a clause returns outside its signature, the diagnostic
# carries the corrected signature to paste." §4's test for the contractual
# subset is §2's — does it hand the agent something to write? — and until F25
# `return_not_declared` printed the uncovered residual and stopped, which
# answers what is WRONG and not what to WRITE.
#
# THE PROBE THAT DECIDES WHETHER THE FIX IS RIGHT IS PROBE 3, NOT PROBE 1.
# Probe 1 is the happy path and every plausible implementation passes it. The
# two that a fix written to satisfy probe 1 gets wrong were both MEASURED before
# this gate was written:
#
#   Two offending clauses produce TWO diagnostics. A correction computed per
#   clause prints two contradictory pasteable lines — `int | :zero` on one and
#   `int | (:error, string)` on the other — and pasting either leaves the other
#   clause still wrong. The correction is a property of the FUNCTION.
#
#   `bs_types:to_string/1` renders a record as `{ Kind: :'M.Invoice', … }`.
#   Ticket 26 §1 mints that tag from the qualified module path, so a signature
#   carrying it hard-codes a mint instead of naming `Invoice`. It LOOKS
#   pasteable. A line that looks pasteable and is not is worse than no line,
#   because §2's whole argument is that the compiler hands over something usable.
#
# WHY PROBE 4 EXISTS. Probe 3 asserts an ABSENCE — no signature for a record
# residual — and an absence passes for free over a run that never compiled. So
# probe 4 requires a module that DOES compile to produce no diagnostic at all.
# The absence in probe 3 is protected by the presence in probe 4, structurally,
# and the BROKEN control below is what proves the pairing works rather than a
# comment claiming it does.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BSC="$HERE/_build/default/bin/bsc"

HEADING='the signature its clauses justify:'
# ENG-346. The three markers of a correction withheld because the declaration
# check would refuse it. The second is the declaration check's own header
# (`bs_diag`'s `indiscriminable_union`), so the advice and the refusal read the
# same words.
REFUSED='Widening the signature to cover both would be refused:'
TELL='no clause head can tell `map<string, int>` from `map<string, binary>`'
TAG='so if both are meant, tag them, with atoms of your choosing:'
# ENG-346 Round 3 (David, 2026-09-11: "all"): every return mismatch leads with
# the clause, naming the declared type as the author wrote it.
LEAD1='If `int` is what you meant, fix the clause, not the signature.'
SHAPE='(:tag1, map<string, int>) | (:tag2, map<string, binary>)'
# David's review round (ENG-346 R2, R3): a withheld line says why, and a line
# that replaces the declared type says so.
UNSPELLABLE='no signature is offered: what the clauses return has no spelling as a type yet.'
REPLACES='this replaces `map<string, int>`, which `map<string, term>` contains.'

# ---------------------------------------------------------------------------
# judge — the whole of the gate's opinion, in one place.
#
# Reads P1.out … P4.out from a directory and prints one line per violation. A
# function over a directory so --self-test drives THIS code path with fixtures
# rather than a copy of it.
# ---------------------------------------------------------------------------
judge() {
  local dir="$1"
  local p1 p2 p3 p4 p5 p6 p7c p7a p8 p9 p10

  p1="$(cat "$dir/P1.out")"
  p2="$(cat "$dir/P2.out")"
  p3="$(cat "$dir/P3.out")"
  p4="$(cat "$dir/P4.out")"
  p5="$(cat "$dir/P5.out")"
  p6="$(cat "$dir/P6.out")"
  p7c="$(cat "$dir/P7C.out")"
  p7a="$(cat "$dir/P7A.out")"
  p8="$(cat "$dir/P8.out")"
  p9="$(cat "$dir/P9.out")"
  p10="$(cat "$dir/P10.out")"

  # PROBE 1 — the line exists, and it is a whole signature.
  #
  #   public int Answer(int n)      with      Answer(n) -> :oops
  #
  # Asserted on the entire line rather than on the type fragment: a fix that
  # printed `int | :oops` alone would still leave the agent assembling a
  # signature, which is the work §2 says the compiler owns.
  if ! grep -qF "$HEADING" <<<"$p1"; then
    echo "probe 1: no corrected signature for a plain return mismatch."
    echo "         ticket 23 §8 is the whole of this gate: the diagnostic must"
    echo "         carry the line to paste, not only the residual."
  elif ! grep -qF 'public int | :oops Answer(int n)' <<<"$p1"; then
    echo "probe 1: the corrected signature is not the line to paste."
    echo "         expected: public int | :oops Answer(int n)"
    echo "         got:"
    sed 's/^/           /' <<<"$p1"
  fi
  # ... and since ENG-346 Round 3 the clause comes first: the signature states
  # intent, and the widened line is the alternative, not the headline.
  local lead_at head_at
  lead_at="$(grep -nF "$LEAD1" <<<"$p1" | head -1 | cut -d: -f1)"
  head_at="$(grep -nF "$HEADING" <<<"$p1" | head -1 | cut -d: -f1)"
  if [ -z "$lead_at" ] || { [ -n "$head_at" ] && [ "$lead_at" -gt "$head_at" ]; }; then
    echo "probe 1: the diagnostic does not lead with the clause."
    echo "         expected, before the signature: $LEAD1"
    sed 's/^/           /' <<<"$p1"
  fi

  # PROBE 2 — the residual survives beside it. Two different questions, and
  # ticket 04 made the first one the product surface, so the new line is an
  # addition rather than a replacement.
  if ! grep -qF 'not covered by the declared return type:' <<<"$p1"; then
    echo "probe 2: the uncovered residual was dropped."
    echo "         the new line answers what to WRITE; the residual answers what"
    echo "         is not COVERED. ticket 04 made the second one a product surface."
  fi

  # PROBE 3 — ONE correction for the function, and it names no mint tag.
  #
  # Two sub-conditions, both measured before this file existed. The count must
  # be two identical lines, not two different ones, and no rendering of a record
  # may reach a signature.
  local heads lines
  heads="$(grep -cF "$HEADING" <<<"$p2" || true)"
  lines="$(grep -cF 'public int | :zero | (:error, string) Go(int n)' <<<"$p2" || true)"
  if [ "$heads" != "2" ] || [ "$lines" != "2" ]; then
    echo "probe 3: two offending clauses did not get ONE function-wide signature."
    echo "         headings: $heads  matching lines: $lines  (both must be 2)"
    echo "         a per-clause correction prints two contradictory pasteable"
    echo "         lines and pasting either leaves the other clause wrong."
    sed 's/^/           /' <<<"$p2"
  fi
  if grep -qF "$HEADING" <<<"$p3"; then
    echo "probe 3: a signature was printed for a record residual."
    echo "         bs_types renders it as its MINT TAG, which ticket 26 §1 derives"
    echo "         from the qualified module path. pasting that hard-codes a mint"
    echo "         instead of naming the record. no line is the correct answer."
    sed 's/^/           /' <<<"$p3"
  fi
  # The mint-tag guard is SCOPED TO THE SYNTHESISED LINE and not to the output,
  # because the residual legitimately prints `Kind:` — ticket 04 made the
  # discriminator the missing case, and to_pattern renders it on purpose. What
  # must never carry a tag is the line offered for pasting, which is the line
  # after the heading. Checking the whole output instead would forbid the
  # correct behaviour, and the self-test's GOOD stub is what caught that.
  local minted
  minted="$(grep -A1 -F "$HEADING" <<<"$p1$p2$p3$p4$p8$p9" | grep -F 'Kind:' || true)"
  if [ -n "$minted" ]; then
    echo "probe 3: a mint tag reached a pasteable signature."
    sed 's/^/           /' <<<"$minted"
  fi
  # ... and the record case must still be reported at all. Without this the
  # probe above passes over a module that produced no output whatsoever.
  if ! grep -qF 'returns a value its signature does not declare' <<<"$p3"; then
    echo "probe 3: the record case reported no return mismatch at all."
    echo "         the refusal is meant to drop ONE line, not the diagnostic."
  fi

  # PROBE 4 — the clean control. A module that compiles must say nothing, which
  # is what makes probe 3's absences a measurement rather than a vacuum.
  if [ -n "$p4" ]; then
    echo "probe 4: a module that should compile produced output."
    echo "         probe 3 asserts absences and they are only meaningful while"
    echo "         this compile is clean."
    sed 's/^/           /' <<<"$p4"
  fi

  # PROBE 5 — a `none` return's correction carries NO ABSORBED MEMBER.
  #
  # Ticket 68 refuses `none | term` at a declaration, so a correction that
  # printed it would be a program this compiler rejects, offered as the fix —
  # ticket 23 §2's failure mode reached through a TYPE rather than through the
  # mint tag probe 3 covers, which is why it is its own probe. The bottom is
  # not the only declared type a residual can absorb: probe 9 is another.
  if ! grep -qF "$HEADING" <<<"$p5"; then
    echo 'probe 5: no corrected signature for a return mismatch under `none`.'
    echo '         `none` is writable since ENG-328, so this is an ordinary'
    echo '         return mismatch and owes the same pasteable line as probe 1.'
  elif grep -qE 'none *\|' <<<"$p5"; then
    echo 'probe 5: the corrected signature offers an ABSORBED member.'
    echo '         ticket 68 refuses `none | term` at a declaration, so this line'
    echo '         is a program the compiler rejects, offered as the fix.'
    sed 's/^/           /' <<<"$p5"
  elif ! grep -qF 'public term Reject(term r)' <<<"$p5"; then
    echo 'probe 5: the corrected signature under `none` is not the line to paste.'
    echo '         expected: public term Reject(term r)'
    echo "         got:"
    sed 's/^/           /' <<<"$p5"
  fi

  # PROBE 6 — a correction the DECLARATION CHECK refuses is not printed (ENG-346).
  #
  #   public map<string, int> Pick(int n)    returning a map<string, binary>
  #
  # was told to paste `map<string, int> | map<string, binary>`, and the
  # declaration check refuses that line. Ticket 70 put the objection in the
  # advice, so the advice must say the line would be refused, name the pair,
  # and name the repair. The first branch fails a run that printed nothing, so
  # the heading's absence is only read over a real diagnostic.
  if ! grep -qF 'returns a value its signature does not declare' <<<"$p6"; then
    echo "probe 6: the two-map program reported no return mismatch at all."
    echo "         the refusal is meant to drop ONE line, not the diagnostic."
  elif grep -qF "$HEADING" <<<"$p6"; then
    echo "probe 6: a corrected signature the declaration check refuses was printed."
    echo "         pasting it gets \`no clause head can tell ...\`, which is the"
    echo "         compiler recommending a form it rejects."
    sed 's/^/           /' <<<"$p6"
  elif ! grep -qF "$REFUSED" <<<"$p6" || ! grep -qF "$TELL" <<<"$p6" \
       || ! grep -qF "$TAG" <<<"$p6" || ! grep -qF "$SHAPE" <<<"$p6"; then
    echo "probe 6: the line is withheld but the diagnostic does not say why or what"
    echo "         to write instead. an author told nothing assumes an unwritable"
    echo "         residual and pastes the refused union by hand."
    sed 's/^/           /' <<<"$p6"
  fi

  # PROBE 7 — the premise, at BOTH declaration sites. The line probe 6 withholds
  # must still be refused, by a compile and by `--api`, which reaches the check
  # through `exports_of/1` and not `check/2`. When a map pattern ships the
  # refusal lifts, this fires, and probe 6's absence stops being right: the
  # line should print again.
  if ! grep -qF "$TELL" <<<"$p7c"; then
    echo "probe 7: a compile accepts the line probe 6 withholds."
    echo "         the refusal the advice predicts is gone, so the advice is wrong."
    sed 's/^/           /' <<<"$p7c"
  fi
  if ! grep -qF "$TELL" <<<"$p7a"; then
    echo "probe 7: \`bsc --api\` accepts the line probe 6 withholds."
    echo "         --api is a second declaration pass, through exports_of/1; a"
    echo "         refusal missing there prints the refused union as the API."
    sed 's/^/           /' <<<"$p7a"
  fi

  # PROBE 8 — the over-refusal control. A map beside an atom is split by a
  # guard, so its correction compiles and must still be printed.
  if ! grep -qF 'public map<string, int> | :oops Pick(int n)' <<<"$p8"; then
    echo "probe 8: the correction for \`map<string, int> | :oops\` was not printed."
    echo "         a guard splits those members, so the line compiles. withholding"
    echo "         it is a refusal with no cause."
    sed 's/^/           /' <<<"$p8"
  fi

  # PROBE 9 — a residual that ABSORBS the declared type (ENG-346 review).
  #
  #   public map<string, int> Pick(int n)    returning a map<string, term>
  #
  # The algebra cannot spell `map<string, term>` less `map<string, int>`, so the
  # residual is `map<string, term>` and contains the declared type. The line
  # read `map<string, int> | map<string, term>`, which ticket 68 refuses as an
  # absorbed member. The correction is the residual alone, as probe 5's is.
  if ! grep -qF "$HEADING" <<<"$p9"; then
    echo "probe 9: no corrected signature when the residual absorbs the declared type."
    echo "         the residual alone is a line that compiles, so it is owed."
    sed 's/^/           /' <<<"$p9"
  elif grep -qF 'map<string, int> |' <<<"$p9"; then
    echo "probe 9: the corrected signature offers an ABSORBED member."
    echo "         \`map<string, int>\` is absorbed by \`map<string, term>\`, and ticket"
    echo "         68 refuses that at a declaration."
    sed 's/^/           /' <<<"$p9"
  elif ! grep -qF 'public map<string, term> Pick(int n)' <<<"$p9"; then
    echo "probe 9: the corrected signature is not the line to paste."
    echo "         expected: public map<string, term> Pick(int n)"
    sed 's/^/           /' <<<"$p9"
  elif ! grep -qF "$REPLACES" <<<"$p9"; then
    # R3: the line replaces the declared type rather than adding to it, and
    # the likelier mistake is the clause, so the diagnostic has to say so.
    echo "probe 9: the line replaces the declared type and does not say so."
    echo "         an author pasting it loses \`map<string, int>\` without being told."
    sed 's/^/           /' <<<"$p9"
  fi

  # PROBE 10 — a withheld line says why (ENG-346 R2).
  #
  #   public list<map<string, int>> Pick(int n)    returning a list<map<string, binary>>
  #
  # The residual prints as `[map<string, binary>, ..]`, pattern syntax, so no
  # line is offered. Probe 3's record case is withheld too. Both must say so: a
  # line that disappears with no word reads as the compiler having nothing to
  # offer, and the author cannot tell that from a defect.
  if ! grep -qF '[map<string, binary>, ..]' <<<"$p10"; then
    echo "probe 10: the list program reported no residual."
    sed 's/^/           /' <<<"$p10"
  elif grep -qF "$HEADING" <<<"$p10"; then
    echo "probe 10: a line was printed for a residual with no spelling as a type."
    echo "          pasting it is a syntax error."
    sed 's/^/           /' <<<"$p10"
  elif ! grep -qF "$UNSPELLABLE" <<<"$p10"; then
    echo "probe 10: a line was withheld with no word about why."
    sed 's/^/           /' <<<"$p10"
  fi
  # The record case, where it is withheld. Where probe 3 finds a line printed
  # instead, that is probe 3's defect and not this one.
  if ! grep -qF "$HEADING" <<<"$p3" && ! grep -qF "$UNSPELLABLE" <<<"$p3"; then
    echo "probe 10: the record residual's line was withheld with no word about why."
    sed 's/^/           /' <<<"$p3"
  fi
}

# ---------------------------------------------------------------------------
# --self-test — build the defects this gate names and require a red on each.
#
# A gate that has never been seen to fail is not believed. Fifteen stubs, each
# wrong in a different way, plus the decided behaviour and a run that never
# compiled. Every stub must also PASS the probes it does not break: a probe
# that fires on everything is worthless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  fail=0

  # The ENG-346 outputs as the decided behaviour prints them, written into
  # every stub directory so each stub breaks only what it names.
  good_p6="m.bs:5:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  If \`map<string, int>\` is what you meant, fix the clause, not the signature.
  Widening the signature to cover both would be refused:
    no clause head can tell \`map<string, int>\` from \`map<string, binary>\`
  so if both are meant, tag them, with atoms of your choosing:
    (:tag1, map<string, int>) | (:tag2, map<string, binary>)
  and return each value inside its tag."
  good_p7="m.bs:3:47: error: no clause head can tell \`map<string, int>\` from \`map<string, binary>\`
  in Pick"
  good_p8="m.bs:3:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  If \`map<string, int>\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public map<string, int> | :oops Pick(int n)"
  good_p9="m.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, term>
  If \`map<string, int>\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public map<string, term> Pick(int n)
  this replaces \`map<string, int>\`, which \`map<string, term>\` contains."
  good_p10="m.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    [map<string, binary>, ..]
  If \`list<map<string, int>>\` is what you meant, fix the clause, not the signature.
  no signature is offered: what the clauses return has no spelling as a type yet."

  seed_eng346() {
    printf '%s\n' "$good_p6" > "$1/P6.out"
    printf '%s\n' "$good_p7" > "$1/P7C.out"
    printf '%s\n' "$good_p7" > "$1/P7A.out"
    printf '%s\n' "$good_p8" > "$1/P8.out"
    printf '%s\n' "$good_p9" > "$1/P9.out"
    printf '%s\n' "$good_p10" > "$1/P10.out"
  }

  good_p1="m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  If \`int\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public int | :oops Answer(int n)"

  good_p2="m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
  If \`int\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public int | :zero | (:error, string) Go(int n)
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)
  If \`int\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public int | :zero | (:error, string) Go(int n)"

  good_p3="m.bs:5: error: Make returns a value its signature does not declare
  not covered by the declared return type:
    { Kind: :'M4.Invoice' }
  If \`Order\` is what you meant, fix the clause, not the signature.
  no signature is offered: what the clauses return has no spelling as a type yet."

  # ENG-328. `none` is writable, so a body that RETURNS is an ordinary mismatch
  # - and the correction must be `term` alone, not `none | term`.
  good_p5="m.bs:3: error: Reject returns a value its signature does not declare
  not covered by the declared return type:
    term
  If \`none\` is what you meant, fix the clause, not the signature.
  Otherwise, the signature its clauses justify:
    public term Reject(term r)"

  # --- SILENT ------------------------------------------------------------
  #
  # The defect F25 exists for: the residual is printed and nothing else. This
  # is the compiler as it stood at 0be76fb.
  mkdir -p "$CTL/silent"
  printf '%s\n' "m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops" > "$CTL/silent/P1.out"
  printf '%s\n' "m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)" > "$CTL/silent/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/silent/P3.out"
  printf '%s\n' "$good_p5" > "$CTL/silent/P5.out"
  : > "$CTL/silent/P4.out"
  seed_eng346 "$CTL/silent"
  silent="$(judge "$CTL/silent" || true)"
  grep -q '^probe 1:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 1 missed the silent stub — the reported defect"; fail=1; }
  grep -q '^probe 3:' <<<"$silent" || { echo "SELF-TEST FAILED: probe 3 missed the silent stub — no function-wide line either"; fail=1; }
  for n in 2 4 6 7 8 9 10; do
    if grep -q "^probe $n:" <<<"$silent"; then
      echo "SELF-TEST FAILED: probe $n fired on the silent stub, which it should pass."
      echo "                  a probe that fires on everything proves nothing."
      fail=1
    fi
  done

  # --- PER-CLAUSE --------------------------------------------------------
  #
  # THE STUB THAT MOTIVATES THIS FILE. Every line is present and well-formed,
  # and each clause was corrected on its own — so the compiler prints two
  # different signatures for one function and neither is sufficient. A gate
  # that only asked "is the heading there?" would go green over this.
  mkdir -p "$CTL/perclause"
  printf '%s\n' "$good_p1" > "$CTL/perclause/P1.out"
  printf '%s\n' "m.bs:3: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    :zero
  the signature its clauses justify:
    public int | :zero Go(int n)
m.bs:4: error: Go returns a value its signature does not declare
  not covered by the declared return type:
    (:error, string)
  the signature its clauses justify:
    public int | (:error, string) Go(int n)" > "$CTL/perclause/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/perclause/P3.out"
  printf '%s\n' "$good_p5" > "$CTL/perclause/P5.out"
  : > "$CTL/perclause/P4.out"
  seed_eng346 "$CTL/perclause"
  perclause="$(judge "$CTL/perclause" || true)"
  grep -q '^probe 3:' <<<"$perclause" || {
    echo "SELF-TEST FAILED: probe 3 accepted a per-clause correction. this is the"
    echo "                  defect the gate exists for: two contradictory pasteable"
    echo "                  lines for one function, neither of them sufficient."
    fail=1
  }
  for n in 1 2 4 6 7 8 9 10; do
    if grep -q "^probe $n:" <<<"$perclause"; then
      echo "SELF-TEST FAILED: probe $n fired on the per-clause stub, which it should pass."
      fail=1
    fi
  done

  # --- OVERREACH ---------------------------------------------------------
  #
  # The OVER-INFORMED stub: it prints a signature everywhere, including where
  # there is nothing writable to print. Its record line is structurally correct
  # and carries a mint tag, which is the plausible-but-wrong fix.
  mkdir -p "$CTL/overreach"
  printf '%s\n' "$good_p1" > "$CTL/overreach/P1.out"
  printf '%s\n' "$good_p2" > "$CTL/overreach/P2.out"
  printf '%s\n' "m.bs:5: error: Make returns a value its signature does not declare
  not covered by the declared return type:
    { Kind: :'M4.Invoice' }
  the signature its clauses justify:
    public { Kind: :'M4.Order', Id: int, Total: int } | { Kind: :'M4.Invoice', Id: int, Total: int } Make(int n)" > "$CTL/overreach/P3.out"
  printf '%s\n' "$good_p5" > "$CTL/overreach/P5.out"
  : > "$CTL/overreach/P4.out"
  seed_eng346 "$CTL/overreach"
  overreach="$(judge "$CTL/overreach" || true)"
  grep -q '^probe 3:' <<<"$overreach" || {
    echo "SELF-TEST FAILED: probe 3 accepted a mint tag in a pasteable signature."
    echo "                  that line looks usable and is not, which is the failure"
    echo "                  mode ticket 23 §2 exists to prevent."
    fail=1
  }
  for n in 1 2 4 6 7 8 9 10; do
    if grep -q "^probe $n:" <<<"$overreach"; then
      echo "SELF-TEST FAILED: probe $n fired on the overreach stub, which it should pass."
      fail=1
    fi
  done

  # --- ABSORBED ----------------------------------------------------------
  #
  # THE STUB PROBE 5 EXISTS FOR, and it is the plausible-but-wrong fix rather
  # than an absurd one: it is what the printer does when nobody teaches the
  # concatenation about the bottom. Every line is present, well-formed and
  # function-wide — probes 1 to 4 all pass — and the one line offered for
  # pasting is a program ticket 68 refuses.
  mkdir -p "$CTL/absorbed"
  printf '%s\n' "$good_p1" > "$CTL/absorbed/P1.out"
  printf '%s\n' "$good_p2" > "$CTL/absorbed/P2.out"
  printf '%s\n' "$good_p3" > "$CTL/absorbed/P3.out"
  : > "$CTL/absorbed/P4.out"
  seed_eng346 "$CTL/absorbed"
  printf '%s\n' "m.bs:3: error: Reject returns a value its signature does not declare
  not covered by the declared return type:
    term
  the signature its clauses justify:
    public none | term Reject(term r)" > "$CTL/absorbed/P5.out"
  absorbed="$(judge "$CTL/absorbed" || true)"
  grep -q '^probe 5:' <<<"$absorbed" || {
    echo 'SELF-TEST FAILED: probe 5 accepted an absorbed member in a pasteable'
    echo '                  signature. ticket 68 refuses `none | term`, so the'
    echo '                  compiler would be offering a program it rejects.'
    fail=1
  }
  for n in 1 2 3 4 6 7 8 9 10; do
    if grep -q "^probe $n:" <<<"$absorbed"; then
      echo "SELF-TEST FAILED: probe $n fired on the absorbed stub, which it should pass."
      fail=1
    fi
  done

  # The ENG-346 stubs start from the decided behaviour and break one output
  # each, so a stub that fires any probe but its own is a probe firing on
  # everything.
  seed_all() {
    mkdir -p "$1"
    printf '%s\n' "$good_p1" > "$1/P1.out"
    printf '%s\n' "$good_p2" > "$1/P2.out"
    printf '%s\n' "$good_p3" > "$1/P3.out"
    printf '%s\n' "$good_p5" > "$1/P5.out"
    : > "$1/P4.out"
    seed_eng346 "$1"
  }
  # expect STUB PROBE — the stub must fire PROBE and no other.
  expect() {
    local out
    out="$(judge "$CTL/$1" || true)"
    grep -q "^probe $2:" <<<"$out" || {
      echo "SELF-TEST FAILED: probe $2 missed the $1 stub."
      fail=1
    }
    for n in 1 2 3 4 5 6 7 8 9 10; do
      [ "$n" = "$2" ] && continue
      if grep -q "^probe $n:" <<<"$out"; then
        echo "SELF-TEST FAILED: probe $n fired on the $1 stub, which it should pass."
        fail=1
      fi
    done
  }

  # --- REFUSED-ANYWAY ----------------------------------------------------
  #
  # THE STUB PROBE 6 EXISTS FOR: the compiler as it stood at 5a40668. Every
  # line is well-formed, and the line offered for pasting is one the
  # declaration check refuses.
  seed_all "$CTL/refusedanyway"
  printf '%s\n' "m.bs:5:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>
  the signature its clauses justify:
    public map<string, int> | map<string, binary> Pick(int n)" > "$CTL/refusedanyway/P6.out"
  expect refusedanyway 6

  # --- WITHHELD-SILENTLY -------------------------------------------------
  #
  # The plausible half-fix: the line is dropped as F25.4 drops an unwritable
  # one, and nothing says the union would be refused or what to do instead.
  seed_all "$CTL/withheld"
  printf '%s\n' "m.bs:5:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, binary>" > "$CTL/withheld/P6.out"
  expect withheld 6

  # --- ONE-SITE ----------------------------------------------------------
  #
  # A compile refuses the withheld line and `--api` answers it as a fact:
  # ENG-320's two-sites defect, reached through the line this advice predicts.
  seed_all "$CTL/onesite"
  printf '%s\n' "module P7
map<string, int> | map<string, binary> Pick(int)" > "$CTL/onesite/P7A.out"
  expect onesite 7

  # --- COMPILE-ACCEPTS ---------------------------------------------------
  #
  # The mirror: `--api` refuses the withheld line and a compile accepts it.
  # Probe 7 reads the two sites in two branches, and without this stub the
  # compile branch is never seen to fire on its own.
  seed_all "$CTL/compileaccepts"
  : > "$CTL/compileaccepts/P7C.out"
  expect compileaccepts 7

  # --- OVER-REFUSAL ------------------------------------------------------
  #
  # A fix that withholds every correction with a map in it. Probes 1 to 7 all
  # pass it; only the control catches it.
  seed_all "$CTL/overrefusal"
  printf '%s\n' "m.bs:3:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  widening the signature to cover it would be refused:
    no clause head can tell \`map<string, int>\` from \`:oops\`
  tag the members instead: return each in a tuple led by its own atom,
  and declare the union of those tuples." > "$CTL/overrefusal/P8.out"
  expect overrefusal 8

  # --- ABSORBED-MAP ------------------------------------------------------
  #
  # The compiler at f3e1eee, which asked only whether the widened union could
  # be told apart. `map<string, int> | map<string, term>` can be: it normalises
  # to one member. Written out, it is an absorbed member.
  seed_all "$CTL/absorbedmap"
  printf '%s\n' "m.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, term>
  the signature its clauses justify:
    public map<string, int> | map<string, term> Pick(int n)" > "$CTL/absorbedmap/P9.out"
  expect absorbedmap 9

  # --- ABSORBED-SILENT ---------------------------------------------------
  #
  # The compiler at a25d048: the right line, `map<string, int>` dropped
  # without a word. Probes 1 to 8 and probe 9's first three branches pass it.
  seed_all "$CTL/absorbedsilent"
  printf '%s\n' "m.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    map<string, term>
  the signature its clauses justify:
    public map<string, term> Pick(int n)" > "$CTL/absorbedsilent/P9.out"
  expect absorbedsilent 9

  # --- WITHHELD-SILENTLY, UNSPELLABLE ------------------------------------
  #
  # Also the compiler at a25d048: the list residual has no type spelling, so
  # no line, and nothing says so.
  seed_all "$CTL/silentwithhold"
  printf '%s\n' "m.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    [map<string, binary>, ..]" > "$CTL/silentwithhold/P10.out"
  expect silentwithhold 10

  # --- RECORD-WITHHELD-SILENTLY ------------------------------------------
  #
  # Probe 10's second half: the record residual withheld with no reason, the
  # compiler before R2. Without this stub that branch is never seen to fire,
  # because every other stub's P3 carries the reason or is empty.
  seed_all "$CTL/recordsilent"
  printf '%s\n' "m.bs:5: error: Make returns a value its signature does not declare
  not covered by the declared return type:
    { Kind: :'M4.Invoice' }" > "$CTL/recordsilent/P3.out"
  expect recordsilent 10

  # --- NO-LEAD -----------------------------------------------------------
  #
  # The compiler at bc4740b: the right line, offered as the headline, with no
  # word that the clause may be what is wrong (ENG-346 Round 3).
  seed_all "$CTL/nolead"
  printf '%s\n' "m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  the signature its clauses justify:
    public int | :oops Answer(int n)" > "$CTL/nolead/P1.out"
  expect nolead 1

  # --- LEAD-LAST ---------------------------------------------------------
  #
  # The sentence present but after the line, which is R3's order at bc4740b.
  # The lead is the point, so its position is part of the claim.
  seed_all "$CTL/leadlast"
  printf '%s\n' "m.bs:3: error: Answer returns a value its signature does not declare
  not covered by the declared return type:
    :oops
  the signature its clauses justify:
    public int | :oops Answer(int n)
  If \`int\` is what you meant, fix the clause, not the signature." > "$CTL/leadlast/P1.out"
  expect leadlast 1

  # --- GOOD --------------------------------------------------------------
  seed_all "$CTL/good"
  good="$(judge "$CTL/good" || true)"
  if [ -n "$good" ]; then
    echo "SELF-TEST FAILED: the gate rejected the decided behaviour:"
    sed 's/^/                  /' <<<"$good"
    fail=1
  fi

  # --- BROKEN ------------------------------------------------------------
  #
  # Nothing compiled. Probe 3's record half asserts an ABSENCE and goes green
  # for free here; its companion presence check and probe 4 are what catch it.
  mkdir -p "$CTL/broken"
  : > "$CTL/broken/P1.out"
  : > "$CTL/broken/P2.out"
  : > "$CTL/broken/P3.out"
  : > "$CTL/broken/P5.out"
  : > "$CTL/broken/P6.out"
  : > "$CTL/broken/P7C.out"
  : > "$CTL/broken/P7A.out"
  : > "$CTL/broken/P8.out"
  : > "$CTL/broken/P9.out"
  : > "$CTL/broken/P10.out"
  printf '%s\n' "m.bs:1: error: syntax error before: 'module'" > "$CTL/broken/P4.out"
  broken="$(judge "$CTL/broken" || true)"
  for n in 1 2 3 4 5 6 7 8 9 10; do
    grep -q "^probe $n:" <<<"$broken" || {
      echo "SELF-TEST FAILED: probe $n went green over a run that never compiled."
      echo "                  an absent diagnostic is not a passing measurement."
      fail=1
    }
  done

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught fifteen defects on different probes — the silent case,"
    echo "           the per-clause correction that prints two contradictory lines,"
    echo "           the mint tag in a pasteable signature, the absorbed member a"
    echo "           writable bottom introduces, a line the declaration check"
    echo "           refuses, that line withheld with no reason, a refusal missing"
    echo "           at --api and one missing at a compile, a correction withheld"
    echo "           with no cause, a declared map absorbed by its residual, that"
    echo "           map dropped without a word, and an unspellable residual and"
    echo "           a record residual each withheld without a word, and a line that"
    echo "           does not lead with the clause or leads with it last —"
    echo "           passed each stub's other probes, passed the decided"
    echo "           behaviour, and refused a run that never compiled. the gate"
    echo "           discriminates and does not pass vacuously"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
if [ ! -x "$BSC" ]; then
    echo "building bsc..." >&2
    (cd "$HERE" && rebar3 escriptize >/dev/null)
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/P1" "$WORK/src/P2" "$WORK/src/P3" "$WORK/src/P4" \
         "$WORK/src/P5" "$WORK/src/P6" "$WORK/src/P7" "$WORK/src/P8" \
         "$WORK/src/P9" "$WORK/src/P10" "$WORK/out"

cat > "$WORK/src/P1/p1.bs" <<'BS'
module P1
public int Answer(int n)
Answer(n) -> :oops
BS

cat > "$WORK/src/P2/p2.bs" <<'BS'
module P2
public int Go(int n)
Go(0) -> :zero
Go(n) -> (:error, "bad")
BS

# A record in the RESIDUAL. `Invoice` and `Order` carry the same fields, so what
# separates them is the tag ticket 26 §1 mints — which is exactly the thing that
# must not reach a pasteable line.
cat > "$WORK/src/P3/p3.bs" <<'BS'
module P3
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
public Order Make(int n)
Make(n) -> Invoice{ Id = n, Total = 0 }
BS

# The clean control. It must compile silently, and probe 3's absences mean
# nothing without it.
cat > "$WORK/src/P4/p4.bs" <<'BS'
module P4
public atom Answer(int n)
Answer(n) -> :ok
BS

# ENG-328 / ticket 12 section 4. `none` is writable, so this is an ordinary
# return mismatch - and the only one whose residual ABSORBS the declared type.
cat > "$WORK/src/P5/p5.bs" <<'BS'
module P5
public none Reject(term r)
Reject(r) -> r
BS

# ENG-346. The program the defect was measured on: no union declared anywhere,
# and the only union in sight is the one the correction would write.
cat > "$WORK/src/P6/p6.bs" <<'BS'
module P6
public map<string, int> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Bins()
private map<string, int> Ints()
Ints() -> Ints()
private map<string, binary> Bins()
Bins() -> Bins()
BS

# The line P6 withholds, pasted. Probe 7 reads it through both declaration sites.
cat > "$WORK/src/P7/p7.bs" <<'BS'
module P7
public map<string, int> | map<string, binary> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Bins()
private map<string, int> Ints()
Ints() -> Ints()
private map<string, binary> Bins()
Bins() -> Bins()
BS

# The over-refusal control: a map beside an atom, split by `is_map`.
cat > "$WORK/src/P8/p8.bs" <<'BS'
module P8
public map<string, int> Pick(int n)
Pick(n) -> :oops
BS

# A residual that absorbs the declared type: the algebra's `map<string, term>`
# less `map<string, int>` is `map<string, term>`.
cat > "$WORK/src/P9/p9.bs" <<'BS'
module P9
public map<string, int> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Terms()
private map<string, int> Ints()
Ints() -> Ints()
private map<string, term> Terms()
Terms() -> Terms()
BS

# R2: a non-empty list residual prints as `[map<string, binary>, ..]`, which is
# not a type, so the line is withheld and must say why.
cat > "$WORK/src/P10/p10.bs" <<'BS'
module P10
public list<map<string, int>> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Bins()
private list<map<string, int>> Ints()
Ints() -> Ints()
private list<map<string, binary>> Bins()
Bins() -> Bins()
BS

for p in P1 P2 P3 P4 P5 P6 P8 P9 P10; do
  "$BSC" --src-root "$WORK/src" -o "$WORK/out" "$WORK/src/$p" \
      > "$WORK/$p.out" 2>&1 || true
done
"$BSC" --src-root "$WORK/src" -o "$WORK/out" "$WORK/src/P7" \
    > "$WORK/P7C.out" 2>&1 || true
"$BSC" --src-root "$WORK/src" --api "$WORK/src/P7" \
    > "$WORK/P7A.out" 2>&1 || true

# The gate reads the diagnostic text only; the path prefix varies per run.
for o in P1 P2 P3 P4 P5 P6 P7C P7A P8 P9 P10; do
  sed -i.bak "s#$WORK/src/[^/]*/##g" "$WORK/$o.out" && rm -f "$WORK/$o.out.bak"
done

violations="$(judge "$WORK" || true)"

if [ -n "$violations" ]; then
  echo "the return-mismatch diagnostic does not hand over a signature to paste:"
  echo
  sed 's/^/  /' <<<"$violations"
  echo
  echo "ticket 23 §8, built as F25. run --self-test to see the gate fail on purpose."
  exit 1
fi

echo "corrected signature: 10 probes — the line is present and pasteable, the"
echo "                     residual survives beside it, two clauses share one"
echo "                     function-wide correction, no mint tag reaches a"
echo "                     signature, a clean module stays silent, a"
echo '                     `none` return is corrected without an absorbed member,'
echo "                     a line the declaration check refuses is withheld with"
echo "                     the tagged shape named, that refusal holds at both"
echo "                     declaration sites, a union a guard splits is still"
echo "                     corrected, a declared map its residual absorbs is"
echo "                     replaced and says so, and a withheld line says why"
