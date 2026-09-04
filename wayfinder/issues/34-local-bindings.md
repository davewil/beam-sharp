# 34 — Does the language have local bindings, and is a body one expression?

Type: grilling
Status: **resolved 2026-08-14** — see [Answer](#answer) at the end. Built the same day as
[F4](../../compiler/features/F4-local-bindings.md).

> **TWO CORRECTIONS TO THIS TICKET, BOTH MINE, BOTH MADE BEFORE IT WAS RESOLVED.**
> They are left in place rather than edited away, because one of them is a lesson about the
> map's method and not just about this ticket.
>
> **1. The headline evidence is a selection effect and was presented as a finding.** *"Zero
> binding-shaped lines across 25a and 25c"* measures **nobody trying**, not nobody wanting: those
> exemplars were written by agents inside a language that had no bindings, in sessions where the
> absence went unnoticed. David reached for one within a minute of getting a prompt. **The
> anecdote was the stronger evidence and this ticket buried it as the raising note.** Guard
> against this generally: a measurement taken inside a constraint cannot test the constraint.
>
> **2. §"Why it is worth a ticket anyway", point 3 is factually wrong.** It says a binding
> *"lowers to a `case … of` or a `begin … end` block, which is a real emission question"*.
> Measured: an Erlang clause body is **already a sequence** and `{match, …}` is an ordinary form,
> so the lowering is a flat list and needs neither. Nothing was at stake in the emission target.

Raised 2026-08-14 by David typing `o = Order{Id = 1, Total = 500}` at the REPL, one minute after
records shipped. It is the first thing he reached for, and the language has no such construct.

## Question

**A clause body is one expression, and there is no way to bind a name inside it.** No `let`, no
`x = e`, no sequence. A name is bound by a clause head and nowhere else.

That is not a gap in the implementation — it is the state of the *grammar*, and it has never been
decided. A grep across every ticket, the map and `CONTEXT.md` for local bindings, let-bindings,
intermediate values or single-expression bodies returns **nothing**. Twenty-four tickets settled
the type system, the error model, dispatch, pipelines and records without anyone writing down
whether you can name a value.

**So: is the absence a position or an oversight — and if a position, does it survive contact with
the workloads ticket 25 fixed?**

## The evidence that already exists, and it points at "position"

**Zero** binding-shaped lines across [`25a`](../prototypes/25a-http-api-server.md) and
[`25c`](../prototypes/25c-event-queue-consumer.md) — measured, not estimated. Those exemplars were
written before records existed and without anyone deciding this, so the style was not being
protected; it simply never came up.

**Three closed decisions explain why.** They were each taken for their own reasons and together
they leave very little for a binding to do:

- **[Ticket 01](01-sample-code.md)/[08](08-head-and-guard-syntax.md): the clause head destructures.**
  Most of what a C# author binds a name to is something they are about to take apart, and here
  the head has already done it — under a *signature*, with exhaustiveness checked.
- **[Ticket 17](17-pipeline-and-comprehension.md) §1: `|>` sequences.** The other common use of a
  binding is threading a value through steps, which the pipe does without naming the middles, and
  §4's valve does for the fallible case.
- **[Ticket 16](16-ad-hoc-polymorphism.md) §6 / 17 §1: lifting into a named function is *better*,
  measured.** 25c reports that lifting two of four conditions into named functions to fit the
  tuple subject **improved** the code, and that a `cond` ladder would have inlined them and read
  worse. A binding is the same inlining pressure at a smaller scale.

So the honest first question is not *"what would a binding look like"* but **"which of the six
exemplars is worse without one, and how much"** — and the answer today is *none of them,
observed*.

## Why it is worth a ticket anyway

**Three things push back, and none is answered.**

**1. Nobody has written the exemplars that would stress it.** 25a's workload was retracted as
contrived and its replacement is not written; the database, async-processing and dynamic-web-page
exemplars do not exist. The one where a value is computed once and used *twice* is the shape the
pipe cannot express and the clause head cannot bind — and arithmetic on a projected field is the
obvious instance, since `o.Total * o.Total` reads two `map_get`s where a binding reads one.

**2. It has a cost the map already prices elsewhere.** With no binding, the only way to name a
value is another function — and under the standing constraint that is *one more file*. Write cost
is near-free, so that is not the objection; **read cost is not**, and a workload that fragments
into eight one-line functions is a reviewer's problem, which is the half of the constraint that
carries full weight.

**3. The compiler cannot currently express it either.** A body lowers to a single abstract-format
expression. Erlang has no `let` either and Core Erlang does, but ticket 13 chose the Abstract
Format — so a binding would lower to a `case ... of X -> ... end` or a `begin ... end` block,
which is a real emission question rather than a syntactic one.

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| The clause head is the destructuring construct, under a mandatory signature | [01](01-sample-code.md), [04](04-crossclause-exhaustiveness.md), [08](08-head-and-guard-syntax.md) |
| `\|>` is the single chaining form, with **qualified** names; `\|?>` sequences the fallible case | [17](17-pipeline-and-comprehension.md) §§1, 4 |
| `switch` is the only branching construct — no `if`, no `else` | [17](17-pipeline-and-comprehension.md) §6 |
| Narrowing is **always written, never inferred** — so a binding could not silently narrow | [08](08-head-and-guard-syntax.md), [11](11-type-system-shape.md) |
| The emission target is the Abstract Format, not Core Erlang | [13](13-compilation-target-decision.md) |
| Write cost is near-free; **read cost carries full weight** | standing constraint |

## The sub-questions

**1. Is the absence deliberate?** If yes it should be *stated*, because a C# or TypeScript reader
will reach for a binding immediately — David did, one minute after records landed — and a rule
nobody wrote down is a rule the compiler cannot explain. The REPL now names it, which is a
diagnostic standing in for a decision.

**2. If a binding is added, what is the smallest one?** A body of `name = expr` lines ending in an
expression is the C#/TS shape and the tier-1 borrow. Against it: it introduces **statements** to a
language that currently has only expressions, and it is the first construct whose lowering needs a
block. The narrower option is a single trailing form — Elixir's `with`, already spoken for by
ticket 26 — or nothing at all.

**3. Does it interact with exhaustiveness?** Probably not, since bindings are irrefutable by
construction and [ticket 12](12-totality-vs-let-it-crash.md) makes a refutable one a crash. Worth
confirming rather than assuming, because a `let` whose pattern can fail is a branch the checker
would have to see.

**4. What does it cost the diagnostics?** [Ticket 23](23-what-the-language-owes-an-agent.md) makes
the compiler synthesise clause heads. A body with bindings has intermediate values that no
signature describes, which is the first place in the language where a type exists that nobody
declared — and [ticket 04](04-crossclause-exhaustiveness.md)'s whole position is that a declared
type is what makes the questions well-posed.

## Notes

Blocked by nothing, and **not urgent**: nothing that compiles today needs it, and adding one later
is purely additive — no program written without a binding becomes invalid when one exists. That
reversibility is the reason to leave it open rather than settle it thinly.

**Most valuable after another exemplar or two**, since the case for it is empirical and the
current evidence is two programs written before the question was asked.

**Do not re-raise** ticket 17's pipe or its refusal of `if`. This asks whether a value can be
*named*, not how control flows.

**Linear**: ENG-201. The `NN → ENG-(166+NN)` mapping is already offset by one from ticket 33 — see
the map's Notes — so this is ENG-(167+34).

---

## Answer

**The language has local bindings.** David, 2026-08-14: *"x = 1, y = ("a", "b") etc. are very
useful concepts."* Built the same day as [F4](../../compiler/features/F4-local-bindings.md).

**A body is zero or more bindings followed by one expression**, and the body's value is that last
expression — so a body remains an *expression with names in front of it*, not a statement list. It
is the smallest form that answers the question, and it is a tier-1 borrow both audiences read on
sight.

**Bindings do not shadow.** Rebinding is an error, including rebinding a name the clause head
bound. There is no mutation to assign with, so a second `x =` can only be a mistake, and ticket
08's *narrowing is always written, never inferred* extends to names.

**Three things the resolution turned out to owe, and none was on the ticket:**

- **Two diagnostics, or `erlc` reports them against the emitted `.abstr`** — a file the author did
  not write. Rebinding and unbound names are now `bsc` errors that state the fix. This means a
  scope pass **walks a body**, which [ticket 33](33-body-check-site.md) says the checker does not
  do; the two are not in tension, because **33 is about whether a body is *typed*** and nothing
  here asks a type question. Keep that line sharp — F4 is not the start of a body type-checker.
- **An unused binding stays legal and warning-free.** Naming a value to say what it *is* is a
  reason to write one, and ticket 23 puts the reader first. It lowers `_`-prefixed.
- **The body stays a flat list rather than a block**, which keeps the last expression in tail
  position — verified by recursing 1000 deep with a binding before the self-call.

**Destructuring binds are deferred to [ticket 33](33-body-check-site.md), not refused.** `(a, b) =
pair` can fail, and a failing bind is a branch exhaustiveness never sees, which cuts against
ticket 12. The map already has the machinery to settle it — require
`subtract(TypeOfExpr, TypeOfPattern)` empty, making the bind **provably irrefutable** by the same
residual the clause head uses — but that needs a typed body, which is 33's subject. **This is the
second capability 33 now gates**, after F3's three.

**On §3's worry — does a binding weaken the diagnostics?** It introduces a value no signature
describes, which the ticket flagged against ticket 04's position. In practice it does not arise
*yet*, because no body is typed at all; when 33 lands it becomes the first real instance, and the
answer is likely synthesis rather than inference, since ticket 27 already made instantiation
matching rather than solving.

**Note what did not need deciding.** `y = ("a", "b")` — David's own second example — is still not
writable, because **string literals do not exist**: ticket 20 makes `string` a `binary` refined by
valid UTF-8, and binaries are a later feature. The binding half of that line shipped; the literal
half did not.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Local bindings](issues/34-local-bindings.md) — **the language has them, and their absence was an
  accident rather than a position.** Raised and resolved 2026-08-14 by David typing
  `o = Order{Id = 1, Total = 500}` at the REPL one minute after records shipped. Twenty-four tickets
  had settled the type system, the error model, dispatch, pipelines and records **without anyone
  writing down whether you can name a value** — a grep for it across every ticket, this map and
  `CONTEXT.md` returned nothing. A body is now **zero or more bindings followed by one expression**,
  so a body is still an expression with names in front of it; **bindings do not shadow**, since
  there is no mutation to assign with and 08's *narrowing is always written* extends to names.
  **The methodological lesson is the part worth keeping**: this ticket's headline evidence was
  *"zero binding-shaped lines across 25a and 25c"*, which measures **nobody trying, not nobody
  wanting** — those exemplars were written by agents inside a language that had no bindings. *A
  measurement taken inside a constraint cannot test the constraint*, and the map should treat
  exemplar silence as weak evidence wherever the exemplars were written by the same process that
  set the constraint. Two smaller corrections, both recorded on the ticket: the lowering was
  claimed to need a `case`/`begin` block and needs **neither** — an Erlang clause body is already a
  sequence and `{match, …}` an ordinary form, so the body stays a flat list and the last expression
  stays in **tail position**. **Destructuring binds are deferred to
  [ticket 33](issues/33-body-check-site.md), not refused** — `(a, b) = pair` can fail, which is a
  branch exhaustiveness never sees, and the map already has the machinery to make it *provably
  irrefutable* (`subtract(TypeOfExpr, TypeOfPattern)` empty) as soon as a body is typed. **That is
  the second capability 33 gates**, after F3's three. Sharpest downstream consequence: a scope pass
  now **walks a body**, and the line against 33 must stay sharp — **33 is about whether a body is
  *typed***, and rebinding, shadowing and unbound-name checks ask no type question at all.
```
