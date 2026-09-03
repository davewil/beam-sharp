# F21 — A field assignment is checked, at both spellings and on both halves

**Status**      **done 2026-08-21** · [ENG-203](https://linear.app/davewil/issue/ENG-203)
**Implements**  [ticket 36](../../wayfinder/issues/36-field-value-obligations.md), resolved
                2026-08-21 — which widens
                [ticket 33](../../wayfinder/issues/33-body-check-site.md) §2's site-2 *relation*
                and leaves its closing sentence unamended, and enforces
                [ticket 26](../../wayfinder/issues/26-data-modelling.md) §2 at compile time where
                the BEAM had been enforcing it at run time
**Unblocks**    nothing that was waiting, and that is the point — this is the compiler being wrong
                rather than a capability being absent
**Depends on**  F3 (records, and `declared_fields/1`), F5 (site 2's name half, which shipped this
                hole and named it), F2 (interval refinements — a refined field type is checked by
                the same containment with no extra work)

## Why this one now

Because it is a **soundness** defect, and because the third of its three symptoms is a program the
compiler accepts and the BEAM crashes — the shape ticket 54 was about, six days earlier.

```csharp
record Order { Id: int, Total: int }

Order Make(int n)
Make(n) -> Order{ Id = :oops, Total = n }      // compiled to a .beam

Order Bump(Order o)
Bump(o) -> o with { Total = :oops }            // compiled to a .beam

Order Grow(Order o)
Grow(o) -> o with { Nope = 1 }                 // compiled, then raised {badkey,'Nope'}
```

## What the ticket decided, in one paragraph

**Site 2 is not "construction" — it is field assignment**, of which `Order{ … }` and `o with { … }`
are two spellings meeting **one** declaration. So both check, on both halves, and **no sixth site
opens**: 33 §2's closing sentence carries its own justification clause naming the four forms that
declare nothing (`e_op`, `e_tuple`, `e_list`, `e_block`), and `e_with` is not among them. The name
relation differs between the spellings by exactly what 26 §2 already says — equality at
construction, **subset** at `with` — and the value relation is identical in both.

## The three defects, and which is not in the ticket

| Form | Name half, before | Value half, before |
|---|---|---|
| `Order{ Id = 1 }` | **checked** (F5) | unchecked |
| `o with { Nope = 1 }` | **unchecked at compile time** — runtime `badkey` | unchecked |

The bottom-left cell is the one ticket 36 did not name. Its scope fence said *"F5 enforces the
names; this ticket is about the values"*, and F5 enforces them at **construction only**. A build
following the ticket's stated delta closes two cells and leaves a runtime crash in the tree — which
is why the gate's third stub exists (see below).

## The delta

Larger than the ticket priced, and larger only in **scope**. Still containment against
`declared_fields/1`; **nothing new in `bs_types`**.

| Arm | Where | Diagnostic |
|---|---|---|
| Construction — value | `type_of`'s `e_record` clause | `field_value_not_accepted` (new tag) |
| `with` — value | `type_of`'s `e_with` clause | `field_value_not_accepted` |
| `with` — name | `type_of`'s `e_with` clause | `field_set_mismatch`, **existing** |

Three things worth stating, because each was a choice:

**Names first, values only when they agree.** An undeclared key has no declared type, so checking
its value reports on the compiler's guess rather than the author's program. Same bargain
`clause_diags` strikes for a malformed segment one level up.

**No new diagnostic shape for the name arm.** `field_set_mismatch` already carries `Missing` and
`Extra`, `field_list/2` renders an empty list as the empty string, and `with`'s failure is exactly
`{field_set_mismatch, Order, update, [], [Nope]}` — nothing missing, a name invented. Its `Extra`
sentence, *"not declared by Order"*, was already right. **Only the headline verb was wrong**:
*"Bump builds an Order"* is false about an expression that updates one, so the descriptor gained a
`form` field (`construction | update`) and the verb is read from it. One field, not a fourth shape.

**The cascade needs no special case.** A value whose own synthesis failed is `reported()`, which is
`none()`, and `none \ T` is empty — so a second complaint about the same expression cannot arise.
Asserted (F21.6) rather than reasoned about, because it stays true by accident until someone
changes `reported/0`.

## What the residual is, and the verdict this corrects

33 §3 measured site 2's residual and marked it **useless**: `Order{Id} \ Order` is
`{ Kind: :'Shop.Order' }`, which names the type being built rather than the field forgotten.

That is the **name** residual. The **value** residual is a different query:

```
type_of(:oops) \ int   =   :oops
```

precise, and standing beside a field name that is already known because it is the key being
assigned. So the one site 33 §3 recorded as unable to hand an agent anything writable can do so on
its value arm — which **strengthens ticket 23** rather than weakening it.

```
Probe.bs:7: error: Make assigns Id a value Order does not accept
  not covered by the declared type of Id:
    :oops
```

Shaped on site 4's message deliberately: both say a synthesised value is not contained in a type
someone declared, and the only difference is which declaration.

## The gate — `bin/check-field-values.sh`

Five probes *(four until 2026-09-03; see [the subject](#corrected-2026-09-03--the-subject-eng-249))*.
Four assert a diagnostic appears; probe 4 asserts a correct record program compiles **clean**,
and captures the **exit code** beside the output so that "clean" means rc 0 and nothing said,
rather than merely nothing said.

**The self-test's third stub is what earns this gate**, and the fifth is what the gate could not
see for thirteen days.

| Stub | What it is | Fails |
|---|---|---|
| `SILENT` | the compiler as ticket 36 found it | probes 1, 2, 3, 5 |
| `CRYWOLF` | says every right word, on every program including the correct one | probe 4 only |
| `VALUE-ONLY` | **the ticket's stated delta, built exactly as written** | **probe 3** and 5 |
| `SUBJECT-BLIND` | **F21 as it shipped** — both halves, both spellings, and the base never asked what it is | **probe 5 only** |
| `GOOD` | the decided behaviour | nothing |
| `BROKEN` | nothing compiles | all five |

`VALUE-ONLY` is the build a careful reader of the ticket produces. It is a real improvement, it
passes three of four probes, and it leaves `{badkey,'Nope'}` in the tree. `CRYWOLF` is the
over-informed control: it is invisible to every probe that asks whether a diagnostic *appeared*,
and probe 4 is the only thing that can see it.

The `BROKEN` control is `check-list-length.sh`'s lesson taken as read rather than relearned — that
gate went green on its first real run over a module that never parsed, because a probe asserting an
**absence** is satisfied for free the moment the run dies earlier.

## Scenarios

All in `test/body_check_tests.erl` beside F5's site-2 tests, except F21.7's sibling in
`test/records_tests.erl`.

| # | Scenario |
|---|---|
| F21.1 | construction checks the value assigned to a field |
| F21.2 | `with` checks it too, and opens no sixth site |
| F21.3 | the rejected value is handed back — `:oops`, not the record's tag |
| F21.4 | a correct record program compiles: literal, parameter, projection, binding, call return |
| F21.5 | a **refined** field type rejects a value outside it, with no work beyond F2 |
| F21.6 | a value whose synthesis already failed is not reported twice |
| F21.7 | `with` may not invent a field, **at compile time** |
| F21.8 | the `with` diagnostic says "updates", never "builds", and invents no missing field |
| F21.9 | the value diagnostic reaches the author as prose |
| F21.10 | `with` on an `int` is refused, with `int` as the member handed back, and **one** error — the refusal does not cascade into the return check *(ENG-249)* |
| F21.11 | `with` on a bare `term` is refused — a foreign map is not known to be a record |
| F21.12 | `with` on a `list<(atom, term)>` is refused — ticket 48's probe, the shape that was read as map-update support |
| F21.13 | `with` on a union where one member lacks the field is refused, and the residual is that member |
| F21.14 | `with` on a union where every member carries the field is legal, and the value half runs **per member** |
| F21.15 | `with` on a recursive record is still a record update — the control at the binder |

## Built 2026-08-21

**471 tests, up from 462.** Seventeen gates, all green.

**One existing test was rewritten rather than extended, and its old body is why ticket 36 exists.**
`records_tests:with_cannot_add_a_field_test` used to build the module, call it, and assert
`?assertError({badkey, 'Extra'}, …)` — it certified that `with` cannot add a field **by observing
the BEAM raise**. 26 §2 is real, but F3 was enforcing it at run time and this test recorded that as
the intended behaviour, so nothing was left to notice the compiler had never checked. The claim is
now made where 26 §2 belongs. The runtime half needs no test: it is `erlc`'s `:=`, and it can no
longer be reached from source that compiles.

That is the general shape worth carrying forward: **a test that asserts a runtime crash may be
recording a missing compile-time check as a feature.**

**Two tests changed only by gaining `construction`** in the `field_set_mismatch` tuple, which is the
whole cost of the verb fix at the term level.

## Corrected 2026-09-03 — the subject (ENG-249)

**`with` checked the fields it named and never asked what was being updated.** The clause above
reads `declared_fields/1` off the base's type, and when the base is not one closed record the
answer is `unknown` — which the clause took as *no information* and passed the base's type through
untouched. So `n with { Total = 1 }` on an `int` typed as `int`, the `int` return type was
satisfied, and the BEAM raised `{badmap, N}` when it ran. A `term` and a `list<(atom, term)>` were
accepted the same way. Found on 2026-08-25 by a probe written for ticket 48 to check a claim its
own survey had made — that `with` was already a map-update form. It was, in the sense that nothing
looked.

**The fix is site 3's relation in `with`'s verb, and nothing new in `bs_types`.** One closed
record keeps the path built above, byte for byte. Everything else is asked `subject \ { K: term, .. }`
per field: a non-empty residual is the member that may lack the field, handed back exactly as the
dot hands it back, and `field_absent` gained a `form` (`projection` | `update`) the way
`field_set_mismatch` did rather than a sibling. The refused expression synthesises `reported()`,
so the return check no longer certifies whatever an updated `int` would have been.

**One thing the fix reaches that the defect did not name.** A union of records whose every member
carries the field is a *legal* subject — the subtraction is empty — and the value half then runs
against **each member's own declaration** (F21.14). It has to: the subject may be either record at
run time, and a value one member's `Total` accepts and the other's rejects would build the second
record in breach of its own type. Two members, two verdicts, each naming its record.

**Six tests, one probe, one control.** F21.10–F21.15 in `body_check_tests.erl`; probe 5 in the
gate, and the `SUBJECT-BLIND` stub, which is this feature exactly as it shipped and which the gate
passed for thirteen days. Two projection tests changed only by gaining `projection` in the
`field_absent` tuple. `LANGUAGE.md` §6 gained the sentence and a replayed example.
