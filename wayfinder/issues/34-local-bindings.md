# 34 — Does the language have local bindings, and is a body one expression?

Type: grilling
Status: open

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
