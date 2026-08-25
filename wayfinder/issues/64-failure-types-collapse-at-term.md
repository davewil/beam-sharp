# 64 — `option<term>` and `result<term, E>` collapse to bare `term`

Type: grilling
Status: open — [ENG-254](https://linear.app/davewil/issue/ENG-254)

Measured 2026-08-25 by [`48l`](../prototypes/48l_what_the_workaround_costs.sh) while pricing
[ticket 48](48-a-map-type-in-the-prelude.md)'s question 1, and split out here because it is a
**prelude** defect that maps merely expose.

## Question

**A lookup cannot report "absent" in a type the checker can see, at exactly the value type every
caller reaches for first.**

## The mechanism

Both prelude failure types put the **bare value** in the success position:

    type option<T>    = T | :nothing
    type result<T, E> = T | (:error, E)

At `T = term` the union swallows its own tag: `:nothing` is an atom, and `term` already contains
every atom. Measured off `bsc --api`, four lookup signatures side by side:

    :absent | (:ok, atom|int|tuple|list<term>|map|binary) FindF(…)  hand-rolled — SURVIVES
    :nothing | int                                        FindI(…)  option<int>  — survives
    term                                                  FindR(…)  result<term, atom> — COLLAPSED
    term                                                  FindT(…)  option<term> — COLLAPSED

## Why it surfaced now

[Ticket 48](48-a-map-type-in-the-prelude.md) decided `map<K, V>` ships with **no pattern form**, so
a lookup operation is the *only* way into a map. All three motivating cases — Plug-style `assigns`,
a decoded `jsonb` document, and Req's headers — carry `term` values. The first thing anyone does
with the new type hits this.

**It is unblocked and not fixed.** 48's question 8 followed `Map.fetch/2` to a **tagged** success,
`(:ok, V) | :absent`, which does not collapse. That is a workaround at one call site, not a repair
of the prelude.

## This was met once already and not generalised

Ticket 15 §1 refused `atom | :nothing` **at the declaration** for exactly this reason — a singleton
absorbed into a cofinite top — and `PRELUDE.md` still records `ToExistingAtom` as **owed** because
of it, with two known-good answers and neither chosen. **That is this bug**, seen in one instance
and never lifted to the rule underneath.

## Open

1. **Is it a defect at all, or the type system working correctly?** `term | :nothing` really *is*
   `term`. The collapse is sound. What it costs is expressiveness, not soundness.
2. **If it is to be fixed, how?** A tagged success on `option<T>` itself changes every existing use.
   Refusing `option<T>` at `T = term` is loud, and leaves the author with nothing to reach for.
3. **Does the same reasoning reach `result<T, E>` at `E = term`?** Not measured.
4. **Is there one rule here rather than two special cases?** Every prelude union whose success arm
   is a bare type variable has this shape. `48l` found two; 15 §1 found a third. There may be more.

## Notes

Do not "fix" this by tagging `option<T>`'s success without first answering 1 — the collapse is
sound, and a change that makes `option<int>` more awkward to buy `option<term>` may be a bad trade.
And do not treat the `(:ok, V) | :absent` shape from ticket 48 as the answer: it is one call site
choosing a type that happens not to collapse.
