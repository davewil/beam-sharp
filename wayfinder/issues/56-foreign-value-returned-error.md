# 56 — A foreign function that returns `(:ok, V) | (:error, R)` as values has no declared form

Type: grilling
Status: **resolved 2026-08-22** — raised 2026-08-18 while building
[F19](../../compiler/features/F19-foreign-try-wrapper.md), given a repo file 2026-08-22
[ENG-228](https://linear.app/davewil/issue/ENG-228). Built the same day as
[F23](../../compiler/features/F23-value-returned-foreign-error.md)

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

## Answer

**It is declared as an ordinary union naming its own error payload, and nothing else changes.**

```csharp
type Contents = (:ok, binary) | (:error, atom)

using :file {
    Contents read_file(binary p)
}
```

No wrapper is emitted, both arms are typed, and `(:error, :enoent)` is an ordinary clause head.

**What the compiler gained: one predicate, narrowed.** The wrapper is requested by the **payload**
`foreign_error`, not by the **tag** `:error`.

```erlang
wraps(Ret, Env) ->
    Fe = maps:get(foreign_error, Env),
    lists:any(fun(P) -> same_type(P, Fe) end, error_members(Ret)).
```

No new syntax, no new prelude entry, no widening of `foreign_error`, and **no extension to the FFI
declaration at all**.

### Why that is the answer and not a second form

The question assumed the missing thing was a *form*. It was not — the form already existed, and the
check was reading it wrong.

F19 §2 inferred the failure **channel** from the **shape** of the return type: a type mentioning
`(:error, R)` belongs to a function that throws. For most of OTP that inference is simply false.
**And the compiler cannot do better** — it has no Erlang type database, and nothing about
`{:file, read_file, 1}` reveals whether it raises. The channel is knowledge only the author has, so
it must be something the author *writes*.

They already can. `foreign_error` is stratum-2, compiler-known, and names an exception **class**,
which no other type in the language spells. Writing it says *this throws, and I want the throw as a
value*. So naming it is the declaration of the channel, and every other union is an ordinary value.

That reading also makes F19 §1 **more** true, not less: the trigger was always meant to be the type
rather than the spelling, and this just picks the part of the type that carries the meaning.

### The two channels compose, which had no form at all before

A function that returns `{error, Reason}` as a value *and* can throw was previously undeclarable in
both halves at once. The algebra keeps the two `(:error, _)` products **separate** (measured — the
old refusal printed `(:error, atom)`, not a merged payload), so:

```csharp
type Opened = (:ok, term) | (:error, atom) | (:error, foreign_error)
```

gets the wrapper for the throwing arm while the value arm stays an ordinary value. This was not the
goal; it fell out, and it is the strongest evidence the narrowing is the right cut.

## What was measured, including two claims that were false

**1. The gap was wider than this ticket's own title.** The title says `(:ok, V) | (:error, R)`.
`erl_tar:extract/2` returns `ok | {error, Reason}` — a **bare** `:ok` atom — and was refused
identically. So the answer could not be "recognise the `(:ok, V)` sibling"; that rule would have
mis-classified `erl_tar` and half of stdlib with it.

**2. F19 §1's worked example does not compile.** It offers
`int | (:error, foreign_error) g(binary)` as a foreign signature. `foreign_sig -> type_prim` and a
union is not a `type_prim`, so it is `syntax error before: '|'`. The **rule** is sound — an alias
naming the same union does get the wrapper, and a test has always pinned it — but the example was
wrong, and it is why the answer above goes through a `type` declaration. Corrected in F19.

**3. The bullet in the Question was right, and understated.** *"`result<binary, foreign_error>` is a
lie"* — it is worse than a lie the author might notice. It **compiles and runs**:

```
$ bsc --src-root . H Read '<<"/etc/hosts">>'   ->  (:ok, "## Host Database ...")
```

The declared type is `binary | (:error, foreign_error)` and `{ok, Bin}` inhabits neither arm. The
refusal was **recommending** this, in its own last-but-one sentence.

**4. And that dissolves F19 §2's central defence.** §2 called refusing *"the reversible direction"*,
on the grounds that emitting no wrapper silently would ship a program that dies where its signature
declares a value. But the form it recommended instead already shipped a value inhabiting no arm of
its declared type, silently. The protection was not general — it was aimed at one direction of a
symmetric problem. Both directions belong to ticket 18's boundary guard.

## The cost, stated plainly

**A mis-declared channel is no longer refused.** `result<int, atom>` over `binary_to_integer` now
compiles, gets no wrapper, and the program dies at runtime. That is a real regression against F19 §2
and it is accepted deliberately, because the alternative is keeping a large and ordinary class of
Erlang function undeclarable in exchange for a guard that never covered its own recommended
workaround.

**Owner: ticket 18's boundary guard** — an emitted check that a foreign value inhabits its declared
type. It catches both directions, because both return a value the declared type does not contain.
`LANGUAGE.md` §11's **Owed** paragraph now names the second direction explicitly so it cannot be
forgotten.

`a_payload_other_than_foreign_error_is_an_ordinary_union_test` asserts the *cost*, not just the
benefit, so the next reader finds a decision rather than an omission.

## Where it is recorded in the compiler

- `bs_check.erl` — `wraps/2` and the comment block above it carry the reasoning.
- `bs_diag.erl` — the `foreign_error_channel` descriptor and message are **deleted**. F19 expected
  whoever resolved this to *edit* that prose; there was no refusal left to word.
  `grep foreign_error_channel` over `src/` now returns nothing, and `check-diagnostics.sh` fails a
  half-deletion in either direction.
- `foreign_wrapper_tests.erl` — three new tests, two inverted.
- `LANGUAGE.md` §7 and §11. **§11 already said the right thing** — *"declare anything else and it
  does not"* — while §7 said *"an error at the declaration"*, and both were marked **shipped**. The
  language document has been contradicting itself since F19, and §11's half was the answer.

## What this does NOT do

- **It does not widen `foreign_error`.** The ticket ruled that out and the ruling holds: a
  `(:value, T)` member would let the declaration type-check while still telling the author their
  error arrives by a channel it does not.
- **It does not add a keyword, a marker, or a second declaration form.** An earlier reading of this
  ticket expected one; the measurement said the form already existed.
- **It does not touch the grammar.** A union still cannot be spelled inline in a `using` block.
  Widening `foreign_sig -> type_prim` to `type_expr` would owe `yecc:file/2` before and after and
  buys only a second spelling of what a `type` line says more legibly.

## Sequencing

Sat beside [ticket 50](50-naming-a-foreign-struct.md) and
[ticket 52](52-dependency-provenance.md) — all three ask what an FFI declaration carries, and 52
warned that answering them apart risks two extensions to one construct designed by different
sessions.

**That warning is defused for this ticket rather than deferred to.** The answer extends the FFI
declaration by nothing: no new field, no new keyword, no grammar change. There is no construct here
for 50 or 52 to collide with, and both are free to design their own additions without accounting for
this one. The warning still stands between 50 and 52.

## Notes
