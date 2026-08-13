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

## Constraints from ticket 12 — resolved 2026-08-12

**A runtime analogue of ticket 04's residual now exists, and it was nearly thrown away.**

This ticket records that the exhaustiveness residual *is* the clause an agent needs to write — a
compile-time diagnostic. Ticket 12 §6 found the runtime counterpart: the compiler-generated
failure arm produces `error:function_clause` with the frame
`{Module, Function, [c], [{file,…},{line,…}]}` — **naming the exact value that defied the types**.
Omitting the arm to save 40 bytes (4.8%) replaces it with `error:if_clause` and
`{Module, Function, 1, []}`: the wrong error class, an arity instead of the argument, no file, no
line. Measured on OTP 28, [`prototypes/12a_failure_arm.erl`](../prototypes/12a_failure_arm.erl).

So the diagnostic question this ticket owns extends past compile time. **An agent debugging a
running system reads crash reports**, and the same principle applies: the frame that names the
offending value is the one that hands the agent its next task. Add to this ticket's scope whether
the runtime failure carries a machine-readable form too, not only the compile-time diagnostic.

**A scaffolding obligation, from ticket 12 §3.** The boundary stance is signature-directed — write
the honest value your return type admits, `raise` only where it admits none — but the language
cannot *enforce* it, because the clause body is user code. So the stance reappears here as a
**generator default**: what does scaffolding put in a mandatory boundary clause? Under agent
authorship the generated default becomes what most code actually does, which makes this a real
decision rather than a cosmetic one.

**And a related surface**: ticket 12 §2 makes `_` an error over a *closed* residual — the compiler
knows the case names. That diagnostic should therefore be able to emit the missing clause heads
directly, which is the strongest instance yet of "the residual is the clause you must write".

## Constraints from ticket 14 — resolved 2026-08-12

**Two jobs land on the scaffolding generator, and one of them is a policy knob the language
deliberately declined to hard-code.**

- **Default callback signatures are a generator setting, not language semantics.** Ticket 14 §4
  settled that the user writes a *narrower* callback signature and the compiler checks containment
  against a typed OTP contract. That choice was taken partly on reversibility: a project that
  wants OTP's full six-way union, or a fixed narrow subset, gets it by configuring what the
  generator emits — no language change either way. So this ticket owns the question of what the
  generated default *is*, and it is a real decision with a real cost: the wide default makes an
  evasive `(:noreply, s)` always type-correct, and per ticket 12 that is where the crash policy
  quietly disappears.
- **Generate system-message clause heads.** Ticket 14 §6 found a blind spot nothing in the checker
  catches: a `handle_info` clause written with the wrong *shape* for a system message never fires,
  and the mandatory catch-all absorbs it in silence
  ([`14g`](../prototypes/14g_handle_info_blind_spot.erl)). The primary mitigation is the
  compiler-known prelude stratum, but generating the clause head for whichever system messages a
  module subscribes to means the shape is never hand-written at all.
- **The prelude is stratified, which changes what "the language owes" means.** Ordinary aliases a
  user could have written, versus a compiler-known stratum they could not — modelled on Elixir's
  `Kernel.SpecialForms`, verified locally on Elixir 1.19.5 to win resolution against a
  same-named user macro. `ParseAtom<T>`, `ValidateAs<T>` and now OTP's message shapes live there.
  An agent writing beam-sharp needs to know which stratum a name is in, because one is
  documentation and the other is a compiler guarantee.

Standing constraint reminder from the map: write-cost objections carry little weight here, so
"the generator emits a lot" is not an argument against any of the above.

## Constraints from ticket 15 — resolved 2026-08-12

**A concrete instance of this ticket's diagnostics-as-interface question, already decided.**

Ticket 15's foreign wrapper yields
`foreign_error = (:error, term) | (:throw, term) | (:exit, term)`, and the class tag was kept
rather than flattened **specifically on this ticket's grounds**: `(:exit, (:noproc, _))` means *the
process is gone* and `(:error, :badarg)` means *your argument was wrong*, which are different
repairs for an agent in a loop. A flattened reason is not self-describing — measured,
`{noproc, {gen_server, call, [...]}}` needs the `exit` tag to be legible as a death rather than a
returned value.

So the language now has **two** worked examples of a diagnostic designed as a data structure an
agent dispatches on rather than prose it parses: ticket 04's exhaustiveness residual, and this.
Both are ordinary clause-head material. That is a candidate general principle for this ticket to
state: *a diagnostic an agent must act on should be a value the language can already match.*

Also inherited: `ValidationError` is a path into the term plus the expected type, chosen because a
bare `:error` from a synthesised O(n) traversal tells the consumer only that the traversal ran.

## Evidence from ticket 17 — 2026-08-13

**The residual-as-the-missing-case is not a research finding any more. A shipping BEAM compiler
prints it today**, and ticket 17 measured it rather than citing it
([`prototypes/17c`](../prototypes/17c_else_in_the_neighbourhood.md), Gleam 1.18.1):

```
error: Inexhaustive patterns
This case expression does not have a pattern for all possible values.

The missing patterns are:

    False
```

Ticket 04 established this from CDuce, which prints a residual type plus a sampled counter-value.
This is the same behaviour in a statically typed BEAM language, in a diagnostic a user sees today.

**So this ticket's question narrows.** It is no longer *"could a compiler hand an agent the clause
it must write"* — one does. It is:

- **Should the residual be a machine-readable output as well as prose?** Gleam's is prose with the
  pattern embedded in it. An agent parsing `The missing patterns are:` is screen-scraping a string
  that is not part of any compatibility contract.
- **Is the prose form even the right primary?** Under the standing constraint the primary consumer
  is a program, and the human reads the same information at review time. Gleam optimised for the
  human because that is Gleam's only reader.

A second, smaller datum in the same prototype: **Gleam's refusal of `if` is expressed as a designed
diagnostic** — *"Gleam doesn't have if expressions. If you want to write a conditional expression you
can use a `case`:"* with a template. That is a compiler telling an author what to write instead, for
a construct it deliberately does not have. Under agent authorship that is exactly the shape this
ticket is asking about, applied to a *language surface* question rather than a type error.

## Evidence from ticket 18 — resolved 2026-08-13

**A worked anti-example, and one question 18 declined to pay for and handed here.**

**The anti-example: Elm defends its boundary correctly and then makes the rejection unreadable.**
Measured, Elm 0.19.1 ([`research/18-elm-port-validation.md`](../research/18-elm-port-validation.md)).
Elm synthesises a decoder from each port's declared type and runs it on every incoming value, so the
mechanism is sound — and then:

- a rejection is a **synchronous JavaScript `throw`** into the caller's stack frame; **Elm code never
  sees it**, so nothing in the language can log, report or recover;
- **under `--optimize` the entire message collapses to a bare URL** — `https://github.com/elm/core/blob/1.0.0/hints/4.md`
  — with no port name and no offending value;
- even in dev builds it prints `[object Object]`, because flags call `_Json_errorToString` and ports
  do not (elm/core #1043, **open since 2019-09-16**).

This is the exact inverse of ticket 04's finding that the exhaustiveness residual *is* the missing
case. Elm's compiler **knows** which decoder failed and on what value, and discards both. Under this
map's standing constraint the consumer is an agent in a loop, and an agent handed a URL has nothing
to act on — it cannot even name the port to a human. **Whatever this ticket decides about
machine-readable diagnostics, the boundary rejection is a case it must cover**, not only the
type-error and exhaustiveness cases: it is a *runtime* diagnostic, and 17's Gleam evidence and 04's
CDuce evidence are both compile-time.

**The question handed here.** Ticket 18 §1 and §4 make the emitted boundary **invisible in the
surface language** — the beam-sharp source is byte-identical whether a guard was emitted or not, and
§4 confines the analysis to one function so it is at least *predictable*, but never *visible*.
18 considered emitting a manifest of what was guarded and **rejected it there** as a build artefact
the spec would have to define, version and keep stable — explicitly noting it would hand this ticket
a dependency it had not asked for.

So the question arrives here on its own terms rather than as 18's leftover: **should an agent be able
to ask the compiler what it defended?** Note it is the same question as the diagnostics one wearing
different clothes — a machine-readable residual tells an agent *what clause to write*, and a
machine-readable boundary tells it *what the emitted code will actually trust*. If this ticket
concludes the compiler owes an agent a structured output at all, the boundary is a second consumer
of that same channel, not a separate feature.
