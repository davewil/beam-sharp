# ENG-299 — a broken buffer: tree-sitter as the LSP's parse front, or yecc recovery

Measured 2026-09-14 at `a5e574a`, tree-sitter 0.25.10, OTP 28. Issue:
[ENG-299](https://linear.app/davewil/issue/ENG-299). Script: `eng299_broken_buffer.py` beside this
file; rerun with `python3 wayfinder/prototypes/eng299_broken_buffer.py` after `rebar3 escriptize` in
`compiler/`. The per-case table at the end is the script's output, pasted unedited.

## What was measured

Every `compiler/examples/**/*.bs` outside `exemplars/` — **23 files**, not the 16 the issue counted.
In each file the script takes the middle clause that is not the file's last declaration and breaks
the file five ways there. The issue named the five kinds; the edit points are this script's:

| break | edit |
|---|---|
| `mid_identifier` | delete from halfway through the body's first name to the end of the body |
| `unclosed_brace` | delete the last `}` of the first clause, from the target on, that has one |
| `half_head` | keep `Name(` and the first pattern; delete the rest of the clause |
| `dangling_arrow` | delete the body, keep `->` |
| `no_signature` | delete the function's signature |

115 slots, 88 measured. 27 do not apply: 10 target bodies hold no name (`-> :ok`), and 17 files
have no clause holding a `}` before their last declaration.

Each tree-sitter parse is compared with the unbroken file's parse, at two levels:

- **exact** — every declaration the edit did not touch is a top-level node of the same kind with the
  same source text;
- **symbols** — every such declaration is a node of the same kind, naming the same function, on the
  same line. This is what an outline, go-to-definition and "which function is the cursor in" read.

and classified:

- **recovered** — nothing lost, and the node at the cursor names the function being edited;
- **flagged** — something lost, and the tree carries an ERROR or MISSING node, so a server can tell;
- **silent** — something lost, and no ERROR or MISSING node: a wrong tree that looks right.

`bsc` is run on the same 88 files through one `--batch` manifest with `--diagnostics term`.

## Results

**tree-sitter, exact**

| break | recovered | flagged | silent | n/a |
|---|---|---|---|---|
| mid_identifier | 11 | 2 | 0 | 10 |
| unclosed_brace | 6 | 0 | 0 | 17 |
| half_head | 0 | 23 | 0 | 0 |
| dangling_arrow | 0 | 10 | 13 | 0 |
| no_signature | 23 | 0 | 0 | 0 |
| **all** | **40** | **35** | **13** | 27 |

**tree-sitter, symbols**

| break | recovered | flagged | silent | n/a |
|---|---|---|---|---|
| mid_identifier | 11 | 2 | 0 | 10 |
| unclosed_brace | 6 | 0 | 0 | 17 |
| half_head | 0 | 23 | 0 | 0 |
| dangling_arrow | 13 | 10 | 0 | 0 |
| no_signature | 23 | 0 | 0 | 0 |
| **all** | **53** | **35** | **0** | 27 |

**bsc**, first diagnostic per file: `parse_error` 55, compiles 13, and 20 checker diagnostics
(`name_arity_unfixed` 6, `unknown_callee` 4, `vacuous_arm` 3, `field_absent` 2, `unbound_variable` 2,
`arity_mismatch` 1, `behaviour_not_satisfied` 1, `valve_on_infallible` 1).

## What the numbers say

1. **`bsc` gives no structure for a buffer that does not parse.** 55 of 88 breaks end in a
   `parse_error`, each the only diagnostic, placed between 0 and 11 lines after the edit. The other 33
   breaks left text that parses, so they measure the checker, not recovery.
2. **tree-sitter never produced a silent tree at the symbol level.** 53 of 88 keep every declaration;
   the other 35 carry an ERROR or MISSING node. 34 of those lose one to four declarations; the 35th
   (`Shop/shop.bs`, `mid_identifier`) loses none, and is flagged because the node at the cursor is
   the ERROR node holding `with { To`, with the intact `Pay` clause just before it.
3. **`half_head` is the costly break: 23 of 23 flagged.** A half-typed head merges with what follows
   it into one ERROR node, until something ends the node.
4. **The 13 exact-level silent trees are one mechanism, and it is a grammar defect.** A clause left at
   `->` takes the next line's `public` as its body, a variable, so the next signature parses without
   its visibility and no ERROR node appears. `bs_lexer.xrl` makes `public` and `private` keyword
   tokens, so the tree-sitter grammar accepts a tree the compiler's lexer cannot produce.
5. **Deleting a signature compiled in 13 of 23 files.** Observed, not examined here.

## The program, both ways

`compiler/examples/Fib/fib.bs`, with the author half way through typing a clause head at line 18:

```csharp
private list<int> Series(int n, int a, int b, list<int> acc)

Series(n
Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])

// Exhaustive with no catch-all: `[]` and `[x, ..rest]` partition list<int>.
private list<int> Reverse(list<int> xs, list<int> acc)

Reverse([], acc)          -> acc
Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])
```

`bsc`, the whole answer:

```
fib.bs:19:1: error: syntax error before: 'Series'
```

tree-sitter's top level from line 10 on:

```
line 10  signature  Fib
line 12  clause     Fib
line 13  clause     Fib
line 16  signature  Series
line 18  ERROR      Series   (holds the half head, the second Series clause and all of Reverse)
```

An outline built from that tree shows `Fib`, `Series` and the ERROR node named `Series`; `Reverse`
is missing until the head is closed. An outline built from `bsc` shows nothing.

## What each answer costs

**A — tree-sitter for structure, `bsc` on save for diagnostics.** No compiler change. The server
(ENG-305) reads the `name` field of `signature` and `clause` nodes, and the first `function_name`
inside an ERROR node. Owed with it: the grammar must refuse `public` and `private` as names
(finding 4), measured by this script's `dangling_arrow` row going to zero silent at the exact level;
tree-sitter 0.25's reserved-word rules are the candidate, not yet tried. While a head is half typed,
the declarations after it drop out of the outline.

**B — error recovery in `bs_parser.yrl`.** A feature file of its own: the parser resynchronises at a
declaration boundary and `with_stages` hands on a partial tree instead of stopping. What yecc offers
for this is unmeasured, and is the first thing that feature would check. It changes the compiler's
own front end, which every gate and the audition read.

## Round 1 — the question for David

**Q1.** In the Fib buffer above, `Reverse` drops out of the outline while line 18 is half typed, and
comes back when the head is closed. Is that acceptable for the outline and go-to-definition? Yes →
answer A. No → answer B.

## Decision — David, 2026-09-14

**Q1: No.** Answer B. The LSP's structure comes from the compiler's parser, and `bs_parser.yrl` gains
error recovery as its own feature:
[ENG-370](https://linear.app/davewil/issue/ENG-370), which blocks the server,
[ENG-305](https://linear.app/davewil/issue/ENG-305). Because tree-sitter's loss was the thing judged
unacceptable, the bar is higher than tree-sitter's: on all 23 `half_head` breaks, every declaration
after the broken clause must survive. ENG-370 also carries the two things nothing has measured yet:
whether yecc offers a recovery mechanism, and which `bsc` output carries the recovered declarations.

**Deferred: finding 4, `public` and `private` accepted as a variable by the tree-sitter grammar.**
Under answer B it no longer feeds the server, and affects only highlighting while a clause is being
typed, so no issue is filed. What fixing it would need: the grammar refuses both words wherever
`bs_lexer.xrl` tokenises them as keywords (tree-sitter 0.25's reserved-word rules are the candidate,
untried), measured by this script's `dangling_arrow` row reaching zero silent at the exact level,
with `editor/bin/check-corpus.sh` still green.

## Follow-up — reserving the lexer's keywords, 2026-09-14

Asked by David after the decision: *"I thought one of tree-sitter's key strengths was error
recovery?"* It is, and the results above show it recovering. The question was whether its losses
come from tree-sitter or from this grammar, since finding 4 showed the grammar does not reserve
`public` and `private`, and most `half_head` losses swallowed a signature starting with one of them.

**Probe.** A copy of the grammar in scratch, renamed so its compiled library cannot replace the
shipped one, with every keyword `bs_lexer.xrl` tokenises reserved:

```js
reserved: {
  global: $ => ['module', 'type', 'when', 'using', 'behaviour', 'behavior',
                'public', 'private', 'record', 'with', 'switch', 'var',
                'raise', 'fn', 'and', 'or', 'where', 'true', 'false'],
},
```

All 23 clean corpus files still parse with no ERROR node. Rerun with
`ENG299_GRAMMAR=<grammar dir> python3 wayfinder/prototypes/eng299_broken_buffer.py`.

| break | recovered | flagged | silent | change from the shipped grammar |
|---|---|---|---|---|
| mid_identifier | 11 | 2 | 0 | none |
| unclosed_brace | 6 | 0 | 0 | none |
| half_head | 0 | 23 | 0 | **none: identical losses in all 23, `Reverse` still lost in Fib** |
| dangling_arrow | 14 | 9 | 0 | exact level: silent 13 → 0, recovered 0 → 14 |
| no_signature | 23 | 0 | 0 | none |
| **all** | **54** | **34** | **0** | the exact level now matches the symbol level |

bsc's column is unchanged, as it should be: the compiler was not touched.

**What this shows.**

1. **Finding 4's fix works and costs nothing on the corpus.** Reserving the keywords removes every
   silent tree.
2. **The `half_head` loss is not about keywords.** With `private` reserved, `Series(n` still takes
   the second `Series` clause and all of `Reverse` into one ERROR node. A clause head has no closing
   token until `)`, B# declarations have no terminator, and `bs_lexer.xrl` discards whitespace
   (`{WS}+ : skip_token`), so nothing in the grammar says where the half-typed head ended. tree-sitter's
   recovery is generic: it does not know that `private` must start a declaration.
3. **This corrects Q1's framing.** Answer B was offered as the way to keep `Reverse`. Nothing
   measured shows that it would: a recovering `bs_parser.yrl` meets the same missing boundary. What
   keeps `Reverse` in either parser is a recovery rule that uses something the grammar does not
   carry, such as a declaration starting at column 0. All 332 top-level declarations in the 23
   corpus files do start there, and nothing in the lexer or parser requires it. Whether either
   parser can recover on that rule is unmeasured.

## Round 2 — the question for David

**Q2.** Q1 asked whether losing `Reverse` is acceptable, and the answer was No. That answer stands on
its own terms; what changed is that the loss belongs to B#'s grammar, not to tree-sitter. Should
ENG-370 stay as filed — `bs_parser.yrl` recovery, with keeping `Reverse` as its bar — or should the
structure source be reopened before ENG-370 starts?

**Answer, David 2026-09-14: reopen it — try the column-0 rule in tree-sitter first.** The decision
above no longer stands; ENG-299 is open again and ENG-370 waits on it.

## Per case

| file | break | exact tree | symbols | lost (exact) | enclosing fn | bsc first diagnostic | bsc diagnostics |
|---|---|---|---|---|---|---|---|
| Aliasing/aliasing.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Aliasing/aliasing.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Aliasing/aliasing.bs | half_head | flagged | flagged | 1 of 15: clause Pick | yes | `parse_error` +1 lines from the edit | 1 |
| Aliasing/aliasing.bs | dangling_arrow | flagged | flagged | 1 of 15: clause Pick | yes | `parse_error` +1 lines from the edit | 1 |
| Aliasing/aliasing.bs | no_signature | recovered | recovered | 0 of 15:  | n/a | `unknown_callee` +15 lines from the edit | 1 |
| Counter/counter.bs | mid_identifier | recovered (ERROR node) | recovered (ERROR node) | 0 of 13:  | yes | `parse_error` +11 lines from the edit | 1 |
| Counter/counter.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Counter/counter.bs | half_head | flagged | flagged | 4 of 13: type_alias, type_alias, signature HandleCast, clause HandleCast | yes | `parse_error` +11 lines from the edit | 1 |
| Counter/counter.bs | dangling_arrow | flagged | flagged | 1 of 13: type_alias | yes | `parse_error` +11 lines from the edit | 1 |
| Counter/counter.bs | no_signature | recovered | recovered | 0 of 13:  | n/a | `behaviour_not_satisfied` -11 lines from the edit | 1 |
| Escalate/escalate.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Escalate/escalate.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Escalate/escalate.bs | half_head | flagged | flagged | 3 of 8: type_alias, signature Ceiling, clause Ceiling | yes | `parse_error` +9 lines from the edit | 1 |
| Escalate/escalate.bs | dangling_arrow | flagged | flagged | 2 of 8: type_alias, signature Ceiling | yes | `parse_error` +9 lines from the edit | 1 |
| Escalate/escalate.bs | no_signature | recovered | recovered | 0 of 8:  | n/a | compiles | 0 |
| Fib/fib.bs | mid_identifier | recovered | recovered | 0 of 9:  | yes | `name_arity_unfixed` at the edit | 1 |
| Fib/fib.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Fib/fib.bs | half_head | flagged | flagged | 4 of 9: clause Series, signature Reverse, clause Reverse, clause Reverse | yes | `parse_error` +1 lines from the edit | 1 |
| Fib/fib.bs | dangling_arrow | flagged | flagged | 1 of 9: clause Series | yes | `parse_error` +1 lines from the edit | 1 |
| Fib/fib.bs | no_signature | recovered | recovered | 0 of 9:  | n/a | `unknown_callee` -3 lines from the edit | 1 |
| Foreign/foreign.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Foreign/foreign.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Foreign/foreign.bs | half_head | flagged | flagged | 2 of 22: signature PortOr, clause PortOr | yes | `parse_error` +6 lines from the edit | 1 |
| Foreign/foreign.bs | dangling_arrow | silent | recovered | 1 of 22: signature PortOr | yes | `parse_error` +6 lines from the edit | 1 |
| Foreign/foreign.bs | no_signature | recovered | recovered | 0 of 22:  | n/a | compiles | 0 |
| Frame/frame.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Frame/frame.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Frame/frame.bs | half_head | flagged | flagged | 1 of 36: clause Name | yes | `parse_error` +1 lines from the edit | 1 |
| Frame/frame.bs | dangling_arrow | flagged | flagged | 1 of 36: clause Name | yes | `parse_error` +1 lines from the edit | 1 |
| Frame/frame.bs | no_signature | recovered | recovered | 0 of 36:  | n/a | `unknown_callee` +12 lines from the edit | 1 |
| Intake/intake.bs | mid_identifier | recovered | recovered | 0 of 5:  | yes | `name_arity_unfixed` at the edit | 1 |
| Intake/intake.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Intake/intake.bs | half_head | flagged | flagged | 2 of 5: signature Verdict, clause Verdict | yes | `parse_error` +7 lines from the edit | 1 |
| Intake/intake.bs | dangling_arrow | silent | recovered | 1 of 5: signature Verdict | yes | `parse_error` +7 lines from the edit | 1 |
| Intake/intake.bs | no_signature | recovered | recovered | 0 of 5:  | n/a | `vacuous_arm` +12 lines from the edit | 3 |
| Interop/interop.bs | mid_identifier | flagged | flagged | 1 of 9: signature Rows | yes | `parse_error` +2 lines from the edit | 1 |
| Interop/interop.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Interop/interop.bs | half_head | flagged | flagged | 2 of 9: signature Rows, clause Rows | yes | `parse_error` +2 lines from the edit | 1 |
| Interop/interop.bs | dangling_arrow | silent | recovered | 1 of 9: signature Rows | yes | `parse_error` +2 lines from the edit | 1 |
| Interop/interop.bs | no_signature | recovered | recovered | 0 of 9:  | n/a | compiles | 0 |
| Label/label.bs | mid_identifier | recovered | recovered | 0 of 16:  | yes | `field_absent` at the edit | 1 |
| Label/label.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 16:  | yes | `parse_error` +2 lines from the edit | 1 |
| Label/label.bs | half_head | flagged | flagged | 2 of 16: signature Names, clause Names | yes | `parse_error` +3 lines from the edit | 1 |
| Label/label.bs | dangling_arrow | silent | recovered | 1 of 16: signature Names | yes | `parse_error` +3 lines from the edit | 1 |
| Label/label.bs | no_signature | recovered | recovered | 0 of 16:  | n/a | compiles | 0 |
| Levels/levels.bs | mid_identifier | recovered | recovered | 0 of 5:  | yes | `name_arity_unfixed` at the edit | 1 |
| Levels/levels.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Levels/levels.bs | half_head | flagged | flagged | 2 of 5: signature OrElse, clause OrElse | yes | `parse_error` +5 lines from the edit | 1 |
| Levels/levels.bs | dangling_arrow | silent | recovered | 1 of 5: signature OrElse | yes | `parse_error` +5 lines from the edit | 1 |
| Levels/levels.bs | no_signature | recovered | recovered | 0 of 5:  | n/a | `vacuous_arm` +10 lines from the edit | 3 |
| Math/math.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Math/math.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Math/math.bs | half_head | flagged | flagged | 2 of 14: signature InBand, clause InBand | yes | `parse_error` +9 lines from the edit | 1 |
| Math/math.bs | dangling_arrow | silent | recovered | 1 of 14: signature InBand | yes | `parse_error` +9 lines from the edit | 1 |
| Math/math.bs | no_signature | recovered | recovered | 0 of 14:  | n/a | compiles | 0 |
| Parcel/parcel.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Parcel/parcel.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 12:  | yes | `parse_error` at the edit | 1 |
| Parcel/parcel.bs | half_head | flagged | flagged | 2 of 12: signature Weigh, clause Weigh | yes | `parse_error` +4 lines from the edit | 1 |
| Parcel/parcel.bs | dangling_arrow | silent | recovered | 1 of 12: signature Weigh | yes | `parse_error` +4 lines from the edit | 1 |
| Parcel/parcel.bs | no_signature | recovered | recovered | 0 of 12:  | n/a | compiles | 0 |
| Pipeline/pipeline.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Pipeline/pipeline.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Pipeline/pipeline.bs | half_head | flagged | flagged | 1 of 26: clause Validate | yes | `parse_error` +1 lines from the edit | 1 |
| Pipeline/pipeline.bs | dangling_arrow | flagged | flagged | 1 of 26: clause Validate | yes | `parse_error` +1 lines from the edit | 1 |
| Pipeline/pipeline.bs | no_signature | recovered | recovered | 0 of 26:  | n/a | `valve_on_infallible` -2 lines from the edit | 4 |
| Queue/queue.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Queue/queue.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 9:  | yes | `parse_error` +5 lines from the edit | 1 |
| Queue/queue.bs | half_head | flagged | flagged | 2 of 9: signature Route, clause Route | yes | `parse_error` +5 lines from the edit | 1 |
| Queue/queue.bs | dangling_arrow | silent | recovered | 1 of 9: signature Route | yes | `parse_error` +5 lines from the edit | 1 |
| Queue/queue.bs | no_signature | recovered | recovered | 0 of 9:  | n/a | compiles | 0 |
| Readings/readings.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Readings/readings.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Readings/readings.bs | half_head | flagged | flagged | 1 of 7: clause Classify | yes | `parse_error` +1 lines from the edit | 1 |
| Readings/readings.bs | dangling_arrow | flagged | flagged | 2 of 7: clause Classify, clause Classify | yes | `parse_error` +1 lines from the edit | 1 |
| Readings/readings.bs | no_signature | recovered | recovered | 0 of 7:  | n/a | compiles | 0 |
| Shop/Billing/Billing.bs | mid_identifier | recovered | recovered | 0 of 7:  | yes | `field_absent` at the edit | 1 |
| Shop/Billing/Billing.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Shop/Billing/Billing.bs | half_head | flagged | flagged | 2 of 7: signature Label, clause Label | yes | `parse_error` +6 lines from the edit | 1 |
| Shop/Billing/Billing.bs | dangling_arrow | silent | recovered | 1 of 7: signature Label | yes | `parse_error` +6 lines from the edit | 1 |
| Shop/Billing/Billing.bs | no_signature | recovered | recovered | 0 of 7:  | n/a | compiles | 0 |
| Shop/Collections/Ints/Ints.bs | mid_identifier | recovered | recovered | 0 of 8:  | yes | `unbound_variable` at the edit | 1 |
| Shop/Collections/Ints/Ints.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Shop/Collections/Ints/Ints.bs | half_head | flagged | flagged | 3 of 8: clause Length, signature Length, clause Length | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Collections/Ints/Ints.bs | dangling_arrow | flagged | flagged | 1 of 8: clause Length | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Collections/Ints/Ints.bs | no_signature | recovered | recovered | 0 of 8:  | n/a | `arity_mismatch` +8 lines from the edit | 1 |
| Shop/Discounts/Discounts.bs | mid_identifier | recovered | recovered | 0 of 8:  | yes | `unbound_variable` at the edit | 1 |
| Shop/Discounts/Discounts.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 8:  | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Discounts/Discounts.bs | half_head | flagged | flagged | 4 of 8: signature Charged, clause Charged, signature Steps, clause Steps | yes | `parse_error` +2 lines from the edit | 1 |
| Shop/Discounts/Discounts.bs | dangling_arrow | silent | recovered | 1 of 8: signature Charged | yes | `parse_error` +2 lines from the edit | 1 |
| Shop/Discounts/Discounts.bs | no_signature | recovered | recovered | 0 of 8:  | n/a | `unknown_callee` +5 lines from the edit | 1 |
| Shop/Pricing/Pricing.bs | mid_identifier | recovered | recovered | 0 of 19:  | yes | `name_arity_unfixed` at the edit | 1 |
| Shop/Pricing/Pricing.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Shop/Pricing/Pricing.bs | half_head | flagged | flagged | 2 of 19: signature Free, clause Free | yes | `parse_error` +4 lines from the edit | 1 |
| Shop/Pricing/Pricing.bs | dangling_arrow | silent | recovered | 1 of 19: signature Free | yes | `parse_error` +4 lines from the edit | 1 |
| Shop/Pricing/Pricing.bs | no_signature | recovered | recovered | 0 of 19:  | n/a | compiles | 0 |
| Shop/Reports/Totals.bs | mid_identifier | recovered | recovered | 0 of 8:  | yes | `name_arity_unfixed` at the edit | 1 |
| Shop/Reports/Totals.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Shop/Reports/Totals.bs | half_head | flagged | flagged | 2 of 8: signature Fully, clause Fully | yes | `parse_error` +2 lines from the edit | 1 |
| Shop/Reports/Totals.bs | dangling_arrow | silent | recovered | 1 of 8: signature Fully | yes | `parse_error` +2 lines from the edit | 1 |
| Shop/Reports/Totals.bs | no_signature | recovered | recovered | 0 of 8:  | n/a | compiles | 0 |
| Shop/Rows/Rows.bs | mid_identifier | recovered | recovered | 0 of 15:  | yes | `name_arity_unfixed` at the edit | 1 |
| Shop/Rows/Rows.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 15:  | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Rows/Rows.bs | half_head | flagged | flagged | 1 of 15: clause Build | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Rows/Rows.bs | dangling_arrow | flagged | flagged | 1 of 15: clause Build | yes | `parse_error` +1 lines from the edit | 1 |
| Shop/Rows/Rows.bs | no_signature | recovered | recovered | 0 of 15:  | n/a | `vacuous_arm` -9 lines from the edit | 3 |
| Shop/shop.bs | mid_identifier | flagged | flagged | 0 of 21:  | no | `parse_error` +4 lines from the edit | 1 |
| Shop/shop.bs | unclosed_brace | recovered (ERROR node) | recovered (ERROR node) | 0 of 21:  | yes | `parse_error` +4 lines from the edit | 1 |
| Shop/shop.bs | half_head | flagged | flagged | 2 of 21: signature Band, clause Band | yes | `parse_error` +4 lines from the edit | 1 |
| Shop/shop.bs | dangling_arrow | silent | recovered | 1 of 21: signature Band | yes | `parse_error` +4 lines from the edit | 1 |
| Shop/shop.bs | no_signature | recovered | recovered | 0 of 21:  | n/a | compiles | 0 |
| Wire/wire.bs | mid_identifier | n/a: no name of two or more characters in the body | | | | | |
| Wire/wire.bs | unclosed_brace | n/a: no clause holding `}` before the last declaration | | | | | |
| Wire/wire.bs | half_head | flagged | flagged | 1 of 17: clause Classify | yes | `parse_error` +1 lines from the edit | 1 |
| Wire/wire.bs | dangling_arrow | flagged | flagged | 1 of 17: clause Classify | yes | `parse_error` +1 lines from the edit | 1 |
| Wire/wire.bs | no_signature | recovered | recovered | 0 of 17:  | n/a | compiles | 0 |

corpus: 23 files; bsc on the clean corpus: 23 compile

**exact tree**

| break | recovered | flagged | silent | not applicable |
|---|---|---|---|---|
| mid_identifier | 11 | 2 | 0 | 10 |
| unclosed_brace | 6 | 0 | 0 | 17 |
| half_head | 0 | 23 | 0 | 0 |
| dangling_arrow | 0 | 10 | 13 | 0 |
| no_signature | 23 | 0 | 0 | 0 |
| **all** | 40 | 35 | 13 | 27 |

**symbols**

| break | recovered | flagged | silent | not applicable |
|---|---|---|---|---|
| mid_identifier | 11 | 2 | 0 | 10 |
| unclosed_brace | 6 | 0 | 0 | 17 |
| half_head | 0 | 23 | 0 | 0 |
| dangling_arrow | 13 | 10 | 0 | 0 |
| no_signature | 23 | 0 | 0 | 0 |
| **all** | 53 | 35 | 0 | 27 |


bsc first diagnostic, by tag: arity_mismatch 1, behaviour_not_satisfied 1, compiles 13, field_absent 2, name_arity_unfixed 6, parse_error 55, unbound_variable 2, unknown_callee 4, vacuous_arm 3, valve_on_infallible 1

