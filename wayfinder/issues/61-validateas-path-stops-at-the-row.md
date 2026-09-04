# 61 — `ValidateAs`'s pathed error stops at the row, and two renderings beside it

Type: defect
Status: **resolved 2026-08-24** — [ENG-243](https://linear.app/davewil/issue/ENG-243). All three
repairs landed; see [Answer](#answer) at the end.

Raised by exemplar 25d on 2026-08-24 while measuring per-row validation at result-set scale.
Repo body: this file; measurements in
[`25d_surface_probe.sh`](../prototypes/25d_surface_probe.sh) §3 and the valve-refusal control.

**Type: defect — the behaviour contradicts the reference, not an open question.** LANGUAGE.md §10
documents `ValidationError` as *"a path into the term plus the type expected there"* with `"(2)"`
as the spelling for a tuple component. F18 built the traversal and the record/list descent
(`(:error, (["[0]", ".Value"], "int"))` is its own shipped example); what 25d measured is that
the **tuple** descent is missing, plus two rendering defects in the same diagnostic channel.

## The measurement

`ValidateAs<list<WireRow>>` where `type WireRow = (int, string, term)`, handed
`[(1, "ada", :x), (2, :bad, :y)]` — the second row's second component an atom where text
belongs — returns:

```
(:error, (["[1]"], "(int, string, atom | int | tuple | list<term> | map | binary) | (int, string, atom | int | tuple | list<term> | map | binary)"))
```

Three defects in one term, separable:

1. **The path stops at the row.** The reference's path grammar says the error should be
   `(["[1]", "(2)"], "string")` — the row, the component, and the narrow expected type. At
   result-set scale the row index alone still earns its keep (it is the part 25d's write-up
   praises), but the component is where the repair happens, and ticket 23 hands this term to an
   agent whose next edit depends on it. The design's behaviour is in
   [`25d_db_lowering.erl`](../prototypes/25d_db_lowering.erl)'s hand lowering: `["[1]", "(2)"]`.
2. **`term` renders as its top decomposition.** The expected-type string spells every `term`
   component as `atom | int | tuple | list<term> | map | binary` — six alternatives the author
   wrote as one word. Second sighting the same day: the valve's cannot-fail diagnostic renders
   `(:ok, term, term)` the same way ([`25d_surface_probe.sh`](../prototypes/25d_surface_probe.sh)
   valve-refusal control). The author's alias is gone by diagnostic time, but `term` is not an
   alias — it is the name of the top, and printing its decomposition is strictly worse.
3. **A union member prints twice.** The expected type is the *same* tuple type twice, joined by
   `|`. Whatever produced the duplicate (two clauses' expectations concatenated without
   dedup, or a union normalisation missed on the diagnostic path), the printed algebra claims
   `X | X ≠ X`, which the checker itself knows is false.

## Why it matters more than a cosmetic

Ticket 23 §12 made the residual/diagnostic term the thing an agent repairs from, and ticket 43
fixed the prose truncation on the same principle: the term is the diagnostic. A path that stops
one level up hands the agent the wrong edit site; a `term` expansion and a duplicated member make
the expected-type string unusable as a paste. 25c found the residual too *wide* at protocol
scale; 25d's probe 5b control found the record-field residual too *shallow* (it names the tags
and omits the discriminating field). This ticket is the same family: **exactness held, legibility
lost** — three concrete, checkable repairs.

## What this owes

1. Tuple descent in the generated validator's error path — `"(N)"` segments, 1-based per the
   reference's own example.
2. `term` printed as `term` in diagnostic type rendering, everywhere.
3. Union dedup on the diagnostic path (or normalisation before rendering).
4. The gate first, red, per the standing rule — the probe's §3 expectation is the failing test.

## Cross-references

* **F18** — built `ValidateAs<T>`; the record and list descent work, the tuple one does not.
* **Ticket 23** — the diagnostic-as-a-term contract this under-delivers on.
* **Ticket 25 / exemplar 25d** — where it was found, and the write-up's finding 5.
* **Ticket 43** — the truncation rule; the *term* keeps everything, which is why rendering
  defects in the term are load-bearing.

## Answer

Resolved 2026-08-24, and defects 1 and 3 turned out to be **one defect, not two — and it was
never the descent**. The `"(N)"` machinery this ticket asked for has existed since F18
(`tuple_case({one, ...})` emits exactly those segments); what stopped it was `bs_types:t_absorb/1`
comparing *distinct* members only (`Q =/= P`), so a product unioned with itself survived twice.
`l_elem/1` does exactly that union for every `list<T>` — the element type is both the spine's
prefix and its open tail — so every list-of-tuples validator received a two-member union of one
product, the discriminator saw ambiguity where there was none, and the `{alts, _}` clause
correctly stopped blame at the row *of the type it was actually given*. Deduplicate the union and
the descent needs no change at all.

The same comparison had a live soundness edge beyond the ticket: two structurally different
spellings of one product (`(int, atom) | (atom, int)` written in both orders) each absorb the
other and **both vanish** — a union of two inhabited types reporting empty, measured red in
`types_tests` before the fix. `t_absorb/1` now folds to a **maximal antichain**: a product covered
by anything already kept is dropped (equality keeps the first), and a kept product covered by a
newcomer gives way. `m_absorb/1` had already fixed the dedup half — for maps only, on an earlier
day — which is why F18.7's record-in-list descent always passed while 25d's tuple rows failed:
a decided rule that never reached past its example.

Defect 2 lived in **two** printers, not one. `to_string/1` renders `ValidationError`'s expected
type; the valve's cannot-fail diagnostic renders through `to_pattern/1`; both now print the exact
top as `term`. A *partial* residual is untouched — nothing short of the whole top takes the
spelling — so "the residual is a set the author must enumerate" holds everywhere enumeration says
anything, which dissolves the objection `bs_api` recorded when it met this defect earlier and
patched it locally: that local patch is retired, the rule lives in the printers. (`_` was
considered and refused for `to_pattern/1`: ticket 12 §2 makes a catch-all illegal over a closed
residual, and a diagnostic must not recommend a form the checker refuses.)

Measured at the boundary afterwards, the probe's §3 form returns
`(:error, (["[1]", "(2)"], "string"))` — row, component, narrow type, the reference's own
promise — and the valve control says `(:ok, term, term)`. Tests: seven new
(`validate_as_tests`, `types_tests`, `pipe_tests`), all seen red first; 509 pass.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- **`ValidateAs`'s pathed error stops at the row** — [ticket 61](issues/61-validateas-path-stops-at-the-row.md),
  raised by exemplar 25d on 2026-08-24 and resolved the same day; the series' first compiler-defect
  ticket. Three defects in one term, and the first two shared a root: `t_absorb/1` compared
  *distinct* members only, so a product unioned with itself survived twice — which `l_elem/1` does
  for every `list<T>`, the element type being both the spine's prefix and its tail — and the doubled
  member then read as ambiguity, stopping the validator's descent at the row with the expectation
  printed as `X | X`. The same comparison had a worse edge, measured live before the fix: two
  structurally different spellings of one product absorb each other and **both vanish**, a union of
  two inhabited types reporting empty. One repair covers all of it — `t_absorb/1` folds to a maximal
  antichain, keeping the first representative of equals — and `m_absorb/1` turns out to have fixed
  the dedup half for records in isolation on an earlier day, which is why F18.7's record descent
  always worked while 25d's tuple rows did not: a decided rule that never reached past its example.
  The third defect was the printers': the exact top rendered as its six-way decomposition, and
  `bs_api` had already met this and patched it *locally*, arguing the expansion is the point in a
  residual. It is — for a *partial* residual, which never equals the top. The rule now lives in
  `to_string/1` and `to_pattern/1` themselves: the exact top prints `term`, everywhere, and partial
  residuals are still enumerated. Measured at the boundary afterwards:
  `(:error, (["[1]", "(2)"], "string"))` — the row, the component, the narrow type, exactly as
  `LANGUAGE.md` §10 promised, and the valve's cannot-fail diagnostic says `(:ok, term, term)` in the
  author's own spelling.
```
