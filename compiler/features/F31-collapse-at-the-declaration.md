# F31 — The failure channel must survive normalisation, and the declaration is where it is checked

**Status**      **done 2026-08-28** — 25 new tests, one new gate
                (`check-collapse.sh`), 562 in the suite. Three existing tests
                changed, each recorded in place: one of them,
                `foreign_wrapper_tests`' `result<term, E>` case, had **predicted
                this feature in its own comment** — *"that check is not built,
                so this is the shape it will catch"*
**Implements**  [ticket 15](../../wayfinder/issues/15-error-model.md) §1, resolved
                2026-08-12. It **decides nothing** — 15 §1 settled the predicate,
                the site and the severity, and this file builds them
**Closes**      [ENG-272](https://linear.app/davewil/issue/ENG-272), filed
                2026-08-28 while measuring ticket 49
**Unblocks**    **F30** (the valve's fixed short-circuit set). Ticket 49 accepted
                shape C's `option<atom>` exposure *on the grounds that 15 §1
                refuses it*; until this ships, that refusal does not exist and
                the hazard is reachable. `decisions.md:1731` — *"F30 must not
                land before it"*
**Depends on**  F6 (`resolve/3` and the parametric env), F16 (the diagnostic is
                a term), F18 (which built 15 §1's predicate at **one** site)

## Why this one now

Ticket 15 §1 is the sharpest kind of unbuilt decision: it is not merely absent,
it is **cited as present**. Ticket 49 weighed three shapes for the valve and
accepted shape C's exposure because 15 §1 was understood to refuse the case that
makes it dangerous. `PRELUDE.md:108` records `ToExistingAtom` as **owed** for the
same reason. Two documents lean on a refusal the compiler does not have.

F18 built the predicate at the `ValidateAs<T>` obligation site and nowhere else.
`bs_diag.erl:280` says so in as many words — *"Ticket 15 §1's collapse, met at an
instantiation rather than at a declaration."* That comment is accurate and it is
the whole gap.

## Measured before this file was written, not assumed

Every row below was run against `bsc` at `83ed3b7`, the build this feature starts
from. The probes are `wayfinder/prototypes/49a-what-the-arm-must-be/` and the
sweep recorded in §"Expected verdicts".

**The harm is not theoretical, and it is silent.** `option<atom>` is reported by
`bsc --api` as bare `atom`:

    public option<atom> Lookup(int id)      -->   atom Lookup(int)

A caller cannot write the failure clause because no failure member survives. A
clause that *looks* like one compiles and runs — `Go(:nothing) -> :ok` over
`option<atom>` returns `:ok` — but it is an ordinary atom arm, not a channel.

**The plausible wrong fix is named by the ticket itself.** 15 §1: *"Stated as
absorption by an atom top it would cover only `option<atom>` and an implementer
would write the cofinite check alone."* Two measured cases defeat that
implementation, and both are in the gate as controls:

    option<option<int>>              -->  :nothing | int    (no atom top anywhere)
    result<(atom, binary), binary>   -->  (atom, binary)    (a TUPLE-shape collision)

**The rule is keyed on the type, not on the spelling.** A hand-written alias
collapses identically, and this is the spelling `ToExistingAtom` is written in:

    type M = atom | :nothing         -->  atom

**A bare union cannot be written in a signature at all.** `public atom | :nothing
Go(...)` is a *syntax error before `'|'`* — `foreign_sig` and `signature` take a
`type_prim`, not a `type_expr` (`bs_parser.yrl:140`). So the hand-written case
always arrives through a `type_alias`, which is why the alias body is a site and
why there is no "bare union in a return position" scenario below.

**There is no local-binding annotation site.** 15 §1's illustration writes
`option<atom> z;`, and the language has no such form: a binding is `var pattern =
expr` (`bs_parser.yrl:323`). The illustration is 15's prose, not a surface the
compiler owes. Recorded so a later reader does not go looking for the site.

## The predicate — one implementation, not two

15 §1 states it as an equation, *"reject when `T | <failure member> ≡ T`"*. In
this algebra that equation has a one-line normal form, because a union is always
a supertype of its members and so only one direction can fail:

    T | F ≡ T     exactly when     F ⊆ T

So the whole of 15 §1 is `bs_types:is_subtype(Failure, Success)`, and `F18`'s
`validate_collapses/2` is **already that**, with the failure member synthesised
rather than passed in. This feature does not add a second predicate beside it —
15 §1 would then have two implementations that can drift, which is precisely what
`bs_check.erl:25` exists to warn against. It **generalises the existing one** to
take the member as an argument, and the `ValidateAs` site passes the member it
was already synthesising. The obligation site's behaviour and its diagnostic text
are unchanged; `check-diagnostics.sh` pins that text and stays green.

**What counts as a failure member.** The two the prelude defines, and only those
— `:nothing` (`bs_check.erl:714`) and `(:error, E)` (`bs_check.erl:716`). This is
15 §1's own wording: the diagnostic says *"the failure channel does not survive
normalisation"*, a sentence that has no meaning about a type with no failure
channel.

**And that is deliberately narrower than "no union may have an absorbed
member".** The general rule was measured and it refuses four shapes that compile
today and that 15 §1 says nothing about — `atom | :ok`, `binary | string`
(`string` is `binary` refined by UTF-8, so it is absorbed), `term | int` and
`list<term> | list<int>`. Each has a member no one can ever discriminate, so each
is arguably ticket 09 §4's business — but 09 §4 **is not implemented at all**
(nothing in `bs_check.erl` checks discriminability), and building it here would
be answering a question this feature was not asked. Filed separately with the
measured table; see *Residuals*.

## Where it runs

**Not in `resolve/3`.** No type-expression node carries a line number — not
`t_union`, not `t_generic`, not `param`, not `field` — and lines live only on the
enclosing declaration tuple (`bs_parser.yrl:95, 140, 177, 192, 265`). A check
inside the resolver could not say *where*. `compiler_known_redeclared/1`
(`bs_check.erl:779`) is the existing template: it walks `Decls`, pairs each name
with its `L`, and reports. This runs in the same block, `check/2`
`bs_check.erl:103-117`.

Five declaration forms carry a type an author wrote:

| form | positions checked | measured to collapse today |
|---|---|---|
| `signature` | return, every param | yes — `atom Lookup(int)` |
| `foreign_sig` | return, every param | yes — accepted clean at both |
| `type_alias` (ground) | body | yes — `type M = atom \| :nothing` |
| `type_refined` | base | yes |
| `record_decl` | every field type | yes — `Note: option<atom>` reported as `Note: atom` |

Nested positions are reached structurally, because the channel is equally dead
there: `(option<atom>, int)` is reported as `(atom, int)` today. A `t_ref` is
**not** followed — the alias it names is checked at its own declaration, and
following it would report the same defect once per use.

**Parametric aliases need no guard.** `type myopt<T> = T | :nothing` is a syntax
error (`type_decl` admits parameters only in the prelude's shape), and the
prelude's own `option<T>` is an Erlang literal in `stratum_one()`, never a parsed
declaration. `type_env/1` already passes `{parametric, _, _}` through unresolved
(`bs_check.erl:683`). So no unbound `T` ever reaches the check, and there is no
risk of refusing the prelude.

## Expected verdicts — written before the code

Red in either direction. `option<term>` and `result<term, E>` are included
because they are [ENG-254](https://linear.app/davewil/issue/ENG-254)'s measured
cases and this feature decides their fate by construction — see *Residuals*.

| # | declared type | normalises to | verdict |
|---|---|---|---|
| S1 | `option<int>` | `:nothing \| int` | accept |
| S2 | `option<bool>` | `:false \| :nothing \| :true` | accept |
| S3 | `option<atom>` | `atom` | **refuse** |
| S4 | `option<option<int>>` | `:nothing \| int` | **refuse** |
| S5 | `option<term>` | `term` | **refuse** |
| S6 | `result<int, binary>` | `int \| (:error, binary)` | accept |
| S7 | `result<term, binary>` | `term` | **refuse** |
| S8 | `result<(atom, binary), binary>` | `(atom, binary)` | **refuse** |
| S9 | `type M = atom \| :nothing` | `atom` | **refuse** |
| S10 | `type F = (:ok, term) \| :absent` | itself | accept |
| S11 | `type R = atom \| (:error, binary)` | itself | accept |

S4, S8 and S9 are the **controls**. An implementation that checks for absorption
by a cofinite atom top passes S3 and S5 and fails S4 and S8. One keyed on the
spelling `option<...>` fails S9. S10 is ticket 48's `Map.Fetch` shape, chosen
*because* it does not collapse — it must stay legal. S11 is 15 §2's whole reason
for giving failure a payload.

## The diagnostic

15 §1 pins the sentence and one hint:

    `:nothing` is absorbed by `atom`; the failure channel does not survive
    normalisation
    hint: tag it — (:some, atom) | :nothing

**The hint does not generalise, and 15 §1 only wrote the one.** *Recorded
assumption, not a decision*: the `tag it` hint is printed for the `:nothing`
channel, where tagging is a repair. It is **not** printed for an absorbed
`(:error, E)` — that member is already tagged, so the advice would recommend a
form that does not fix the program; there the fix is to narrow the success type,
and that is what is said instead. If a later ticket wants one wording for both,
this is the line to change.

## What ships

| | |
|---|---|
| `bs_check.erl` | `absorbed/2` — the predicate generalised to take the member, with `validate_collapses/2` now calling it; `collapse_refused/2` and its walk, driven from `check_dir/3` **and** from `exports_of/1` |
| `bs_diag.erl` | one `descriptor/2` clause, two `message/1` clauses, new tag |
| `bin/check-collapse.sh` | the eleven shapes above, plus `--self-test` |
| `test/collapse_tests.erl` | the eleven shapes, the six declaration sites, termination, and the message |
| `LANGUAGE.md` | §7 *A failure channel that does not survive normalisation is refused*, as prose — a refusal has no `examples/` demo |
| `ci.yml`, `verify.sh`, `.claude/end-session.md` | the four-edit rule, count sentence included |

## Two things measured during the build that the plan did not have

**`--api` is a SECOND declaration pass and does not go through `check/2`.**
`bs_api:resolved/2` calls `bs_check:exports_of/1`, which builds its own
`type_env/1` — which is why it already reports `kind_field_is_minted` — and
never reaches `check_dir/3`. The first working version of this feature therefore
refused `option<atom>` at a compile and answered `atom Go(int)` to `bsc --api`
on the same file: the collapse reported by one half of the compiler and printed
as a fact by the other. `exports_of/1` calls the pass too. It cannot double-
report: `bsc:build/4` reaches `exports_of/1` only on its `{ok, Beam}` branch, so
that module has already been checked clean.

**The walk needs `resolve/3`'s `Seen` chain, and the first draft did not have
it.** On a contractive alias it expanded forever. The symptom is worth recording
because it is not the one you would look for:
`generics_tests:a_contractive_alias_is_an_unbuilt_feature_test` did not go red,
it **timed out**, eunit cancelled every module after it, and the run reported
`Failed: 0. Skipped: 0. Passed: 250` — a green-looking summary over less than
half the suite. `collapse_tests` has two regression tests for it, and both assert
the `recursive_type` refusal that must still arrive rather than merely that the
call returns.

## Residuals

1. **[ENG-254](https://linear.app/davewil/issue/ENG-254) / ticket 64 is
   half-answered by this, by construction.** Its Q2 lists *"a restriction —
   `option<T>` refused at `T = term`"* as an undecided candidate fix, with the
   cost *"loud but leaves the author with nothing."* S5 and S7 make that
   refusal real. This does **not** foreclose a later tagged `option<T>`; it
   converts a silent collapse into a loud one and leaves the expressiveness half
   of 64 open. **David should confirm rather than discover this.**
2. **Ticket 09 §4 is unimplemented** and the four shapes above are its evidence.
   Filed separately.
