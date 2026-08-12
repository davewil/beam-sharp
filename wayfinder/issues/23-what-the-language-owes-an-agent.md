# 23 — What does the language owe an agent that writes it?

Type: grilling
Status: open
Blocked by: 11

## Question

The map carries a standing constraint: **beam-sharp is written by agents and read by humans.**
Every prior ticket was written assuming a human author. This one asks what changes when the
primary author is a program.

Decide:

### Diagnostics as an interface, not prose

Ticket 04 established that exhaustiveness is `t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0` and that **the
residual is the missing case** — CDuce prints the residual type plus a sampled counter-value. For
a human that is a good error message. For an agent it is *the clause it needs to write*.

- Do diagnostics have a **machine-readable form** as a first-class output (structured, not
  prose-that-happens-to-parse)? What is in it — residual type, sample value, the clause position
  to insert at, a suggested clause?
- Is that form **stable across compiler versions**, given something will depend on it?
- Does the compiler ever emit a **suggested fix** rather than only a diagnosis, and what happens
  to trust when a suggestion is wrong?

Ticket 20 recorded readable error messages and type pretty-printing as an open problem named by
Castagna himself. Under this constraint that problem is a **product** problem, not a cosmetic one.

### The scaffolding contract

Tooling generates files (`mix gen.operation Order.Apply` or similar). That makes the generator
part of the language's surface, not an afterthought.

- What exactly does a generated file contain, and is a stub with a signature and no clauses a
  **compile error** (nothing is exhaustive) or a permitted intermediate state?
- Can the compiler generate the *signature* from the type declarations, so an agent writes only
  clauses?
- How does an agent discover what operations an aggregate already has, without reading every file?

### Blast radius and write scope

One function per file makes an agent's write scope a file. Decide whether the language leans into
this deliberately:

- Should anything **forbid** an edit in one file changing another file's meaning? Type
  declarations already can — a change in `order.bs` invalidates every clause in the directory.
- Should a compile error name **which files** must change, so an agent's task list is derived
  rather than guessed?

### What must NOT be optimised for agents

State this explicitly so later sessions do not over-rotate:

- **Read and review cost keeps full weight.** `(0)` and `()` at nullary and unary arity,
  `Order.Server.Apply` colliding with `Order.Apply` — these are defects because a human reviews
  them, and agent authorship does not excuse them.
- **Verbosity is not a virtue either.** Cheap-to-write is not the same as good; the fact that a
  generator can emit anything is not a reason to require more of it.

## Notes

HITL. Raised 2026-08-12 from the standing constraint. Blocked by ticket 11 because the diagnostic
format depends on what the type system actually computes and can name.

Interacts with ticket 22: enforced conventions are guardrails on an agent, which is an argument
for opinionation that a human-authorship analysis would not produce.

## Constraints from ticket 11 — resolved 2026-08-12

- **The residual is the missing clause**, and ticket 11 kept it that way deliberately: an
  unhandled boundary case shows up as a non-empty `term \ (Acc(p₁)|…|Acc(pₙ))`, which is the
  clause the agent must write, handed over rather than described.
- **A compile error can name its own fix.** `ValidateAs<T>` on an arrow type is rejected, and the
  error's useful form is *"an arrow has no runtime evidence — take `{M,F,A}` instead"*. That is
  the diagnostics-as-instructions property this ticket is about, in a second concrete instance.
- **Counterweight, and this ticket owns it**: `ParseAtom<T>` and `ValidateAs<T>` are
  **compiler-generated bodies nobody writes and no reviewer reads**. The standing constraint says
  agents author and humans review, so generated code is the one place that constraint has no
  purchase. Decide what the language owes a reviewer here — emitted source, a documented lowering,
  or nothing.
