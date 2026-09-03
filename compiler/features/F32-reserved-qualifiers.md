# F32 — `List` is an operation set the compiler knows, not a module it ships

**Status**      **done 2026-09-04** — 28 new tests, one new gate
                (`check-reserved-qualifiers.sh`), 601 in the suite, up from 573. One existing
                test changed and one corpus module renamed, both recorded below
**Implements**  [ticket 67](../../wayfinder/issues/67-stdlib-shape-as-a-principle.md),
                resolved 2026-09-03. It **decides nothing** — 67 settled the
                kind, the reserved set, the spellings and the collision rule,
                and this file builds them
**Closes**      [ENG-321](https://linear.app/davewil/issue/ENG-321)
**Depends on**  F11 (the module system and its two import tiers, which clause 3
                is written against), F15 (a module is a directory, which is what
                clause 2 refuses), F18 (whose `validator_table/2` is the shape
                the lowering table copies)
**Leaves**      `Map.Get` and `map<K, V>` —
                [ENG-319](https://linear.app/davewil/issue/ENG-319). The NAME
                `Map` is reserved here; the operations under it are not built,
                and they land on the same table

## What shipped

Three clauses, and the first is the feature:

1. **A lowering table.** `{Qualifier, Name, Arity}` → a generated local
   recursive function, emitted into the module that uses it and typed at that
   site. `List.Sum/1`, `List.Length/1`, `List.Reverse/1`, `Term.Compare/2`.
   No `List.beam` ships and no `using` is ever written.
2. **The reserved declaration refusal.** `module List`, `module Map` and
   `module Term` are refused. The **bare name only** — 67 Q6 declined burning
   the path segment, so `Shop.Collections.List` is still a legal module.
3. **The call-site collision.** `using Shop.Collections` beside a reserved
   `List` makes `List.Length(...)` an error naming both claimants and printing
   the full path as the fix — [ticket 47](../../wayfinder/issues/47-import-alias.md)'s
   rule for two user modules, applied to one more source of shadow.

## Two of the plan's three premises were false, and measuring them first is why

The issue as filed said `List.Sum` with no `using` was *"refused today with
`unknown module`"*, and that clause 2 **extended** 48's refusal of `module Map`
to two more names. Measured through a built `bsc` on `7141773` before a line was
written:

| the plan said | the compiler did |
|---|---|
| `unknown module` | `List is called but never imported`, hinting `` add `using List` `` |
| 48's refusal of `module Map` is extended | **no such refusal exists.** `module Map`, `module List` and `module Term` each compiled clean, exit 0, in a directory of their own name |

So clause 2 is a **build, not an extension**, and all three names get a test
rather than one standing for the set. The first probe missed this because the
directory-name check fires first: `module Map` in a directory called anything
else is refused for the *path* mismatch, which looks like a reserved-name
refusal and is not one. That is also why `reserved_module_name/2` is called
**before** `module_matches_path/3` — so the author of `Foo/List.bs` and the
author of `List/List.bs` get the same answer.

The failing test pins the measured string. A test written against `unknown
module` would have been green against a compiler that never printed it.

## The whole feature is invisible to a value, so the gate reads the artefact

67 chose **(b)**, an operation inlined at the site, over **(a)**, a shipped
module resolved through the module table. `List.Sum([2,2,2])` is `6` under both.
Every test that asks what a program *prints* passes either way, which means the
eunit suite alone could have shipped the wrong design and reported success.

`check-reserved-qualifiers.sh` P2 reads the compiled beam's **import chunk**:
an inlined operation names no module under its qualifier, a resolved one names
exactly the module it resolved to. Its self-test's `shipped_module` stub is the
**over-informed** one — it gets P1 right, prints `6`, and is 67's (a). It is the
only stub a value-checking gate would pass, and it is the reason the gate exists.

`lists` is named in the same probe as `List`, because emitting `lists:sum/1` is
the other way to be (a): 67 asks for a generated local form, and a remote call
to the stdlib is still a remote call.

## Three pairs of probes, because three rules fail in opposite directions

Every refusal here has a neighbouring program that must still be **accepted**,
and a check missing that half passes the red probe while being wrong:

| refused | and this must not be |
|---|---|
| `module List` | `module Shop.List` — 67 Q6 declined (i) |
| `using Shop` + `List.Sum(…)` | `using Shop` + `Ints.Sum(…)`, the namespace tier at large |
| | `using Shop.List` + unqualified `Sum(…)`, the **module** tier |
| | `Shop.List.Sum(…)`, the full path — which is what the diagnostic offers as the fix, so if it were refused the message would be a lie |
| `List.Frobnicate(x)` | and it must not fall through to `module_not_imported`, whose advice — "add `using List`" — is the one fix that can never work |

**Clause 3 is namespace-tier-only for free**, rather than by a condition written
into it. `add_module_import/3` populates `funs` and `imported`;
`add_namespace_import/3` populates `mods`. A reserved name can only be shadowed
by a key of `mods`, so a check asking `mods` *cannot* fire on the module tier.
The two controls hold it there.

## `Shop.Collections.List` became `Shop.Collections.Ints`

F11's own worked example short-qualifies a user module to `List`, which is the
program clause 3 refuses. 67 Q6 stated the remedy — *"rename the example's
module or call it in full"* — and the two halves are not equivalent here.

`Totals.bs` teaches **all three** ways one module reaches another, and
`Counted(n) -> List.Length([n, n])` is its only namespace-tier line. Calling it
in full would collapse `Counted` into `Fully` and delete the middle tier from
the example that exists to demonstrate it. Renaming keeps all three.

Seven sites, not the two the issue named: `Totals.bs`, `pipeline.bs`,
`LANGUAGE.md:132-146`, `TOUR.md:837-909` and its two construct-index rows, plus
`api_tests.erl`'s assertion on `--api Shop/Collections` and `corpus_tests.erl`'s
two pins on `pipeline.bs`'s text. Five further hits were prose comments.

`Ints` is chosen against the module's own content — `Sum/2` and `Length/1|2`
over `list<int>` — and against the constraint that it must not be a plausible
future reserved qualifier. `Stream` was out on those grounds:
[`stream<T>`](https://linear.app/davewil/issue/ENG-283) is deferred, not refused.

`modules_tests`' own `Shop.List` fixture moved to `Shop.Ints` for the same
reason, and only one of its tests was actually red —
`a_namespace_import_short_qualifies_its_modules_test`, which is the decided rule
reaching past its examples.

## What the build found that the plan did not

**`List.Length` binds its head `_Bs@h` while the other two bind `Bs@h`.** It is
the one operation that does not look at the element, so `erlc` warned *"variable
'Bs@h' is unused"* — and `bsc` surfaced that warning against the author's own
`.bs`, a file containing nothing they could change. F4's rule at a new site: the
compiler owns diagnostics about the author's source, so it must not manufacture
one about code the author never wrote.

**`check-status-claims.sh` could evaluate only one of its three documented
probe forms.** Its loop read `[ "$form" = "type" ] || continue` while the legend
above it described `type`, `codegen` and `builtin`. F32's entries are reached in
**expression** position under a qualifier, so they would have been reported
unbuilt forever — the same mistake the `codegen`/`type` split was written to
prevent, one column over. The loop now dispatches, and a `qualified` form was
added. Probed rows went 8 → 11.

**The collection-library row was not addressable at all.** `prelude_status`
greps for `` | `Entry` `` and the row's first cell read *"the collection
library"*, unbackticked — so the gate could not have read its status even had the
form been right. This is [ENG-320](https://linear.app/davewil/issue/ENG-320)'s
exact shape at a second row. It is now three rows, one per qualifier, each
separately probeable, and `Map.Get`'s says **decided, unbuilt** and is checked to
be refused.

## The generated code

One function per `{Qualifier, Name, Arity}` used, and **no type in the key** —
unlike `validator_table/2`, whose generated code differs per type. None of these
traversals mentions the element, so a `list<int>` and a `list<Order>` share one
emitted `Reverse`. Monomorphic at every use site is still satisfied: the checker
typed the site, and the instructions are the same either way.

Every list operation is **tail-recursive through an accumulator**, which is why
each emits two functions rather than one. This is generated code no author can
rewrite, so it does not get to be the naive one.

`Term.Compare` is the BEAM's own term order — that is what makes it universal —
and only the **answer** is B#'s: three atoms a `switch` must cover, rather than a
boolean pair that cannot express `eq`. Probed: the union declares, is legal in
return position, and a two-armed `switch` over it goes red with `:gt` as the
residual, which is what distinguishes it from a widened `atom` whose residual
would name every atom there is.
