# 64 — `option<term>` and `result<term, E>` collapse to bare `term`

Type: grilling
Status: open — [ENG-254](https://linear.app/davewil/issue/ENG-254); narrowed to the expressiveness
question 2026-09-06 by [ticket 68](68-an-absorbed-member.md)

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

**Narrowed 2026-09-06 by [ticket 68](68-an-absorbed-member.md): questions 1 and 4 are answered
there, and this ticket is now the expressiveness question alone.**

1. ~~**Is it a defect at all, or the type system working correctly?**~~ **Answered by ticket 68
   Q1.** Both: the collapse is sound and it is **still refused**, because what it costs is the
   author's intent rather than soundness. Any member `M` where `M ⊆ union(others)` is an error at
   the declaration.
2. **If it is to be fixed, how?** A tagged success on `option<T>` itself changes every existing use.
   Refusing `option<T>` at `T = term` is loud, and leaves the author with nothing to reach for.
   **Still open, and now the whole of this ticket.** F31 already made the refusal real (its
   scenarios S5 and S7); ticket 68 confirms it generalises. So the loudness is settled and the
   *"leaves the author with nothing"* half is what remains — sharpest at
   `map<string, term>`, which is the shape all three of ticket 48's motivating cases carry.
3. **Does the same reasoning reach `result<T, E>` at `E = term`?** Not measured. **Still open.**
4. ~~**Is there one rule here rather than two special cases?**~~ **Answered by ticket 68 Q1.**
   One rule — `M ⊆ union(others)` — and 15 §1's failure channel was a filter on it, not a rule of
   its own.

## Notes

Do not "fix" this by tagging `option<T>`'s success without first answering 1 — the collapse is
sound, and a change that makes `option<int>` more awkward to buy `option<term>` may be a bad trade.
And do not treat the `(:ok, V) | :absent` shape from ticket 48 as the answer: it is one call site
choosing a type that happens not to collapse.

## Round 1 — 2026-11-11

Measured on Erlang/OTP 28.5 (built from `otp_src_28.5`, the pinned release) with rebar3 3.27.0,
against an unmodified `compiler/` at `cd080fa`. The probes are in
[the research file](../research/64-failure-types-collapse-at-term.md) and are printed by
[`64a`](../prototypes/64a_absent_at_term.sh).

**Two things above have moved since 2026-09-06.** *"Leaves the author with nothing"* no longer
holds: a tagged lookup over `maps:find/2` and `Map.Has` (F75) both compile and both report absence
at a `term` value. And the refusal F31 and F36 built has a way round it that neither had a program
for, because F45 shipped the polymorphic signature after them.

### The program

```csharp
module Solved

public string Trace(list<(string, term)> headers)
Trace(hs) -> Find(hs, "x-trace") switch {
    :nothing => "no trace header",
    v        => "traced"
}

private option<T> Find<T>(list<(string, T)> xs, string key)
Find([], _)                               -> :nothing
Find([(k, v), ..rest], key) when k == key -> v
Find([_, ..rest], key)                    -> Find(rest, key)
```

It compiles today with no diagnostic. The call solves `T` to `term`, its type is
`term | :nothing`, which is `term`, and `bsc --api` prints `term` for a function that returns it.
Run:

```
$ bsc Solved Trace '[("host", "a")]'
"no trace header"
$ bsc Solved Trace '[("x-trace", :nothing)]'
"no trace header"
```

The second header is present. Write the same return type out, `public option<term> Trace(...)`,
and line 3 is refused: *"`:nothing` is absorbed by `term` ... hint: tag it - (:some, term) |
:nothing"*.

This is also how `Map.?Get` will be typed. [Ticket 108](108-the-second-forms-spelling.md) gave the
`?` form the return `option<V>`, and a standard row is typed as a call to a polymorphic function
(F75), so `Map.?Get(headers, "x-trace")` over a `map<string, term>` goes through the same clause
once ENG-324 builds it.

### The question

**Is the call `Find(hs, "x-trace")` refused, because it solves `option<T>` to `T = term`?**

Alone. What the standard environment hands back for a lookup in a `map<string, term>` follows a
yes and is not asked here.

### Under each answer

**Yes.** `Solved` is refused at line 4, at the call:

```
Solved.bs:4:14: error: `:nothing` is absorbed by `term`
  in Trace, at the call to Find
  Find returns `option<T>` and this call makes `T` `term`, so the
  result IS `term` and the `:nothing` arm cannot tell an absent
  header from one holding `:nothing`.
```

The same `Find` over a `list<(string, int)>` compiles as it does today. The compiler gains:

- in `checked_call_typed/7`'s template clause (`bs_check.erl:4416`), a walk of the return template
  `RetT` under the solution `Sub` that asks `absorbed/2` (`bs_check.erl:3415`) of each member of a
  `{t_union, Ms}` against the others, before `subst_tpl/2` hands them to `bs_types:union/1`. It is
  `collapse_members/4` at a call instead of a declaration;
- one more `where` shape on the `absorbed_member` tag in `bs_diag.erl`, naming the call and the
  variable, since the existing sentence says *"the type declared here"* and nothing is declared
  at a call;
- nothing in `bs_emit` or `bs_lower`: the check is on types and the emitted program is unchanged.

`Map.?Get`, `Map.?Find`, `List.?First`, `?Last` and `?At` inherit the refusal at `term` when
ENG-324 builds them, with no delta of their own. This ticket then holds one follow-up, what an
author writes for that lookup, and today's answer to it is the `:maps.find` program in the research
file.

**No.** `Solved` compiles as it does today and prints what it prints today. The compiler gains
nothing. Ticket 68's sentence, *"a written member that is not in the type is an error"*, gains the
clause *"unless a call's solution removed it"*, `LANGUAGE.md` says so where `option<T>` is
introduced, and `Map.?Get` over a `map<string, term>` ships returning `term`. This ticket closes.

**Recommended:** yes, because the type the call produces is one the compiler already refuses when
it is written out, and the program that slips past returns a wrong answer on a header that is
there.
