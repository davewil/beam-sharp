# Ticket 57 — decision brief: where does the negative-literal fold belong

Research only. Nothing here resolves the ticket, edits `wayfinder/issues/57-*.md`, or touches
the tracked `compiler/` tree. All measurements below are reproducible from
`artifacts/_probes/57/README.md`.

## 0. The ticket's own diagnosis is stale — read this first

Ticket 57 was raised 2026-08-23 and describes unary minus as desugaring to a subtraction node,
`{e_op, '-', {e_int, 0}, E}`. **That desugaring no longer exists.** F51 (`float`, done
2026-09-16 — three weeks after the ticket) replaced it with a dedicated node:

```erlang
% compiler/src/bs_parser.yrl:528
expr_low -> '-' expr_low : negate(line('$1'), '$2').
% compiler/src/bs_parser.yrl:823-824
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(L, E)                 -> {e_neg, L, E}.
```

`value >= -5` now parses to `{e_op,'>=',{e_var,value},{e_neg,L,{e_int,L2,5}}}`, not the
ticket's `{e_op,'-',{e_int,0},{e_int,5}}}`. The refusal still reproduces — `comparison/1` in
`bs_check.erl:5570-5571` still only matches a bare `{e_int,_,K}` — but through a different AST
shape than the ticket describes, and **the fix is now one line cheaper than it would have been
in August**, because F51 already added exactly this kind of fold for float literals
(`negate(_L, {e_float, FL, F}) -> {e_float, FL, -F}`) and simply didn't do the same for ints.
That asymmetry — float literals fold, int literals don't — looks like an oversight in F51 rather
than a decision, and is the single fact that makes this ticket cheap to close now.

Confirmed by running `yecc:file/2` directly on both the unpatched grammar and Option A's patch:
**5 shift/reduce, 0 reduce/reduce conflicts, identical, before and after** — matching F51's own
note that this was the count "before and after" its change. Extending `negate/2` changes no
grammar production, only a semantic action, so the parser's conflict profile is untouched.

## 1. Sub-decisions this ticket implies

1. **Grammar vs. checker — the headline.** Resolved by measurement below: a third option exists
   that is textually "grammar" (it lives in `bs_parser.yrl`) but does not reintroduce the
   refinement/guard split `bs_check.erl`'s comments warn against, because it patches the *shared*
   desugaring helper (`negate/2`) that both refinement and guard already funnel through via
   `expr_low`. The ticket's framing treats "grammar" and "one meaning for refinement and guard"
   as in tension; they aren't, once the fix targets `negate/2` rather than duplicating
   `int_lit`'s pattern-only production at the refinement site.
2. **How far folding goes, if checker-side.** Measured directly (§3): the narrow checker fold
   (recognise a bare literal, or a bare unary minus over one) refuses `2 + 3`, `1 - 2 + 3`, and
   `0 - 0` in refinement position, identically to the grammar fix and identically to today's
   baseline. Neither prototype tempts you toward `erl_eval:partial_eval`-style deep arithmetic
   folding — that only becomes tempting if someone later asks for `type T = int where value >=
   1 + 4`, which is a **new** ticket, not this one.
3. **Does the fix need to touch guards too?** Yes, but not as separate work: it already does,
   automatically, because `refine/3` and `apply_guard/3` are the same `alternatives/1` /
   `comparison/1` code (`bs_check.erl:2020-2022`, `5530-5533`). Measured (§2, repro4): a guard
   split `n >= -5` / `n < -5` with no catch-all is **refused today as `inexhaustive`**, despite
   being a genuinely exhaustive partition of `int` — the same root cause as the refinement bug,
   one diagnostic over. This is a second, independently-discovered instance of the bug the ticket
   describes, not mentioned in the ticket's own text, and it means "does the fix reach guards" was
   never actually an open sub-decision: both prototyped fixes closed it for free, in the same
   diff, because the checker never had two code paths to begin with.

## 2. The repro, reconfirmed on today's tree

Built `bsc` from a scratch copy at `/tmp/ticket57-scratch/compiler` (OTP 28.5,
`rebar3 escriptize`; artifacts under `artifacts/_probes/57/repro/`).

| probe | expectation | measured |
|---|---|---|
| `repro1`: `type T = int where value >= -5` | refused | **refused**, `opaque_refinement`, exit 1 |
| `repro2`: `Sign(<= -1) -> :neg` | accepted | **accepted**, exit 0 |
| `repro3`: guard `when n >= -5` + catch-all | accepted, but is the guard *credited*? | **accepted** (exit 0), and the guard evaluates correctly at runtime (`Sign -3` → `:small`, `Sign -10` → `:other`) — the runtime BEAM guard works regardless of whether the *checker* could read it, so this probe alone hides the bug |
| `repro4`: guards `n >= -5` / `n < -5`, **no catch-all** | should be exhaustive | **refused**, `inexhaustive`, exit 1 — the guard version of the ticket's bug, undocumented by the ticket itself |

`repro4` is the sharper demonstration: it is not a diagnostic-wording problem, it is the checker
declining to credit a real proof it is being handed, for a reason that has nothing to do with
guards vs. refinements and everything to do with `comparison/1`'s literal match.

## 3. Two prototypes, measured head to head

Both live in `/tmp/ticket57-scratch/` (never the tracked tree); diffs saved at
`artifacts/_probes/57/patches/`.

### Option A — extend the parser's `negate/2` (grammar layer)

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};   % new
negate(L, E)                 -> {e_neg, L, E}.
```

**5 lines changed** (1 clause + a comment edit). No change to `bs_check.erl` at all — `comparison/1`
already matches `{e_int, _, K}`, so a folded literal is invisible to it in exactly the way an
ordinary `5` already is.

### Option B — fold in the checker (`comparison/1`)

Adds an `int_const/1` helper recognising `{e_int,_,K}` and `{e_neg,_,{e_int,_,K}}`, and routes
both sides of a comparison through it before falling back to `unknown`. **21 lines changed**, all
in `bs_check.erl`.

### Battery run against both (10 cases, `artifacts/_probes/57/battery/`)

Identical results under both options, and identical to each other:

| case | result under A and B |
|---|---|
| `value >= -5 and value <= 5` | compiles |
| `value >= 1 or value <= -1` | compiles |
| `value <= 3 or value >= 10` (control) | compiles, unaffected |
| `value != 0` (control) | compiles, unaffected |
| `value >= 2 + 3` | **still refused** — not a bare negated literal |
| `value >= 1 - 2 + 3` | **still refused** |
| `value >= 0 - 0` | **still refused** |
| `n >= m` (guard, two variables, no catch-all) | **still refused as inexhaustive** — proves neither fold starts reading a non-constant comparison |
| `float where value >= -5.0` | still refused — float refinements are wholly out of F51's scope, unaffected either way |

Both options draw the exact same line: *a bare integer literal, optionally negated once, is a
constant; anything built from an operator is not.* Option B's `int_const/1` makes that boundary a
one-clause decision the same size as Option A's `negate/2` clause — the "how far does it stop"
risk the ticket worried about turned out to be avoidable by construction in both places, not a
reason to prefer one option over the other.

### End-to-end: the ticket's own motivating example now works

`type Delta = int where value >= -100 and value <= 100` (the ticket's own "a temperature, an
offset, a balance, a correction" example) compiles under Option A and emits the narrowed spec:

```erlang
-spec 'Clamp'(-100..100) -> -100..100.
```

confirmed by inspecting the compiled `.abstr` form directly
(`artifacts/_probes/57/spec_check/`).

### Regression run: full `rebar3 eunit`, both options, twice each

1053 of 1056 tests pass under both A and B, **identical failing set**: `every_aoc_program_
still_compiles_test`, `batch_runs_every_entry_in_one_vm_and_attributes_each`,
`a_path_is_utf8_on_the_wire_test`. All three are pre-existing and unrelated to this ticket:

- `every_aoc_program_still_compiles_test` reads `filename:dirname(project_root()) ++ "/aoc"` —
  a sibling directory to `compiler/` that a `cp -r compiler` scratch copy does not include. It
  passes on the untouched tracked tree (`/home/user/beam-sharp/compiler`, verified in isolation)
  and fails identically under both A and B purely because the scratch copy is missing that
  sibling directory. Not a code regression.
- `batch_runs_every_entry_in_one_vm_and_attributes_each` and `a_path_is_utf8_on_the_wire_test`
  **fail on the untouched tracked tree too** (verified: `cd compiler && rebar3 eunit
  --module=cli_tests,diagnostic_json_tests` on `/home/user/beam-sharp/compiler` gives 2 failed,
  same two tests) — pre-existing in this sandbox (locale/subprocess-dependent), predating both
  patches.

`intervals_tests.erl` (F2's own suite, 56 tests) passes in full under Option A. No fixture in
`compiler/test/intervals_tests.erl` uses a negative refinement bound today, matching the ticket's
own observation that "every one of F2's five scenarios is non-negative."

### Compile-time cost

Not measurably different. Both folds are a single extra pattern-match arm on a path already
walked once per comparison node; `bsc` invocation cost is dominated by BEAM VM boot (~250-350ms
per `escript` call, confirmed by timing 50 invocations of each variant — the run-to-run variance
from concurrent background load on this box was larger than any per-fold signal). This is not a
performance question either way.

## 4. Three real precedents, cited from source actually read

**Erlang itself draws the checker-fold line, not the grammar line — and folds much further than
either B# prototype does.**

- `/opt/otp28-src/lib/stdlib/src/erl_parse.yrl:301` — `pat_expr -> prefix_op pat_expr :
  ?mkop1('$1', '$2')`. Erlang's own grammar has **no** special-cased negative-literal production
  for patterns; `-5` in a pattern parses to the same `{op, Anno, '-', {integer, Anno, 5}}` an
  expression would. One grammar, unconditionally, for both.
- `/opt/otp28-src/lib/compiler/src/v3_core.erl:2638-2641` — pattern lowering catches any
  `{op,...}` node and calls `erl_eval:partial_eval(Op)` before treating it as a pattern.
- `/opt/otp28-src/lib/stdlib/src/erl_eval.erl:2204-2223` — `partial_eval/1` / `ev_expr/1`
  recursively evaluates *arbitrary* constant arithmetic (`2+3`, `1-2+3`, arbitrarily nested), and
  silently declines (via `catch`, falling through to the unevaluated node) the moment it meets a
  variable. So Erlang's real answer to "how far does the fold go" is "as far as it can, on
  anything with no free variable" — considerably more permissive than either B# prototype, which
  folds only a bare literal or a single negation of one. This is direct evidence that "fold
  further" is a defensible, well-precedented design, just not one either prototype needed to reach
  for to close this ticket. Worth flagging for whoever answers ticket 57: the boundary chosen here
  (bare literal ± one negation) is narrower than Erlang's own, on purpose, and that's a one-line
  note for the ticket's answer, not a blocker.
  Note also: Erlang folds in **patterns only**; a *guard*'s `-5` stays an `{op,...}` node and is
  evaluated live by the BEAM's guard BIFs at match time — guards don't need compile-time folding
  because they're runtime-checked. B#'s guards need static reading too (for exhaustiveness), so
  this half of the Erlang precedent doesn't transfer; the pattern half does.

**Gleam resolves the same ambiguity lexically, uniformly, with no duplicated grammar production.**

- `/tmp/lang-src/gleam/compiler-core/src/parse/lexer.rs:129-146` — after lexing a name or number,
  if a `-` immediately precedes a digit, the lexer force-emits `Token::Minus` (so `x-1` and `1-1`
  read as subtraction); otherwise (`:1038-1050`, `lex_number`) a leading `-` is swallowed into the
  numeric literal itself. One rule, context-sensitive on the *preceding* token, feeding both
  `parse_pattern`'s bare `Token::Int` match (`compiler-core/src/parse.rs:1510-1515`) and ordinary
  expression parsing without duplication. Gleam has no refinement-typed construct to compare
  against directly, but the lexical unification is itself a relevant third shape: neither "grammar
  rule per site" nor "checker-side fold," but "one token, context-sensitive, shared by
  construction."

**Elm is a useful negative case, not a model.** `/tmp/lang-src/elm-compiler/compiler/src/Parse/
Pattern.hs:33-73` has no `-` alternative in pattern position at all, and `Parse/Number.hs`'s entry
point starts on a digit (its only `-` handling is inside `chompExponentSigned`, for `1e-5`
exponents). `case n of -5 -> ...` simply does not parse in Elm. That's evidence the asymmetry B#
has today — patterns yes, refinements/guards no — isn't forced by anything a neighbor language
does; Elm's answer is "neither," which B# already rejected by giving patterns `int_lit -> '-'
integer` in the first place.

## 5. Recommendation

**Option A** — extend `negate/2` in `bs_parser.yrl` with `negate(_L, {e_int, IL, N}) -> {e_int,
IL, -N}` — mirroring the float-literal clause F51 already shipped beside it.

- Smallest diff measured (5 lines vs. 21), touches one file the checker never needs to know
  changed, and needs no new helper function or naming decision (`int_const/1` in Option B is a
  small but real new piece of checker vocabulary that Option A avoids entirely).
- Does **not** reintroduce the refinement/guard split the ticket worried about: `negate/2` is
  reached identically from refinement, guard and plain expression position, because all three are
  `expr_low`. The dichotomy the ticket poses — "grammar, but risks a split" vs. "checker, but
  raises where folding stops" — turns out to have a third cell the ticket didn't consider: a
  grammar-layer fix at the point every position already shares.
- Fixes the guard-exhaustiveness bug (§2, repro4) as a byproduct, with no extra code, which
  Option B also does but by touching the checker's comparison logic directly — a larger surface
  for the same outcome.
- Matches the shape F51 already established for floats, so the fix reads as "closing a gap F51
  left" rather than a new mechanism, which is a lower review cost.

**Strongest counterargument, and why it doesn't move the recommendation:** Option B keeps
`bs_parser.yrl`'s literal-vs-desugared distinction untouched and puts "what counts as a constant"
in the one file that already owns that question for every other type (`bs_check.erl`), which is a
real architectural argument for locality. But it is not a *cheaper* or *safer* way to answer the
same question — measured identically on every battery case and the full suite — and it introduces
a new named helper (`int_const/1`) where Option A introduces zero new vocabulary, reusing a
function and a comment F51 already wrote. If a future ticket wants folding to go further (`2 + 3`,
per the Erlang precedent), that ticket will have to touch the checker regardless of which of
today's two options is chosen — Option A does not foreclose that; it simply doesn't pay for it
now.

**One open item for whoever answers the ticket, not resolved here:** whether the same one-line
treatment belongs on `to_param/1` (`bs_parser.yrl:807-819`, the lambda-parameter path) — a lambda
parameter destructuring `-5` would hit the same `negate/2` fold automatically under Option A and
was not in the ticket's scope; flagging it as a freebie rather than a gap, since `to_param({e_int,
L, N}) -> {p_int, L, N}` already accepts a negative `N` today via the pattern grammar's
`int_lit -> '-' integer`, so Option A makes the lambda path consistent with the pattern path for
free, unprompted by any test.

## 6. Probes-run appendix

Everything below is under `artifacts/_probes/57/`:

- `README.md` — exact rebuild/replay commands, the citation list with file:line, and the
  expectation table for every probe.
- `repro/repro{1,2,3,4}/` — the ticket's two-line repro plus the guard variant (repro3) and the
  guard-exhaustiveness counter-example (repro4).
- `battery/*/` — the ten-case fold-boundary battery, run identically against both prototypes.
- `spec_check/` — the `Delta` end-to-end example, confirming the emitted `-spec` narrows
  correctly under the fix.
- `patches/optA-grammar-negate.patch`, `patches/optB-checker-fold.patch` — full unified diffs
  against the ticket-57 baseline SHA, ready to reapply to a fresh scratch copy.

Full `eunit` logs (not copied into the repo — regenerable from the README's commands) were
inspected at `/tmp/ticket57-scratch/{baseline,optA,optB}-eunit.log` during this session; the
three pre-existing/unrelated failures are quoted verbatim in §3 above.

## Independent verification

Adversarial re-derivation, done separately from the authoring session, in `/tmp/verify57-scratch/`
(never touching `/tmp/ticket57-scratch/`, the tracked tree, or this brief's own probes until this
section). OTP 28.5 at `/opt/otp28-src/bin`, rebar3 at `/usr/local/bin/rebar3`,
`HTTPS_PROXY= HTTP_PROXY= rebar3 escriptize`. Every claim below was re-run from a fresh `cp -r`
of `compiler/`, not from the authoring session's copies, and every `.bs` file was typed fresh
rather than copied from `artifacts/_probes/57/`.

### The F51-staleness claim — CONFIRMED, exactly

Read `compiler/src/bs_parser.yrl` directly: `negate/2` exists at lines 823-824 exactly as quoted
(`negate(_L, {e_float, FL, F}) -> {e_float, FL, -F}; negate(L, E) -> {e_neg, L, E}.`), reached from
`expr_low -> '-' expr_low : negate(line('$1'), '$2').` at line 528, and there genuinely is no
`{e_int, ...}` clause. `git log --oneline -- compiler/src/bs_parser.yrl` and `git show 6fcaee8 --
compiler/src/bs_parser.yrl` confirm `negate/2` and its float clause were introduced in commit
`6fcaee8`, dated 2026-09-16, the F51 commit (`ENG-378 / F51: \`float\` — the eighth part...`),
which also matches F51's own finding #2 in `compiler/features/F51-float.md` ("Unary minus was
`0 - e`... `-x` is `e_neg` now... A negated float literal folds to the literal"). Before that
commit, `expr_low -> '-' expr_low` produced `{e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}`
— exactly the shape the ticket describes as current. The ticket's diagnosis (the `0 - e` desugar)
is genuinely stale, and F51 genuinely already added the float-only fold the brief says it did.
`comparison/1` in `bs_check.erl` was independently confirmed at lines 5570-5571, matching only a
bare `{e_int,_,K}`, no `{e_neg,...}` case. Both citations check out exactly, down to the line
numbers.

### Baseline repro — CONFIRMED with fresh files, fresh build

Built `bsc` from a clean `cp -r compiler` (not `git clone`, but diffed against the tracked tree
and identical — `git status` on `compiler/` was clean throughout). With my own `mod.bs` files
(none copied from `_probes/57/`): `type T = int where value >= -5` is refused, `opaque_refinement`
(confirmed as the internal tag via `bs_diag.erl:741-742`), exit 1. A pattern form,
`Classify(<= -1) -> :neg`, compiles and runs correctly (`Classify -3` → `:neg`, `Classify 0` →
`:zero`, `Classify 5` → `:pos`), exit 0. Matches the brief's repro1/repro2 exactly, independently.

### Option A and Option B patches — CONFIRMED, byte-for-byte

Applied both patches by hand to fresh scratch copies (the saved `.patch` files themselves didn't
apply cleanly with any `-pN` here, because their `+++` paths have a different directory depth than
`---`; this is a `patch`-strip-level friction in the artifact, not a content problem — the diff
text is correct). `diff -u` between the tracked source and each hand-applied result reproduces the
saved patches line for line, including line numbers (`@@ -818,9 +818,10 @@` for A,
`@@ -5567,8 +5567,16 @@` / `@@ -5576,6 +5584,15 @@` for B). Line-count check: A is 5 changed lines,
B is 21 — both exactly as claimed. Both rebuilt cleanly with `rebar3 escriptize`.

- Option A fixes `type T = int where value >= -5` (exit 0) and preserves the pattern form.
- Option B fixes the same refinement (exit 0) and preserves the pattern form.
- `value >= n` (a variable, my own adversarial file, not in the battery) stays refused as
  `opaque_refinement` under baseline, A, and B alike — neither patch starts folding a
  non-constant comparand. Confirmed.
- `value >= 2 + 3` stays refused under all three, confirmed.
- Elm and Gleam and Erlang citations (below) hold up.

### A genuine gap in the brief's "identical under both options" claim — found by an adversarial case not in the battery

Neither the original battery nor the repro set tries a **double negation**. I tested
`type T = int where value >= - -5` (my own file) against baseline, A, and B:

- Baseline: refused (`opaque_refinement`), as expected.
- **Option A: compiles (exit 0).** `negate/2`'s result re-enters `negate/2` because the grammar
  rule `expr_low -> '-' expr_low : negate(line('$1'), '$2')` recurses through the reduction: the
  inner `-5` folds to `{e_int, -5}` first, and the outer `-` then folds `{e_int, -5}` to
  `{e_int, 5}`, i.e. Option A folds arbitrarily deep nested negations of a literal, not just one.
- **Option B: still refused.** `int_const/1` has exactly one `{e_neg, _, {e_int, _, K}}` clause,
  which does not match a *doubly*-nested `{e_neg, _, {e_neg, _, {e_int, _, K}}}}`, so it falls to
  `not_const`.

This means Options A and B are **not** behaviorally identical on every input — the brief's §3
framing ("Both options draw the exact same line: a bare integer literal, optionally negated once,
is a constant") is true of the ten battery cases tested but false in general: Option A's line is
"negated any number of times", Option B's is "negated at most once". This is a real, previously
undocumented divergence, though a narrow one (nobody writes `- -5` in a refinement), and it does
not change the recommendation — if anything it is a further point in Option A's favor, since its
recursive fold is arithmetically correct (`- -5` really is `5`) and comes for free, whereas Option
B would need a second `int_const` clause to match it. Flag this as a caveat on the "identical
results" framing, not on the recommendation itself.

### The lambda-parameter "freebie" claim — the outcome holds, but the brief's own justification for it is wrong

The brief's §5 closing note says extending `negate/2` makes a lambda parameter like `-5` work
"since `to_param({e_int, L, N}) -> {p_int, L, N}` already accepts a negative `N` today via the
pattern grammar's `int_lit -> '-' integer`". I tested this directly with `(-5) => :hit` as a
lambda parameter (correct C# lambda spelling per `bs_parser.yrl`'s `expr -> '(' expr_list ')'
'=>' expr`; lambda parameters are parsed as `expr_list` and lowered by `to_param/1`, not by the
`pattern` nonterminal at all):

- **On baseline, this is refused today** — `error: a lambda's parameter is a pattern: a name, _,
  a literal, or a tuple or list of those` — because `to_param/1` has no `{e_neg, ...}` clause and
  a lambda parameter never goes through the `pattern` grammar's `'-' integer` production (that
  production only fires for the `pattern` nonterminal used in clause heads/match arms — a
  genuinely separate code path from `to_param(Expr)`, which processes `expr_list`). So the
  brief's stated mechanism for why baseline "already accepts" this is incorrect; baseline does
  not accept it.
- **Under Option A**, the specific `to_param` refusal disappears — the parameter parses cleanly to
  `{p_int, ..., -5}}` (since `-5` now folds to `{e_int, ..., -5}` at parse time before `to_param`
  ever sees it), and the compiler instead reports a downstream, unrelated diagnostic ("a lambda in
  Classify has no arrow to take its type from"), confirming the parameter itself is now accepted.

So the brief's **bottom-line prediction** (Option A makes this case work "for free") is
empirically correct, independently confirmed — but its **stated reasoning** for why the baseline
case already worked is wrong, and should be corrected if this brief is used as a reference: the
"freebie" is real, but it is a freebie *created by Option A*, not one baseline already had.

### yecc conflict count — CONFIRMED independently

Ran `yecc:file/1` directly (not through `rebar3`) against both the untouched
`compiler-baseline/src/bs_parser.yrl` and the hand-applied `compiler-optA/src/bs_parser.yrl`:
both report `Warning: conflicts: 5 shift/reduce, 0 reduce/reduce`, identical. (Note:
`yecc:file/2` with a `{report, true}` option, as one might guess from the brief's mention of
`--self-test`-style reporting, actually raises `badarg` on OTP 28.5 — the correct option is the
undocumented-in-name-only `verbose`; this is an artifact of `yecc`'s option list, not a finding
about the ticket. Once corrected, the counts match on both sides.) `rebar3 escriptize`'s own
compile-time warning line for Option A reads identically: `5 shift/reduce, 0 reduce/reduce`. The
"0 new conflicts" claim holds.

### The guard-exhaustiveness "second bug" — CONFIRMED with an independently written example

Wrote my own guard-split module (not copied from `repro4`, different clause bodies, but
necessarily the same *shape* since it is testing the same defect):

```csharp
public atom Sign(int n)

Sign(n) when n >= -5 -> :small
Sign(n) when n < -5  -> :other
```

- Baseline: refused, `Sign is not exhaustive` (confirmed as the `inexhaustive` tag via
  `bs_diag.erl:1058-1060`), exit 1, despite the two guards genuinely partitioning all of `int`.
- Option A: compiles, exit 0.
- Option B: compiles, exit 0.

This is real, not a misreading of some other diagnostic — the message and internal tag are
unambiguous, and the same split with `>=`/`<` swapped for non-boundary, unambiguously-total
conditions still fails identically on baseline. It is a legitimate second, independently
discoverable instance of the same root cause (`comparison/1`'s literal-only match), reachable
through the guard path rather than the refinement path, exactly as claimed.

### eunit suite — CONFIRMED, numbers match exactly, and the "pre-existing" explanation checks out

Ran the full suite on both a fresh baseline scratch copy and the Option A scratch copy:
`Failed: 3. Skipped: 0. Passed: 1053.` on both, and the same three named failures on both
(`every_aoc_program_still_compiles_test`, `batch_runs_every_entry_in_one_vm_and_attributes_each`,
`a_path_is_utf8_on_the_wire_test`). Went further than the brief and ran
`rebar3 eunit --module=cli_tests,diagnostic_json_tests` directly on the untouched **tracked**
tree at `/home/user/beam-sharp/compiler` (`git status` clean before and after — this is read-only;
only `_build/` artifacts are produced): `Failed: 2. Skipped: 0. Passed: 33.`, the same two tests
(`batch_runs_every_entry_in_one_vm_and_attributes_each`, `a_path_is_utf8_on_the_wire_test`). This
independently confirms those two are pre-existing on the real tree, not scratch-copy artifacts,
exactly as the brief claims.

### End-to-end `Delta` spec — CONFIRMED

My own module, `type Delta = int where value >= -100 and value <= 100` with
`public Delta Clamp(Delta value)` / `Clamp(value) -> value`: refused on baseline (same
`opaque_refinement`), compiles under Option A, and the emitted `.abstr` carries
`{attribute,0,spec,{{'Clamp',1},[{type,0,range,[{integer,0,-100},{integer,0,100}]}]},
[{type,0,range,[{integer,0,-100},{integer,0,100}]}]}` — i.e. `-100..100 -> -100..100`, matching
the brief's claimed emitted spec exactly.

### Cross-language citations — spot-checked, all accurate

- `erl_parse.yrl:301` — `pat_expr -> prefix_op pat_expr : ?mkop1('$1', '$2').` — exact line,
  exact text.
- `v3_core.erl:2638-2641` — the two `pattern({op,...}, St) -> pattern(erl_eval:partial_eval(Op),
  St)` clauses are at lines 2638 and 2640-2641 in the actual OTP 28.5 source at
  `/opt/otp28-src/lib/compiler/src/v3_core.erl`; substance matches exactly.
- `erl_eval.erl:2204-2223` — `partial_eval/1` at line 2204, `ev_expr/1` clauses from 2214;
  `ev_expr({op,_,Op,L,R}) -> erlang:Op(ev_expr(L), ev_expr(R))` has no clause for `{var,...}`, so a
  variable operand throws, caught by `partial_eval`'s `catch`, falling through to the unevaluated
  `Expr` — confirms the brief's "silently declines... the moment it meets a variable" claim exactly.
- Gleam `lexer.rs` — `fn lex_number` is at line 1038 (brief cites 1038-1050) and swallows a
  leading `-` into `is_negative` at parse time; the `check_for_minus` / `eat_single_char(Token::
  Minus)` disambiguation the brief describes is present, close to the cited lines. Substance and
  line numbers both check out.
- Elm `Pattern.hs`'s `termHelp` (lines 33-73 as cited) has no `-`-prefixed alternative among its
  `oneOf` branches — confirmed by reading the function directly; the only path to a negative
  number would be through `Number.number`, which the brief correctly notes doesn't consume a
  leading `-` in this position.

### Overall verdict: **SOUND, WITH CAVEATS**

Every measured, checkable claim in the brief reproduced independently, from a fresh scratch
build, with files I wrote myself rather than the saved probes: the F51-staleness diagnosis, the
exact `negate/2` and `comparison/1` line numbers, both patches' exact diffs and line counts, the
"0 new conflicts" claim, the guard-exhaustiveness second bug, the eunit numbers and the
pre-existing-failure explanation (confirmed on the tracked tree, not just the scratch copy), the
end-to-end `Delta` spec, and every cross-language citation. No circularity was found: the brief's
measurements do not depend on trusting its own prior claims, and its patches, when reapplied by
hand from the same diff text, produce the same tracked-source-relative changes.

Two caveats, neither of which threatens the recommendation:

1. **Option A and Option B are not fully equivalent**, contrary to the brief's "identical results"
   framing — a double-negated literal (`- -5`) folds under Option A (recursively, arithmetically
   correctly) but not under Option B (`int_const/1` only unwraps one `e_neg`). This is a real gap
   in the battery's coverage, not a correctness defect in either patch, and it strengthens rather
   than weakens the case for Option A.
2. **The brief's justification for the lambda-parameter "freebie" is factually wrong** even
   though its conclusion is right: baseline does not "already accept" a negative literal lambda
   parameter today (it is refused by `to_param/1`'s catch-all); Option A is what makes it work, by
   removing the `e_neg` wrapper before `to_param/1` ever runs. The freebie is real; the brief just
   misattributes when it starts existing.

Recommendation (Option A) stands on independently re-derived evidence.
