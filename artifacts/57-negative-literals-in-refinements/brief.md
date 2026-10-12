# Ticket 57 / ENG-239 — a refinement cannot say `-5`, though a pattern can

**Status: OPEN — undecided.** This is a recommendation for David. Nothing under `wayfinder/` was
edited, no Linear state was touched, nothing was committed.
**Date:** 2026-10-11. **Repo rev:** `019533d`.
**Versions:** OTP 29 (erts 17.1), Elixir 1.20.4 (compiled with OTP 27), Gleam 1.19.1, Elm 0.19.0
(its package server is unreachable, see section 7).
**Everything below was run.** Probes are in `probes/` (index in `probes/README.md`), patches in
`patch-A.diff`, `patch-B.diff`, `patch-Barith.diff`.

---

## 0. The shortest version

The ticket asks where a fold belongs. Re-measured, **the premise under the question has moved and
the question is bigger than the ticket says**:

* Since F51 (2026-08) `-5` is no longer `0 - 5`. The checker is handed `{e_neg,_,{e_int,_,5}}`, and
  the parser **already folds a negated float literal** in `negate/2` ("so `Sign(-1.5)` is a head",
  F51 finding 2). Integers are the one literal left unfolded.
* A guard is hit by the same defect, and worse: `Sign(n) when n <= -1 -> ...` is **silently read as
  "no information"**, so the compiler reports `Sign is not exhaustive: no clause matches:
  Sign(<= -1)` — it asks for the clause that was just written. The ticket is about refinements; the
  bug is in `alternatives/1`'s comparand, which refinements and guards share.
* The literal `-5` has type `int`, not `-5..-5` (`type_of({e_neg,..})`, `bs_check.erl:2889`). So even
  a negative refinement that *is* writable today (`int where value < 0`) cannot be returned a
  negative literal. Folding only in the comparison does not fix this; folding at the grammar does.

**Recommendation: fold in the grammar (build A, one line, in `negate/2`).** Details and counter in
section 6.

---

## 1. The sub-decisions

**Gating question (ask this one alone): does `-5` become a literal at parse time, or stay a negation
node that the checker has to read?** Everything else follows from it:

1. **Gating — grammar or checker.** Answered by options 1 (grammar) vs 2/3 (checker) in section 5.
2. *Only if checker:* where the fold stops. Measured in section 4 (stop table). It does not arise if
   the answer to 1 is "grammar".
3. *Follows from 1:* whether guards keep agreeing with refinements. Measured: they do under **every**
   variant built, because both go through `alternatives/1` (`bs_check.erl:1910` and `:4985`). The
   disagreement the ticket fears needs a fold placed at the refinement site only; none was built
   because none is proposed.

---

## 2. Claim ledger

| # | Claim (source) | Probe | Result |
|---|---|---|---|
| 1 | `value >= -5`, `>= -5 and <= 5`, `>= 1 or <= -1` refused; `<= 3 or >= 10` and `!= 0` accepted (ticket table) | `corpus.sh` rows R1-R5, `corpus.reference.out` | **confirmed**, all five rows |
| 2 | Diagnostic is `opaque_refinement`, text recommends a comparison on `value` (ticket) | `corpus.sh`; `/tmp` compile of `type T = int where value >= -5` | **confirmed**. The real text has two more paragraphs than the ticket quotes (the `WellFormed(value)` O(n)-tier note) |
| 3 | `-5` reaches the checker as `{e_op,'-',{e_int,0},{e_int,5}}`; yecc `expr -> '-' expr` builds it (ticket) | `parse_shape.sh` | **refuted, stale.** It is `{e_neg,{2,29},{e_int,{2,30},5}}` since F51. `0 - 5` is still an `e_op` only when written `0 - 5` |
| 4 | "`refinement -> expr`" (ticket) | `bs_parser.yrl:221` | trivially off: it is `refinement -> expr_low` |
| 5 | A refinement is deliberately an `expr` so it and a guard cannot disagree; "`bs_check.erl` says so at the `refinement` rule" (ticket) | `bs_parser.yrl:219-221` (the comment is in the **parser**), `bs_check.erl:1910`, `:4985` | **confirmed** in substance: `refine/3` and `apply_guard/3` both call `alternatives/1` |
| 6 | The pattern grammar is the only place a negative literal is read (ticket, implied) | `bs_parser.yrl:397,401,444,463-466,471-472,947` | **partly.** Four sites read it: pattern `'-' integer` (`:397`), `'-' float` (`:401`), `int_lit` (`:471-472`, used by `rel_test` and `bin_segment`), and `negate/2` for **float** expression literals (`:947`). Integer expression literals are the gap |
| 7 | "Every refinement containing a negative integer literal is refused, whatever the operator" | corpus C1..C12, E2, E3 | **confirmed**, including `-0`, `-(5)`, `-(-5)`, `- 5`, `-0xFF`, a 23-digit magnitude. Positive hex `0xFF` is accepted (C10) |
| 8 | Guards and refinements share `expr`; show what a guard with `-5` does | `semantics.sh` section 5 | **confirmed, and worse than stated.** Guard `n <= -1` is unread: `Sign is not exhaustive / no clause matches: Sign(<= -1)`. Control `n < 0` is accepted |
| 9 | `subtract(-10..10, 0)` is `-10..-1 \| 1..10` (ticket) | `semantics.sh` section 6 | **confirmed**: `-10..-1 \| 1..10` |
| 10 | "a residual the compiler prints and the surface cannot accept" (ticket) | `semantics.sh`, `f25_negative.sh` | **partly.** As a *head line* the residual is pasteable: `K(>= -10 and <= -3) -> ...` is valid pattern syntax. What the surface cannot say is the *type* (the refinement that names the domain). Today the signed bounded domain cannot even be declared, so the residual arises only from guards over bare `int` |
| 11 | F2's five scenarios are all non-negative (ticket) | `intervals_tests.erl:293` | **partly.** The refinements are, but the F2 test file already uses `Classify(<= -1)` as a *pattern* |
| 12 | Ticket 38 is not blocked (ticket) | `semantics.sh` section 2 | **confirmed, with a new coupling.** `n / -0` is accepted today (not recognised as provably zero); build A refuses it. See option 1 |
| 13 | (new) The literal `-5` has the type `-5..-5` | `semantics.sh` section 1 | **refuted.** It is typed `int`; `public Neg Lit() = -5` against `int where value < 0` fails with `not covered by the declared return type: int >= 0` on **the unpatched compiler** |
| 14 | (new) Admitting negatives in refinements is enough to write `value == -5` | corpus C6, E1, E4 | **refuted.** `value == K` fails for *every* K, including `value == 5` and `value == 0`, on the unpatched compiler: `compile: ... bad range type`. See the unrelated defect below |

**One unrelated defect found while testing (needs its own ticket).** `bs_emit:int_part/1`
(`bs_emit.erl:1607`) writes `{type,_,range,[Lo,Hi]}` for a one-integer interval. `erl_lint` requires
`Lo < Hi` (`erl_lint.erl:4052-4054`), so every singleton refinement (`value == 5`, `== 0`) dies in
`erlc` with `bad range type` rather than a B# diagnostic. It predates this ticket (probe E1 on the
unpatched build) but it is the first thing someone will hit after `value == -5` starts parsing.

---

## 3. Neighbour survey

| Language | `-5` in an expression | in a pattern | in a guard | Where the fold is | Evidence |
|---|---|---|---|---|---|
| **Erlang** | `{op,1,'-',{integer,1,5}}` | the same node | the same node | **Checker/lint, never the parser.** `erl_parse.yrl` has one `prefix_op` rule for `expr` (`:299`) and `pat_expr` (`:331`) and builds `{op,A,'-',X}`; `erl_lint:is_pattern_expr` and the range-type check call `erl_eval:partial_eval` (`erl_lint.erl:2473`, `:4052`), which folds `-5` and `2+3` | `probes/neighbour_erlang.out` |
| **Elixir** | `{:-, [line: 1], [5]}` | `{:-, [line: 1], [5]}` | `{:-,..,[5]}` | **Never a literal in the AST.** `-5`, `- 5`, `-(5)` are the same unary node; the match/guard expander accepts it. `-x` in a pattern is refused (`cannot invoke remote function :erlang.-/1 inside a match`), so the constant test is "unary minus over a number" | `probes/neighbour_elixir.out`. Parser source (`elixir_parser.yrl`) is not in the install, so no file:line |
| **Gleam** | `-5` accepted | `-5`, `-5.0`, `-0x10` accepted; `- 5`, `-(5)`, `0 - 5` are **syntax errors** | `n >= -5`, `n == -5` accepted; `n >= - 5`, `-{5}`, `-n` are syntax errors; `0 - 5` and `2 + 3` accepted | **Grammar.** A negative integer literal is a literal in pattern and guard alike, with no space allowed. The emitted abstract form is `{integer,1,-5}` in the pattern and in the guard, which is exactly build A's output | `probes/neighbour_gleam.out`. Binary only; no compiler source, so the citation is the probe |
| **Elm** | not probed | not probed | n/a | **not obtainable.** `elm make` needs `package.elm-lang.org`, which is unreachable (`HTTP PROBLEM`). Nothing is claimed about Elm |

Reading: Erlang and Elixir keep a unary-minus node and fold in the checker. Gleam folds in the
grammar and refuses everything but the exact `-5` token pair. B# is currently a hybrid that no one
chose: patterns and floats fold in the grammar, integer expressions do not. The two real precedents
both allow the same set under their design; neither is "wrong".

---

## 4. Measurements

### 4.1 Acceptance matrix (34 programs; `corpus.sh`, joined by `matrix.py`)

`want` is the post-fix wish. `N*` rows, `F1` and `P3` are negative controls that **must stay refused**.

```
case                   want      reference A         B         Barith
R1_ge_neg5             accepted  refused   accepted  accepted  accepted     value >= -5
R2_neg5_and_5          accepted  refused   accepted  accepted  accepted
R3_1_or_neg1           accepted  refused   accepted  accepted  accepted
R4_le3_or_ge10         accepted  accepted  accepted  accepted  accepted
R5_ne0                 accepted  accepted  accepted  accepted  accepted
C1_gt_neg1             accepted  refused   accepted  accepted  accepted     value > -1
C2_ge_paren5           accepted  refused   accepted  accepted  accepted     value >= -(5)
C3_ge_0minus5          accepted  refused   refused   refused   accepted     value >= 0 - 5
C4_neg5_le_value       accepted  refused   accepted  accepted  accepted     -5 <= value
C5_ge_neg0             accepted  refused   accepted  accepted  accepted     value >= -0
C6_eq_neg5             accepted  refused   refused   refused   refused      singleton bug, not the fold
C7_ne_neg5             accepted  refused   accepted  accepted  accepted
C8_neg_neg5            accepted  refused   accepted  accepted  accepted     value >= -(-5)
C9_space               accepted  refused   accepted  accepted  accepted     value >= - 5
C10_hex                accepted  accepted  accepted  accepted  accepted     value >= 0xFF
C11_neg_hex            accepted  refused   accepted  accepted  accepted     value >= -0xFF
C12_big                accepted  refused   accepted  accepted  accepted     value >= -99999999999999999999999
C13_2plus3             accepted  refused   refused   refused   accepted     value >= 2 + 3
C14_pos_paren          accepted  accepted  accepted  accepted  accepted
E1_eq_pos5             accepted  refused   refused   refused   refused      singleton bug, unpatched
E2_neg_only_range      accepted  refused   accepted  accepted  accepted     -10..-3
E3_le_neg1             accepted  refused   accepted  accepted  accepted
E4_eq_0                accepted  refused   refused   refused   refused      singleton bug, unpatched
N1_value_ge_value      refused   refused   refused   refused   refused      CONTROL
N2_ge_x_plus_1         refused   refused   refused   refused   refused      CONTROL  value >= x + 1
N3_ge_n                refused   refused   refused   refused   refused      CONTROL  value >= n
N4_ge_call             refused   refused   refused   refused   refused      CONTROL
N5_float               refused   refused   refused   refused   refused      CONTROL  int where value >= 1.5
F1_float_neg           refused   refused   refused   refused   refused      float refinement, ticket 58's ground
P1_rel_neg             accepted  accepted  accepted  accepted  accepted
P2_lit_neg             accepted  accepted  accepted  accepted  accepted
P3_rel_paren           refused   refused   refused   refused   refused      CONTROL  pattern `<= -(1)` stays a syntax error
G1_guard_neg           accepted  refused   accepted  accepted  accepted     the guard with `-1`
G2_guard_neg_exhaust   accepted  accepted  accepted  accepted  accepted
```

`matrix.py` prints `negative controls accepted by some build: none`. The harness cannot read a VM
crash as "refused" (it exits 2); its first version did exactly that (`bsc:main/0 is not exported`
reported as 30 refusals) and was fixed before any number here was recorded.

**Where each fold stops (sub-decision 2, if checker):**

| form | A grammar | B checker, unary | Barith checker, `+ - *` |
|---|---|---|---|
| `-5`, `- 5`, `-(5)`, `-(-5)`, `-0`, `-0xFF`, 23-digit magnitude | yes | yes | yes |
| `0 - 5`, `2 + 3` | no | no | yes |
| `value >= n`, `value >= x + 1`, `value >= value`, `value >= F(1)` | refused | refused | refused |

### 4.2 What else changes (`semantics.sh`, `options_program.sh`, `f25_negative.sh`)

| observation | reference | A | B | Barith |
|---|---|---|---|---|
| `public Neg Lit() = -5`, `Neg = int where value < 0` | refused, `int >= 0` uncovered | **accepted** | refused | **accepted** |
| `Floor() -> -100` into `Delta = -100..100` | n/a (Delta unwritable) | accepted | **refused** | accepted |
| `n / -0` (ticket 38: provably zero is refused) | **accepted** | refused: `always zero` | accepted | refused |
| `0 - 5` into a negative type | refused | refused | refused | refused |
| guard `n <= -1`, `n >= 0`, no catch-all | "not exhaustive: `Sign(<= -1)`" | accepted | accepted | accepted |
| F2.5 over `-10..10`, guard `n > -3` | refinement refused | residual `K(>= -10 and <= -3) -> ...` | same | same |
| F2.5 unsigned control, guard `n > 128` over `0..255` | `K(>= 0 and <= 128)` | same | same | same |
| emitted guard for `n <= -1` | `{op,..,'=<',N,{op,..,'-',{integer,..,1}}}` | `{op,..,'=<',N,{integer,..,-1}}` | as reference | as reference |
| emitted `Lit() -> -5` | `{op,{3,10},'-',{integer,{3,11},5}}` | `{integer,{3,11},-5}` | as reference | as reference |
| runtime values, 21 expressions with `-N` (`arith_diff.sh`) | | identical to reference (control fires) | n/a | n/a |

Third case of the options program in `options_program.out`: with build A `Trend`
(`when d <= -1`, `when d >= 1`, `Trend(0)`) is accepted and exhaustive over `int`.

### 4.3 Diff sizes

| build | files | lines added | lines removed |
|---|---|---|---|
| A, grammar | 1 (`bs_parser.yrl`) | **1** | 0 |
| B, checker, unary minus | 1 (`bs_check.erl`) | **8** | 0 |
| Barith, checker `+ - *` and `type_of` | 1 (`bs_check.erl`) | **15** | 0 |

Yecc on `bs_parser.yrl`: `6 shift/reduce, 0 reduce/reduce` for the unpatched file and for build A
(A adds a clause to a helper function, not a production). B and Barith do not touch the grammar.

### 4.4 Generated shape and size (`shape.sh`)

| | reference | A |
|---|---|---|
| parsed body of `F(x) -> -5` | `{e_neg,{3,9},{e_int,{3,10},5}}`, 14 words | `{e_int,{3,10},-5}`, 7 words |
| parsed guard `x >= -5` | 30 words | 23 words |
| `Code` chunk of the `.beam` (md5) | `qYemaZfXzTTl` | `qYemaZfXzTTl` (**identical**; `erlc` folds `-5` anyway) |
| whole `.beam` | 1280 bytes | 1264 bytes |
| diagnostic column on a `-5` literal | at the `-` (col 9) | at the digit (col 10) |

B and Barith leave the parse tree and the output byte-identical to the reference.

### 4.5 Compile time (`timing.sh`, `timing_summary.py`)

5 interleaved rounds (each build in a fresh VM) x 40 timed runs after a 10-run warm-up, in-VM
`timer:tc`. Cells are the median of the five round-medians, with the range of those medians, in
microseconds. 300-declaration synthetic file: `type Ti = int where value >= i and value <= i+1000`
(`pos`), and the same with `value >= -i` (`neg`; refused on the reference, so that cell measures the
error path and is not comparable).

```
workload           base               A                  B                  Barith
parse examples     1447 [1394..1546]  1581 [1426..2263]  1446 [1373..1547]  1456 [1400..1550]
check examples     6780 [6512..7555]  6611 [6259..9557]  6395 [6241..7125]  7054 [6394..7411]
parse synth-pos     881 [ 857..1269]   859 [ 832.. 889]   874 [ 832..1223]   856 [ 819.. 882]
check synth-pos    1934 [1910..2368]  1964 [1876..2146]  1985 [1932..2560]  1945 [1889..1974]
parse synth-neg    1026 [ 989..1103]  1046 [ 975..1056]  1063 [1021..1301]  1056 [ 978..1217]
```

Nothing separates. The one cell that looks different (A, `parse examples`, +9%) has a range that
overlaps the base range, comes from one slow round (2263), and has no mechanism: `negate/2` gains one
clause and a rough grep finds no negative integer literal in `compiler/examples/*/*.bs` at all. I would not cite it as a cost. The
`check examples` ranges are 15-25% wide on this machine, so differences under that are not resolvable.

### 4.6 Existing suite

1437 pass / 11 fail in the reference (verifier's trees: 1438 / 10; the one difference is `cli_tests:escript_entry_point_exists_test`, which passes when `rebar.config` is present; failing set identical across builds), A, B and Barith alike, with an identical failing set
(`probes/eunit.summary.out`; the 11 are environmental, see section 7).

---

## 5. Three options, as programs

All three accept the program the ticket wants. They differ on the next three lines.

```csharp
type Delta = int where value >= -100 and value <= 100      // refused today

public Delta Floor()
Floor() -> -100                                            // (a)

public atom Trend(int d)
Trend(d) when d <= -1 -> :falling                          // (b)
Trend(d) when d >= 1  -> :rising
Trend(0)              -> :flat

public int PerStep(int total)
PerStep(total) -> total / -0                               // (c)
```

`options_program.sh` output: reference `refinement not readable` at line 2; A `(c) is always zero`
only; B `(a) Floor returns a value its signature does not declare` only; Barith `(c)` only.

### Option 1 — fold in the grammar (build A)

* **(a)** accepted, **(b)** accepted, **(c) refused**: `the right-hand side of '/' in PerStep is always zero`.
* **Compiler delta (1 line, `bs_parser.yrl` `negate/2`):**
  `negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};` beside the existing float clause.
  No new symbol, no new pass. `-(-5)` becomes `5` by two reductions; `-(5)` and `- 5` fold because
  parentheses and whitespace leave no trace in the tree.
* **Evidence:** the whole corpus of section 4.1 except `0 - 5`, `2 + 3` and the singleton bug;
  guards fixed too; literal `-5` gets type `-5..-5`; 21 run-time values unchanged; `.beam` code
  chunk byte-identical; parse tree smaller; compile time unmeasurably different.
* **Strongest counterargument — and its answer.** The ticket's: *"narrowing the grammar at one site
  reintroduces the split."* Build A is not a refinement-site rule; `negate/2` runs for every
  `expr_low`, so the refinement, the guard and the body see the same node. Measured, they agree
  (rows G1, R1). The split the ticket fears would need a refinement-only grammar rule, which nobody
  has proposed. **The real counter is different:** A removes the user's negation from every tree, not
  only refinements, so `n / -0` starts being refused (a program that compiled yesterday stops
  compiling; consistent with ticket 38's "a provably-zero divisor is refused", but it is a visible
  behaviour change) and a diagnostic on a `-5` literal moves one column right.

### Option 2 — fold in the checker, unary minus only (build B)

* **(a) refused**, **(b)** accepted, **(c)** accepted (crashes at run time).
* **Compiler delta (8 lines, 9 with a blank, `bs_check.erl`):** a `const_int/1` helper (literal, or `e_neg` of a
  constant) and two `comparison/1` clauses after the atom/string ones (`bs_check.erl:5016-5017`
  is where the bare-literal clauses live).
* **Evidence:** fixes every refinement and guard in the corpus except `0 - 5`, `2 + 3`; parse tree
  and `.beam` byte-identical to the reference; compile time unmeasurably different.
* **Strongest counterargument.** It fixes the comparand and nothing else: `Floor() -> -100` is still
  refused (the literal is `int`, so `Delta` is writable and not inhabitable by a negative literal),
  and the error message for it ("`int >= 0` not covered") is actively wrong about a negative number.
  Fixing that needs a second fold in `type_of`, i.e. option 3's extra lines, so B is not a stable
  stopping point.

### Option 3 — fold in the checker, with arithmetic (build Barith)

* **(a)** accepted, **(b)** accepted, **(c) refused**; also accepts `value >= 0 - 5` and `>= 2 + 3`.
* **Compiler delta (15 lines, 16 with a blank):** option 2's helper extended to `+ - *` over constants, plus one
  `type_of({e_neg,_,{e_int,..}})` clause giving `-N` the singleton range.
* **Evidence:** the widest acceptance in the matrix; `value >= n` and `value >= x + 1` still refused.
* **Strongest counterargument.** It is the only option that accepts `0 - 5`, and no one writes
  `0 - 5` or `2 + 3` as a bound. It buys breadth nobody asked for and creates a rule ("a constant
  expression is any `+ - *` over literals") that the pattern grammar does not share, so
  `Sign(<= 2 + 3)` stays a syntax error while `value <= 2 + 3` is accepted: **the patterns/refinements
  disagreement is relocated, not removed.**

---

## 6. Recommendation

**Option 1: fold the integer literal in `negate/2`.** It is the answer the code already gave for
floats (F51 folded `-1.5` for the same reason the ticket wants `-5`), it is one line, it removes the
disagreement between patterns and expressions instead of re-implementing it in the checker, and it is
the only variant that also fixes the literal's *type* (row `Neg Lit()` / `Floor()`), which the
ticket did not know was broken. The ticket's reason to prefer the checker (one grammar, one meaning)
is satisfied by A as well, because A changes `expr_low`, not `refinement`.

Do alongside it, because they are the same sentence for a user:
1. The failing tests first (CLAUDE.md): R1-R3, G1, `Floor`, plus `n / -0` and the three `N*`
   controls as refused. The only existing assertions on `opaque_refinement` are
   `intervals_tests.erl:53,60` and neither involves a negative.
2. Raise a separate ticket for the singleton-range emission bug (claim 14). It will otherwise be
   found by whoever first writes `value == -5`.
3. The diagnostic text still tells the reader to "write a comparison on `value`" for `value >= 0 - 5`.
   One clause ("against a literal") would stop it recommending what it just refused. Optional.

**What would change it:**
* If David wants `value >= 2 + 3` or `Sign(<= 2 + 3)` to be legal, the question becomes a constant
  expression language shared by patterns and refinements; then option 3 plus the same helper in the
  pattern grammar, and the grammar answer is wrong. Nothing in the repo asks for it.
* If the project wants to keep the written form for tooling (a formatter, `ibs` echoing the user's
  `-(-5)`, a redundant-negation lint), keep the `e_neg` node and take option 3 with the `type_of`
  clause. The cost is 15 lines instead of 1.
* If a refused `n / -0` is judged a breaking change to ticket 38's surface, take option 2 and accept
  that negative literals cannot flow into a signed refinement.

---

## 7. Honest limitations

* **Elm was not probed.** The compiler needs `package.elm-lang.org` for `elm/core`; the request
  fails (`HttpExceptionRequest ... /all-packages`). I make no claim about Elm.
* **Gleam and Elixir:** only binaries/beams were available. The citations are probe runs; no
  parser source file:line is given for either. Erlang citations are to the OTP 29 stdlib source in
  the conda env (`stdlib-8.1/src/erl_parse.yrl`, `erl_lint.erl`), with line numbers checked.
* **The existing eunit suite is a differential, not a green suite.** There is no `rebar3`. I compiled
  all 73 test modules with `erlc`, built a bsc escript per build with `escript:create`
  (`probes/mkesc.escript`) and ran `eunit:test/2` one build at a time (`probes/runeunit.sh`).
  Result, `probes/eunit.summary.out`: **1437 passed, 11 failed in each of the four builds, and the
  failing set is identical** (`cmp`). The 11 are environment, not this ticket: they include
  `binary_tests:the_grammar_has_exactly_its_named_conflicts_test` (wants the rebar layout),
  `cli_tests:escript_entry_point_exists_test`, the UTF-8 locale tests, and the two
  `diagnostic_*` gate tests. So no existing test pins an integer `e_neg`, and none broke under A, B
  or Barith. `./bin/verify.sh` and its gates were **not** run, and nothing here counts as "gates pass
  twice". A first attempt with the four suites in parallel was cancelled by a subprocess timeout
  at 306 tests; that run is discarded.
* **Only A, B and Barith were built.** A *refinement-only* grammar rule (the literal reading of
  "mirror `int_lit`" at the `refinement` production) was not built: it would duplicate the
  comparison grammar of `expr_low` and is the shape the ticket itself argues against. A *refine-only*
  checker fold (the real way to split refinements from guards) was not built for the same reason.
* **Timing:** microsecond medians in a shared VM; the `check examples` cells carry a 15-25%
  spread, so only differences above that are real. Nothing exceeded it.
* **Not measured:** call cost (the generated code chunk is byte-identical, so there is no run-time
  difference to measure); `erts_debug:size` of a module's environment beyond the parse term.
* The probes' `want` column states the post-fix wish; `!!` rows on the reference are the bug being
  reported, not probe failures.


## Verification note

Independently verified: `verification.md` (VERIFIED WITH CORRECTIONS); no circular probe found. Corrections applied or to carry:

- Diff sizes are 1 / 9 / 16 added lines counting blanks (1 / 8 / 15 non-blank).
- The `value == K` / `bad range type` defect is **not** an OTP 29 artefact: `-type t() :: 5..5.` fails on OTP 25.3, 28 and 29 (`erl_lint.erl:4053` in OTP 29, line 3443 in OTP 28), and unpatched `bsc` built on OTP 28 fails `value == 5` and `value == 0` the same way. The "separate defect" claim stands.
- `f25_negative.out` has no Barith column although the table says Barith is the same; the verifier re-ran it and Barith is the same, but the committed output should be regenerated with all four builds.
- Do not cite whole-beam md5s (they change run to run); the Code-chunk md5 and byte sizes are stable.
- Timing is in-VM lex/parse/check, interleaved, and the verifier's re-run found no separation. The `check synth-neg` row is slower on patched builds (ref 1493 vs A 2375 us) only because the reference refuses early.
- Extra inputs the verifier ran: `-(-5)`, `- 5`, `-0x10`, `-9223372036854775808`, `--5` accepted by A, B and Barith; `-(1+2)` by Barith only; `Well{Z = -3}` with `Z: Depth` (a refinement with negative bounds) accepted by A and Barith but refused by B. Patterns already accept `- 5` with a space on the reference, a precedent for A.
- The brief's "want" column is the author's wish, so its `!!` rows are not independent tests.
