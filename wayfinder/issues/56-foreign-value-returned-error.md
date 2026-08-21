# 56 — A foreign function that returns `(:ok, V) | (:error, R)` as values has no declared form

Type: grilling
Status: **open** — raised 2026-08-18 while building
[F19](../../compiler/features/F19-foreign-try-wrapper.md), given a repo file 2026-08-22
[ENG-228](https://linear.app/davewil/issue/ENG-228)

> **This ticket was numbered 48 for four days and it was the wrong number.** ENG-228 was created on
> 2026-08-18 calling itself *"ticket 48"*, with **no repo file** — its own closing line says
> *"repo file `wayfinder/issues/48-*.md` and the map index entry are owed; this issue holds the
> content until then."* On 2026-08-20 a different question — the map type in the prelude — was
> raised as repo ticket 48 and [ENG-230](https://linear.app/davewil/issue/ENG-230), because nothing
> on disk said 48 was taken. **Two trackers then disagreed about what "48" meant**, which is the
> canonicality contract's failure in the mirror direction: the map's long bullet is about a repo
> file with no issue, and this is an issue with no repo file. Renumbered to **56** on 2026-08-22,
> found while resolving [ticket 55](55-destructure-and-bind.md) — the same class of defect, which is
> why it was looked for.

## Question

Found while **building** F19, not by argument — the wrapper was built and this is what it could not
say.

Ticket 15 §5 fixes the foreign error channel:

```csharp
type foreign_error = (:error, term) | (:throw, term) | (:exit, term)
```

F19 therefore **refuses at the declaration** any foreign signature whose failure is declared as
`(:error, E)` with `E ≢ foreign_error` — house style per 09 §4 and 15 §1, error never warning, so
the diagnostic lands where the fix is.

That refusal is right for what 15 §4 was about: a foreign call that **throws in-process**, where the
wrapper produces the exception *class* and no other type can spell it.

**But it makes a large and ordinary class of Erlang function undeclarable.** `file:read_file/1`
returns `{ok, Binary} | {error, Reason}` as **ordinary values** — it does not throw. Under §5 there
is no declared form for it:

- `result<binary, foreign_error>` is a lie — nothing throws, and the author would be pattern-matching
  an exception class that never arrives.
- `result<binary, atom>` is refused by the check F19 just built.
- Declaring it without `result` gets no wrapper, which is correct, but then the `{error, Reason}`
  tuple is just an untyped value crossing the boundary — exactly what ticket 18 exists to prevent.

## Why 15 §5 does not already cover it

§5 prices the cost as *"an author writes `result<int, foreign_error>` and adds a mapping step."*
That covers a **throwing** function whose class the author wants to rename. It does not cover a
function that never throws and whose error is already a value with its own type. **The mapping step
has nothing to map from.**

This is arguably the more common shape in OTP: `file`, `inet`, `gen_tcp`, `erl_tar` and most of
stdlib's IO surface return tagged tuples rather than raising.

## What is not being asked

Not whether to widen `foreign_error`. Adding a `(:value, T)` member would let the type-checker accept
the declaration while still telling the author their error arrives by a channel it does not. **The
question is what a value-returned foreign error is declared as**, which may be a second form rather
than a widening.

## Where it is recorded in the compiler

`compiler/features/F19-foreign-try-wrapper.md`, Out of scope. **The diagnostic's closing sentence
names this gap in prose** — `bs_diag.erl`, the `foreign_error_channel` message: *"A foreign function
that returns `(:ok, V) | (:error, R)` as ordinary VALUES has no declared form yet."* **That sentence
must change when this ticket resolves.**

## Sequencing

Sits beside [ticket 50](50-naming-a-foreign-struct.md) and
[ticket 52](52-dependency-provenance.md) — all three ask what an FFI declaration carries, and 52's
own note warns that answering them apart risks two extensions to one construct designed by different
sessions. That warning now covers three.

## Notes
