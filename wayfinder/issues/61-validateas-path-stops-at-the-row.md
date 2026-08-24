# 61 — `ValidateAs`'s pathed error stops at the row, and two renderings beside it

Type: defect
Status: open

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
