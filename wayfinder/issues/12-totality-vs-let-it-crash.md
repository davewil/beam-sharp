# 12 — Totality versus let-it-crash

Type: grilling
Status: resolved
Blocked by: 04, 11 — both resolved

## Question

Must every function be exhaustive?

The conflict is cultural as much as technical:

- **Enforced totality** is the guarantee that justifies the type system. If clauses must
  cover the input type, a whole class of `function_clause` crashes disappears at compile
  time — and that is the headline claim.
- **But BEAM culture says a badly-shaped message should crash the process.** Erlang's
  `function_clause` error is a *feature*: the process dies, the supervisor restarts it, the
  system stays up. Defensive exhaustive handling of impossible cases is an anti-pattern
  there, not a virtue.
- And the compiler cannot know everything: a message arriving from an untyped Erlang caller
  may have any shape at all, so total-in-theory functions still meet impossible input in
  practice.

Decide the stance. Candidates: total by default with an explicit partial opt-in; partial
permitted with a warning; total only where the input type is fully known and dynamic
elsewhere; or totality enforced at typed boundaries and abandoned at dynamic ones.

Then state how it interacts with **supervision** — if a clause is proven exhaustive but the
runtime value defies it, what happens, and does the process still die cleanly?

## Sharpening from ticket 06

The ticket's framing assumed the choice is between crashing and not crashing. Ticket 06 showed
there is a **third outcome that is worse than either**: silent unsoundness, where a badly-typed
value never crashes at all and the type system is simply wrong. `add(1.5, 2.5)` on a function
typed `Int, Int -> Int` returns `4.0`, quietly.

That reframes let-it-crash as an *ally* of the type system rather than its opponent — a crash
is the honest outcome, and the real enemy is the silent one. Weigh that before treating
totality and let-it-crash as opposed. Ticket 18 handles the emitted-guard question this raises.

## Prior art to consult first (from ticket 03)

**PureScript records partiality in the type and discharges it at a named site** — a
propagating `Partial` constraint. A partial function is not an error; it is a function whose
type says it is partial, and the obligation travels with it until someone explicitly accepts
it. That is a fourth option beyond the candidates above, and it maps unusually well onto
let-it-crash: the crash site becomes a declared, greppable place rather than an accident.

**Hamler removed exactly this mechanism and kept only a warning.** That is a natural
experiment in the option space — worth understanding why before repeating either choice.

**But ticket 19 found `Partial` does not survive to codegen.** It is erased before CoreFn
(`unsafePartial` compiles to applying the argument to the atom `unit`), so the backend has
*zero* coverage knowledge and unconditionally emits `erlang:error({fail, …})` on every
non-total branch. Contrast with ticket 02's finding that the Erlang compiler **omits
`match_fail` when it can see exhaustiveness**: that backend can never make the call, so it pays
for a failure arm it may not need, every time.

**beam-sharp's ticket-04 checker computes exactly the fact that backend lacks.** A checker that
proves the clauses cover the input can tell the code generator to omit the failure arm. That is
a concrete, measurable payoff for the exhaustiveness work — worth stating in the spec, because
it turns the guarantee into emitted-code savings rather than only a compile-time promise.

## Notes

HITL. This is where the language's philosophy gets decided, not merely its semantics.

## Constraints from ticket 11 — resolved 2026-08-12

- **The guarantee sentence now exists** and this ticket must not contradict it: *"Every case your
  types admit has a clause — and everything from outside is a `term` until you match it."* It was
  chosen to be stable whichever way this ticket and ticket 18 go.
- **The boundary clause is now forced to be written, but not forced to do anything.** A `term`
  argument leaves a non-empty exhaustiveness residual until a catch-all clause exists, so the
  checker makes you *name* the foreign case. What that clause does — crash, return an error
  value, log and ignore — is exactly this ticket's question, and the type system now guarantees
  there is somewhere to put the answer.
- **A precedent has been set in one direction already**: `ValidateAs<T>` returns `T | :error`, so
  the one boundary construct the language has decided so far **fails as a value, not a crash**.
  Decide whether that generalises or is an exception.
- **There is no `dynamic`**, so "let it crash" cannot be reached by weakening a type. The only
  routes into a crash are an explicit clause body or an unhandled foreign term.

## Answer — resolved 2026-08-12

> Decision brief: [`../beam-sharp-eng-178.html`](../beam-sharp-eng-178.html) ·
> [published artifact](https://claude.ai/code/artifact/540cd745-ee79-40b4-ba7c-903ecbb962fe)

**Totality is enforced, and let-it-crash is how you spell partiality.** The two were never
opposed; ticket 06 had already shown the enemy is *silence*, not the crash. Six decisions.

### 1. A non-exhaustive function is a hard error, with no opt-out

Being partial means writing a clause whose body crashes. There is no `Partial` constraint, no
`[partial]` attribute, and no warning level.

**Two of this ticket's own four candidates were already dead** when it was picked up. "Total only
where the input type is fully known, and dynamic elsewhere" and "totality at typed boundaries,
abandoned at dynamic ones" both presuppose a dynamic region to abandon totality *to*, and
[ticket 11](11-type-system-shape.md) removed it. Every argument carries a declared type, `term`
*is* a declared type, and exhaustiveness against `term` is well-posed — the residual stays
non-empty until a catch-all exists. So the choice was only ever about enforcement strength.

Three prior decisions pointed the same way:

- **Ticket 04 makes the question always answerable.** Exhaustiveness is only well-posed against a
  *declared* input type — which is why Elixir cannot check it (it builds the function type *from*
  the clauses, making the check vacuous) and CDuce can. Ticket 04 turned that into a binding
  constraint: multi-clause functions carry signatures. A warning is what you ship when the check
  is sometimes unavailable; here it always is.
- **[Ticket 21](21-escape-hatch-precedents.md) supplies the discriminator**: Microsoft's named
  successor to Code Contracts was nullable reference types — *the contract that survived is the
  one that became a type*. A warning-level exhaustiveness check is precisely a contract that did
  not become a type. [Ticket 07](07-csharp15-and-ts-unions.md) found C# 15's unions do exactly
  that (exhaustiveness suppresses a *warning*), and Elixir 1.20 ships redundancy only. If
  beam-sharp's guarantee is also warning-shaped, [ticket 00](00-charting-decisions.md)'s
  differentiator evaporates.
- **The standing constraint**: a warning is something an agent in a loop steps over; an error is a
  task. Ticket 04 established the residual *is* the missing clause, so the error hands the agent
  the code it must write — which only works if the compiler stops.

**What was given up**: PureScript's `Partial` was the most attractive option on the table, and it
maps unusually well onto let-it-crash (a declared, greppable, propagating crash obligation). It
lost on two counts. [Ticket 19](19-purescript-backend-erl-audit.md) found `Partial` **does not
survive to codegen** — erased before CoreFn, so it is a compile-time fiction in a language whose
checker computes exactly the fact that backend lacks. And a propagating constraint is a second
effect system running alongside a set-theoretic type system whose tallying algorithm ticket 04
found has **no complexity bound in the literature**. See §5 — the greppable-crash-site benefit
came back anyway, through the bottom type.

### 2. A catch-all is legal only over an *open* residual

When the checker computes a residual it is one of two shapes, and the language treats them
differently:

- **Closed** — built only from cases you declared. `type Event = OrderPlaced | OrderShipped |
  OrderCancelled;` with two handled leaves the residual `OrderCancelled`, and **the compiler knows
  its name**. `_` here is an error: name the case. This is the defect the language exists to catch,
  and a catch-all would make the function unfalsifiable when a fourth event is added.
- **Open** — contains an unbounded top. A `term` argument's residual is `term \ (what you
  matched)`; [ticket 10](10-atoms-in-a-csharp-skin.md) made `atom` the cofinite top with exactly
  this representation. It cannot be enumerated because a foreign sender chooses the inhabitants, so
  a catch-all is the only possible answer — and ticket 11 already *forces* one.

This answers the tension [ticket 01](01-sample-code.md) raised: *a catch-all makes a function total
and therefore unfalsifiable*. Under a hard error the catch-all would otherwise be the universal
escape, and the cheapest way to satisfy the compiler is always to stop telling it things.

**The showcase lands on the permissive side without special pleading.** `handle_info` receives
OTP's `{'EXIT', pid, reason}`, `{'DOWN', ...}`, timeouts and stray messages; those arrive as `term`,
the residual is open, and the catch-all is legal because it is genuinely unavoidable.

**Cost, stated honestly**: this is a tier-3 invention. C#'s `_` in a switch arm is just a pattern
and TypeScript's `default` is just a branch; neither audience expects `_` to be *conditionally
legal*, so it fails the read-on-sight test. It was accepted because the alternative fails a more
expensive test — a uniform `_` puts the headline guarantee one character from being switched off,
silently, with no trace in the diff. Ticket 21's finding applies: the mechanism that works is the
one **the tool that already builds the code** runs, and the checker is already computing the
residual.

**Open question handed to [ticket 25](25-exemplar-programs.md)**: how often closing a *finite*
residual is genuinely wanted. If common, forcing every case to be named is a tax and a marked
spelling for a deliberate close is worth inventing; if rare, it is ceremony. The database and
event-queue exemplars are where this should bite.

### 3. The boundary stance is signature-directed

**Write the honest value your return type admits; `raise` only where it admits none.**

Ticket 11 left the boundary clause *forced to be written, but not forced to do anything*. The
candidate answer was positional — crash in a call, continue in a loop — and writing the two rules
out showed they are one rule:

```csharp
(:reply, int, Account) HandleCall(term, From, Account);

((:withdraw, amt), _, a) when amt > 0 && amt <= a.Balance -> (:reply, a.Balance - amt, a);
((:balance), _, a)                                        -> (:reply, a.Balance, a);
(_, _, _)                                                 -> raise :bad_request;
```

```csharp
(:noreply, Account) HandleInfo(term, Account);

((:DOWN, _, :process, pid, _), a) -> Accounts.Detach(a, pid);
((:timeout, _), a)                -> Accounts.Sweep(a);
(_, a)                            -> (:noreply, a);
```

`HandleCall`'s declared return `(:reply, int, Account)` contains **no honest value** for an
unrecognised request — the alternatives to crashing are fabricating an integer (a lie the type
system accepts) or not returning (unavailable). `HandleInfo`'s `(:noreply, Account)` makes
`(:noreply, a)` completely honest: the message was not addressed to you, and saying so is the
declared behaviour, not silence. **The position was never the operative fact; the return type was.**

The test is wanting the other behaviour. You do not reach for a different rule — you widen the
signature, and the value channel appears:

```csharp
(:reply, int | :bad_request, Account) HandleCall(term, From, Account);
...
(_, _, a)                                                 -> (:reply, :bad_request, a);
```

The crash disappeared because the author declared somewhere for the failure to go. **This is
ticket 21's discriminator applied to this ticket**: the crash-versus-value decision *became a
type*, visible in the contract a caller sees, rather than a convention a reviewer must police.

**So `ValidateAs<T>` returning `T | :error` is not an exception to a rule** — it is a signature
that declared a failure channel. The interrogative/declarative distinction considered earlier is
unnecessary; the signature already says it.

Two honest limits. *Honest* is not a compiler check — the compiler says what is **available**, only
the author knows whether `(:noreply, a)` is truthful or a shrug; what the language guarantees is
that the shrug was deliberate, because the clause had to exist. And the language cannot enforce a
stance at all, since the clause body is user code: what a stance buys is what the spec recommends
and what scaffolding generates (→ [ticket 23](23-what-the-language-owes-an-agent.md)).

### 4. The bottom type is `none`, fully first-class

For `raise` to type-check in a position declared `(:reply, int, Account)`, the language needs a
type inhabited by nothing and therefore a subtype of every type. Ticket 11 named the top and never
named the bottom.

**Ticket 11's reasoning for `term` transfers without adjustment.** It overrode the borrow heuristic
there — TypeScript's `unknown` is tier 1 and was rejected — because the top is a *set* you take
complements of rather than an epistemic state, and because it matches the emitted `-spec`. Both
hold for the bottom. Taking TypeScript's `never` while the top is `term` would name one lattice
from two heritages, in the one place where both names are always read together.

Verified locally (OTP 28, see [`prototypes/12d_bottom_type.erl`](../prototypes/12d_bottom_type.erl)):
`none()` and `no_return()` are predefined; `never()` is undefined (`type never() undefined`); and
`erl_types:t_none()` prints the empty type as `none()`.

**First-class, not checker-internal.** Diagnostics are an interface here: ticket 04 established the
residual *is* the missing clause, and when a function is exhaustive that residual is the bottom, so
the name appears in compiler output whether or not it appears in source. A type an agent reads in a
diagnostic but cannot write in a signature is a gratuitous asymmetry, and `term` is writable.

**Known false friend, to be stated in the spec**: `none` (a type with no values) against the
prelude's `:nothing` (a value meaning absence, ticket 10 §5). They read as near-synonyms and are
opposites — `-> none` means *does not return*, not *returns nothing*. Same treatment as `as`
meaning C#'s checked conversion rather than TypeScript's unchecked assertion.

### 5. A deliberate crash is spelled `raise`

A tier-2 borrow — Elixir's — not an invention and not C#'s `throw`.

**C#'s `throw` was the tier-1 candidate and it is stronger than it first looks**: C# 7 already made
`throw` an expression (`x ?? throw new ArgumentNullException()`), which is exactly the bottom-typed
form needed. It fails on semantics, which is what tier 1 is explicitly about. **The BEAM already
uses `throw` for the *catchable* non-local-return class**, so a BEAM reader would read recoverable
where the language means fatal — a false friend that fails unsafe.

Verified (Elixir 1.19.5, [`prototypes/12b_raise_classes.exs`](../prototypes/12b_raise_classes.exs)):

| spelling | class |
| -- | -- |
| `raise "boom"` | `{:error, %RuntimeError{}}` |
| `:erlang.error(:boom)` | `{:error, :boom}` |
| `throw(:boom)` | `{:throw, :boom}` |
| `exit(:boom)` | `{:exit, :boom}` |

`raise` produces the **same class as `:erlang.error/1`** — the one that kills processes and that
`function_clause` belongs to. No collision.

**Both neighbours chose a keyword over a function**, which settles the other half. A crash could
have been an ordinary prelude function typed `-> none`, needing no grammar change at all; it was
rejected on read cost — lexically identical to a call, the callee's signature in a *different file*
under one-function-per-file, and no single token that finds every crash site. Gleam is the decisive
evidence: a statically typed BEAM language that had the function option available and declined it.
Verified on Gleam 1.18.1 ([`prototypes/12c_gleam_panic.gleam`](../prototypes/12c_gleam_panic.gleam)),
`panic as "..."` compiles in a `case` arm whose siblings return `String`, so it is bottom-typed
exactly as `raise` must be. Elixir's `raise` was preferred over Gleam's `panic` because `panic`
connotes an impossible state where the common case here is an ordinary foreign term, and Elixir is
the larger interop surface (ticket 06).

**The `Partial` benefit returns here.** A user may declare their own `none Reject(Reason);`, and
its type says it never returns — a named, greppable, type-checked crash site, obtained from the
lattice rather than from a propagating constraint. `raise` is simply the primitive.

Payload, and whether `throw`/`exit` also surface, is [ticket 15](15-error-model.md)'s.

### 6. The failure arm is always emitted — *this reverses this ticket's own prior note*

The "Prior art" section above argued that beam-sharp's checker computes exactly the fact
purescript-backend-erl lacks, so proving coverage should let codegen omit the failure arm, and
called that *"a concrete, measurable payoff... worth stating in the spec"*. **Measured, it is not.**

Method (OTP 28, [`prototypes/12a_failure_arm.erl`](../prototypes/12a_failure_arm.erl)): compile to
Core Erlang, strip the `compiler_generated` `match_fail` clause, recompile with `+from_core`.

| | error class | top stack frame | size |
| -- | -- | -- | -- |
| **with** the arm | `error:function_clause` | `{partial, [c], [{file,...},{line,28}]}` | 832 b |
| **without** | `error:if_clause` | `{partial, 1, []}` | 792 b |

**40 bytes, 4.8%.** What it costs is the whole crash report: the wrong error class — `if_clause`,
for a failure with no `if` in it — an arity in place of the offending argument, and no file or
line. The surprise is that omission does not produce undefined behaviour or a silent fall-through;
it produces a crash that **mislabels itself**, so you pay failure's cost without getting the
information failure buys, and a reader is actively misled.

> **Do not cite `if_clause` as the general rule.** That is what *this* lowering produced — a Core
> `case` with its last clause removed. The behaviour of a Core Erlang `case` with no matching
> clause is not specified to be `if_clause` in general, and a different lowering may well differ.
> The decision does not rest on which class it is: `if_clause`, `case_clause` and genuine undefined
> behaviour are all strictly worse than `function_clause` carrying the offending argument. Measure
> again before quoting the class anywhere else.

**That frame is the property this project has twice identified as most valuable.** Ticket 04: the
residual *is* the missing clause. Ticket 23: what do diagnostics owe an agent in a loop.
`{partial, [c], ...}` is the runtime analogue — it hands you the exact value you failed to handle.

**A second reason, independent of diagnostics: `erlc`'s omission and beam-sharp's are not the same
operation.** When `erlc` drops the arm it has proved coverage over **all terms** — `total/1` lowers
to `fun (_0) -> 1` with no `case` at all — so nothing can defy it. beam-sharp's exhaustiveness is
over the **declared type**, a strictly smaller set, and ticket 06 found values outside it arrive
through eight channels. Ticket 21 closes the escape: no link-time closure on the BEAM (`apply/3`,
no visibility modifiers, hot code loading), so "no foreign caller exists" is unprovable.

**Restricting omission to non-exported functions does not work** — a foreign value entering through
an exported function reaches private ones unchallenged. It collapses into the sound version, which
is: omit only where a boundary guard has already rejected defying values. That is
[ticket 18](18-boundary-defence.md)'s decision, and it now has a concrete reason to emit guards.

**This answers the ticket's second explicit ask.** *If a clause is proven exhaustive but the runtime
value defies it, what happens, and does the process still die cleanly?* **Yes — `function_clause`,
naming module, function, offending argument, file and line, which is what a supervisor should log.**
That is deliberately paid for at ~40 bytes per function.

**Alignment for [ticket 13](13-compilation-target-decision.md)**: this is only a *choice* on the
Core Erlang path. Emitting Abstract Format means `erlc` inserts the arm and it cannot be
suppressed — so the target ticket 02 favours makes the safe answer free, and only the Core path,
which already forfeits `-spec` and Dialyzer, offers the 40 bytes.

### The guarantee is unchanged

Ticket 11 chose its sentence to be stable whichever way this ticket went, and it is:

> **Every case your types admit has a clause — and everything from outside is a `term` until you
> match it.**

### Consequences propagated

- **[14 — concurrency and the OTP model](14-concurrency-and-otp-model.md)** — inherits real weight.
  Callback return types now carry the crash decision (§3), so choosing `HandleInfo`'s and
  `HandleCall`'s return types decides where crashing is the only honest answer.
- **[15 — error model](15-error-model.md)** — `raise` exists and produces the error class. Payload,
  the `throw`/`exit` trio, and `try`/`catch` remain 15's.
- **[18 — boundary defence](18-boundary-defence.md)** — emitted guards are the only sound route to
  the codegen saving (§6). Still blocked on 22.
- **[13 — compilation target](13-compilation-target-decision.md)** — Abstract Format makes §6 free;
  Core Erlang is the only path where the 40 bytes are even available.
- **[23 — what the language owes an agent](23-what-the-language-owes-an-agent.md)** — the
  `function_clause` frame is the runtime analogue of ticket 04's residual; and scaffolding must
  generate a boundary-clause body, so §3's stance reappears as a generator default.
- **[25 — exemplar programs](25-exemplar-programs.md)** — owes the empirical answer on how often a
  *closed* residual is deliberately closed (§2).

## Constraints from ticket 13 — resolved 2026-08-12

**§6's decision is now enforced by the target rather than by policy.**

Ticket 13 chose the **Erlang Abstract Format**, on which `erlc` inserts the `match_fail` arm itself
and there is no way to suppress it. So the failure arm is always emitted because it *cannot* be
omitted — the 40-byte (4.8%) saving this ticket declined is not merely declined, it is unavailable.

Two consequences:

- **The conditional at the end of §6 is discharged.** It bound a future Core Erlang choice to emit
  the arm anyway "unless ticket 18 decides to emit boundary guards". Ticket 13 did not choose Core,
  so that branch is closed, and ticket 18 has correspondingly lost the codegen saving as a
  motivation for emitting guards.
- **The safe answer is free, and unavailable to get wrong** — which is the outcome this ticket
  argued for on diagnostic grounds, now obtained structurally.

Visible in the Core generated *out of* the emitted abstract forms
([`prototypes/13a_target_measurements.md`](../prototypes/13a_target_measurements.md) §3): the
`( <_1> when 'true' ->` clause is `erlc`'s, not beam-sharp's.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Totality versus let-it-crash](issues/12-totality-vs-let-it-crash.md) — **the two were never
  opposed; let-it-crash is how you spell partiality.** Exhaustiveness is a **hard error with no
  opt-out** — two of the ticket's four candidates were already dead, since both presupposed a
  dynamic region ticket 11 removed. PureScript's `Partial` lost twice over: ticket 19 found it
  **erased before codegen**, and a propagating constraint is a second effect system beside an
  algorithm ticket 04 found has no complexity bound. A **catch-all is legal only over an *open*
  residual** — permitted where an unbounded top remains (and ticket 11 already forces it), an error
  where the residual is closed and the compiler knows the case names; a tier-3 invention, accepted
  because a uniform `_` puts the headline guarantee one character from being switched off
  invisibly. The boundary stance is **signature-directed**: write the honest value your return type
  admits, `raise` only where it admits none — so "crash in a call, ignore in a loop" is only the
  shadow cast by two return types, and **`ValidateAs<T>`'s `T | :error` is not an exception but a
  declared failure channel**. This is ticket 21's discriminator again: the decision *became a type*.
  The bottom is **`none`, first-class** (verified: `never()` is undefined on OTP 28, `erl_types`
  prints `none()`), mirroring ticket 11's `term` override — one heritage names the whole lattice;
  its false friend is the prelude's `:nothing`. A deliberate crash is **`raise`**, tier-2 from
  Elixir, verified to produce the **error** class, so C#'s `throw` is out on semantics — the BEAM's
  `throw` is the *catchable* class. **Both neighbours chose a keyword**, Gleam's bottom-typed
  `panic` decisively so, having had the function option and declined it — and the `Partial` benefit
  returns anyway, since a user-declared `none Reject(Reason);` *is* a greppable typed crash site.
  Finally, **this ticket reverses its own prior note**: the failure arm is **always emitted**.
  Omitting it saves **40 bytes (4.8%)** and destroys the crash report — `error:if_clause` (the
  wrong class) with an arity in place of the offending argument. `erlc`'s omission proves coverage
  over *all terms*; beam-sharp's is over the *declared type*, and ticket 21 says no foreign caller
  can be ruled out. So **yes, the process still dies cleanly**, deliberately paid for. Emitted
  guards (→ 18) are the only sound route to the saving, and it is only *available* on the Core
  Erlang path at all (→ 13).
```
