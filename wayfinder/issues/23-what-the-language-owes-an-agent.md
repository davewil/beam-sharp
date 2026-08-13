# 23 — What does the language owe an agent that writes it?

Type: grilling
Status: resolved 2026-08-13
Blocked by: 11 — resolved

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

## Answer — 2026-08-13

Probe: [`23a_otp_diagnostic_channels.sh`](../prototypes/23a_otp_diagnostic_channels.sh), OTP 28.5.
Every `[L*]` below is measured there.

**The premise the ticket was written on is wrong in the language's favour.** It asks whether
diagnostics *should* have a machine-readable form, as though one had to be invented. The platform
already has three channels and beam-sharp inherits all of them:

- **Compile time** — `compile:file/2` returns `{ErrorLocation, Module, ErrorDescriptor}` and
  `Module:format_error/1` renders the prose from the descriptor. The term is primary; the string is
  derived [L1].
- **The artefact** — the `abstract_code` chunk carries the forms that were compiled, verbatim; on
  the `+from_abstr` path that is exactly what beam-sharp emitted [L4].
- **Runtime** — `erlang:error/3`'s `error_info` carries an arbitrary structured `cause` in the
  stacktrace frame, rendered by a `format_error/2` callback. Since OTP 24 [L6].

So **Elm's port failure was never inevitable** — it is a mechanism the BEAM has shipped for years
and Elm's runtime had no equivalent of. What *is* attested here is the failure mode: **`erlc`
publishes none of its own structured form** — no flag on `erlc -h` recovers it [L2] — so the
platform builds the value correctly and destroys it at the boundary where the consumer stands.
That is the defect this ticket exists to not repeat, and it is the same defect as Elm's, one layer
out.

### 1. The diagnostic is a term; prose is a pure function of it

Decided, borrowing OTP's split (tier 2). The CLI publishes both, and the prose is generated from
the term rather than alongside it, so they cannot drift.

**The prose is terse, and states the fact rather than narrating the mechanism.** The skeleton
printed `the residual is the clause you must write.` under the diagnostic; it was cut (David:
*"Yuck. Is that line even required"*) because `no clause matches:` plus the head already says it.
The general rule: **the term carries what to act on, so the prose owes only the fact.** A
diagnostic explaining its own theory is a design document leaking into a compiler.

### 2. The compiler synthesises the head, never the body

The residual is a *set*; a clause head is a *pattern plus a guard*; lowering one to the other is a
real compilation step and the compiler owns it, so that consumers never each invert it differently.
The skeleton does **not** do this today — measured, it renders type expressions into argument
position, none of them paste-able:

```
Classify((:error, atom)) -> ...     %% `atom` sits where a binder belongs
Classify(int <= -1)      -> ...     %% real head: Classify(n) when n <= -1
Classify(atom \ (:ok))   -> ...     %% real head: Classify(a) when a /= :ok
```

**Where the residual is not guard-expressible the term says so and offers nothing.** Tier-1
refinements always lower, because tier 1 *is* the BEAM guard set; ticket 20's opaque tier does not,
because `binary where valid_utf8` has no guard. Emitting an approximation there would be the Elm
defect in its most dangerous form — output that reads as actionable and silently is not.

**The compiler may not synthesise a body.** A head is *derived* from the residual and cannot be
wrong; a body is a guess. This line is load-bearing and is why §9 below refuses to let the compiler
propose a boundary value: a suggestion that is wrong *in content* is what makes an agent stop
trusting the channel, and one bad suggestion poisons every good one.

### 3. The boundary answers on the same channel

Ticket 18's question — may an agent ask what the compiler defended — is answered **yes, as an
informational diagnostic on this channel**, in beam-sharp's vocabulary, at the moment the agent is
compiling.

18 rejected a manifest because it would be "a build artefact the spec would have to define, version
and keep stable". **That objection is dissolved rather than overruled**: the channel is not a new
artefact, and separately the `abstract_code` chunk already answers the same question faithfully and
durably, for free, with no decision required [L4]. The chunk is *not* chosen as the answer, for two
reasons: it speaks Erlang (`{error, _E}` where the language said `(:error, e)`), which asks the
consumer to invert the lowering §2 just made the compiler own; and `beam_lib:strip/1` removes it,
which release builds routinely do. It remains available as a durable fallback whether or not the
spec blesses it.

### 4. A named subset is contractual; the remainder is opaque

Q1's cost — a versioned surface — is paid only where it buys something. **The spec freezes the
descriptors that hand an agent something to write** (`inexhaustive` with residual and head,
`defended`, `unreachable_clause`); every other diagnostic is structured and renderable but carries
no shape promise.

The test for membership is §2's: *does it hand the agent something to write?* A syntax error does
not — nobody repairs one from a structured term; they re-read the source.

This is **narrower than OTP's own position and wider than nothing**. OTP documents the envelope
exactly and says nothing about the descriptor beyond "pass it to `format_error/1`" [L3] — the
payload is opaque *by documentation*. That works for `{unbound_var,'Y'}`, which is a label for a
sentence, and fails for `{inexhaustive, …}`, which is the thing being acted on.

**Payloads are maps, not tuples**, because a map gains a key without breaking a matcher and a tuple
cannot. Additive-only evolution is therefore expressible in the data rather than promised in prose.

### 5. Both encodings; the term is canonical

JSON is a **published encoding of the term**, not a rival form. OTP 28.5 ships `json` in stdlib but
it refuses tuples — `{unsupported_type,{neg_inf,-1}}` [L5] — and tuples are what these diagnostics
are made of, so an encoding needs a defined mapping.

**It reuses ticket 16 §4's language-published serialisation mapping.** Inventing a diagnostics-only
JSON spelling would leave beam-sharp with two renderings of `(:ok, 5)`: one for programs, one for
the compiler that compiles them. This takes a dependency on a mapping that is **owed and not yet
written** (it sits in the map's *Not yet specified*), and inherits whatever it decides.

### 6. `error_info` on compiler-generated code only

Boundary guards, `ValidateAs<T>` and `string`'s UTF-8 entry check attach a structured `cause`; the
retained failure arm over user-written clauses does not.

The line is **where the reader has no source to consult** — which is ticket 11's counterweight,
recorded on this ticket and now answered: `ParseAtom<T>` and `ValidateAs<T>` are bodies nobody
writes and no reviewer reads, so when one fails the cause map is the whole story. Over user clauses
the frame ticket 12 measured already names the offending value with file and line, and 12 fought to
keep that arm at a constant ~15 bytes; a cause map at every site would grow it, plausibly in
proportion to the type rather than constantly.

**Cost, and it is an unusual one for this map: it lands in emitted code, not in the compiler.** The
standing constraint's "write-cost objections carry little weight" does not apply — this is runtime
size in every shipped module. The skeleton owes the number (see the debt recorded in the map).

### 7. A stub is legal, with an explicit marker

A signature with no clauses is **not** a hard error. Under agent authorship the compiler is an
interlocutor as well as a gate: a stub's residual is the *entire declared parameter type*, which is
the most informative diagnostic the language can produce, and refusing to compile withholds it
exactly when it is most useful. Forcing the agent to write something plausible first is the worst
possible input to a feedback loop.

`no_clauses` therefore stops being a special case — it is the ordinary inexhaustive diagnostic at
its maximum — and ticket 12 already settled what such a function does when called: a body of
nothing but the retained failure arm.

The marker makes the incompleteness **a fact in the file**, so the release gate is a text search
rather than a diagnostic-parsing job. **How it is spelled** — attribute, keyword or convention —
is deliberately not decided here; it is ticket 22's question and 22 is deferred. Recorded as fog.

### 8. A named stub type in the payload, and the compiler emits the corrected signature

Ticket 14 settled that callback signatures **narrow** and the compiler checks containment; it left
the generated default here, noting the wide default makes an evasive `(:noreply, s)` always
type-correct. Narrow has **two axes** and 14's argument covers one: the generator can get the
*action* union right, because the behaviour determines it, and cannot know the *payload*, because
it writes the file before any clause exists.

The payload position gets a **named stub type**, not `term`. A `term` return decays invisibly — it
type-checks forever and review sees a plausible signature; a named stub decays loudly and is
greppable.

And **when a clause returns outside its signature, the diagnostic carries the corrected signature
to paste**. This is §2 applied to signatures and needs no new machinery — it is another contractual
descriptor under §4's test. The risk is named and accepted: it makes widening frictionless, which
is a virtue only if widening is meant to be *deliberate* rather than *rare*. It is bounded by what
the clauses actually do, never by OTP's six-way union, so the drift ceiling is the honest signature.

### 9. The generator smuggles in no crash policy

The body of a mandatory boundary clause is the author's decision, per boundary.

Read literally, ticket 12's rule — *write the honest value your return type admits, `raise` only
where it admits none* — would make the generated default `raise`, because §8's stub type admits
nothing. **That is an artefact of ordering, not a decision**, and defaulting to `raise` is how a
crash policy disappears quietly, which is the failure 12 exists to prevent. A defaulted `raise` is
also indistinguishable at review time from a deliberate one, which is precisely the case where 12's
reasoning applies.

The compiler proposing a value was refused on §2's line: choosing `:unhandled` over `:bad_request`
is inventing semantics.

### 10. A compiler query mode answers what operations exist

`bsc --api <Module>` reads source and answers on this channel, in beam-sharp's vocabulary, with no
build. The directory listing (one function per file) and the built artefact
(`module_info(exports)` plus the `-spec` from the chunk [L4]) both remain true for free, but the
first gives names without types and the second requires a build and answers in Erlang.

**Scope clarification, and it is general (David, 2026-08-13):** *"Tooling is not out of scope if
there's a genuine need."* The map's out-of-scope entry rules out the **ecosystem track** — package
manager, build tool, LSP, formatter, docs generation — not any capability that happens to serve
tooling. Later tickets should read that boundary the same way.

### 11. Blast radius is complete within the compilation unit

A compile error names every file in the module that must change, and **says that is what it means**.

The line falls on the compilation unit for a structural reason: ticket 13 made the directory the
BEAM module, so the compiler has every file of the unit in front of it and completeness is free.
Beyond it, a cross-module dependency graph is the build tool's, which *is* on the out-of-scope
list — so promising completeness there would either drag build tooling into the spec or promise
what the compiler cannot keep. Best-effort was refused because an agent cannot distinguish "no more
files" from "did not look", which makes a derived task list worthless.

The ticket's other blast-radius question — should anything **forbid** an edit in one file changing
another's meaning — does not survive contact: type declarations are shared by construction, so
forbidding it means restating types per file or having no shared types. Making the dependency
*explicit* is real, and it is the map's **imports and cross-module scope** fog, not this ticket's.

### 12. What must not be optimised for agents

Restating the ticket's own rule, and then applying it to this ticket's output:

- **Read and review cost keeps full weight.** `(0)` and `()` at nullary and unary arity, and
  `Order.Server.Apply` colliding with `Order.Apply`, remain defects. Agent authorship does not
  excuse them — and §10 makes filenames more load-bearing, not less.
- **Verbosity is not a virtue.** That a generator can emit anything is not a reason to require
  more of it.

**Applied here, this rule changed an answer.** §7, §8 and §9 each introduced a marker, so a
scaffolded operation would have arrived three-quarters placeholder — cheap to generate, and exactly
what the rule warns against. Instead: **the debt lives on the channel, not in the source.** The
generator emits only what it *knows*; the compiler enumerates the holes, because an unwritten clause
and a missing boundary clause are both residuals it can compute exactly. The decisions of §7 and §9
stand — the author still chooses, the gate still refuses a marker — only their spelling moves.

**The rule is one marker per _declaration_, not one per hole.** The distinction matters and the
first draft of this answer got it wrong: dropping to literally one marker per *function* would
leave §8's stub type undeclared, and a signature naming a type that does not exist is not a
deferred decision, it is a broken file. So:

```csharp
[incomplete]                                  // the function: holes enumerated by the compiler
(:ok, ApplyReply) Apply(Order o, Command c);

type ApplyReply = [incomplete];               // a separate declaration, so its own marker
```

Two markers, not three and not one. What collapses into the function's single marker is everything
*internal* to it — the missing clauses and the undecided boundary body — because those are residuals
the compiler computes rather than facts only the author knows. What keeps its own marker is anything
that must **resolve as a name**, because an unresolvable name is an error rather than a deferral.

That is the fourth section deciding a design question rather than decorating one: cost moved off
the human reviewer and onto the channel whose primary consumer is a program.

### What this ticket owes

- **A measurement**, recorded in the map: the code-size cost of §6's `cause` map on generated
  checks at showcase clause counts, stacked on ticket 12's failure arm.
- **A dependency**: §5's JSON encoding inherits ticket 16 §4's serialisation mapping, which is owed
  and unwritten.
- **A question to [ticket 22](22-how-opinionated.md)**: how §7's marker is spelled — attribute,
  keyword or convention is 22's subject exactly. Recorded on that ticket rather than in the map's
  fog, since it belongs to a live (if deferred) ticket. Three properties are fixed regardless of
  spelling: it is a fact in the file, it is one per declaration, and CI refuses it.
- **A question to the map's _imports and cross-module scope_ fog**: §11 declined to decide whether
  anything should *forbid* an edit in one file changing another's meaning, because making the
  dependency explicit is that patch's business.
