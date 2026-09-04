# 24 — The testing story

Type: grilling
Status: resolved 2026-08-13
Blocked by: 11

## Question

The map has charted twenty-three tickets without one about **how a beam-sharp program is tested**.
That is a hole, and it matters more here than in most language designs for two reasons: the
standing constraint says code is written by agents and read by humans, so tests are the main thing
a human actually verifies; and the exhaustiveness guarantee changes *what is worth testing*.

Decide:

### What is the unit, given one function per file?

One function per file invites one test file per function — which is **implementation testing**,
and is the thing to avoid: a test that would break under a behaviour-preserving refactor is
testing the wrong thing. Boundary tests survive refactors, which is what makes confident
refactoring possible at all.

So: **what is the boundary in a beam-sharp application?** Candidates, and they are not exclusive:

- the **aggregate module** (the directory) — its exported operations, with internal helpers
  untested directly;
- the **process API** — `StartLink`, `Apply`, `Fetch`, exercised through a running `gen_server`;
- the **application** — through whatever port an adapter exposes (→ ticket 22).

State which is the default, and what would justify unit-testing an individual operation file
(a genuinely complex algorithm whose edges cannot be reached from the boundary).

### What does exhaustiveness make unnecessary?

If the compiler proves the clauses cover the declared input, a test asserting "unknown event is
rejected" is testing the compiler, not the code. The spec should say plainly which test
categories the type system retires, because otherwise every codebase writes them out of habit and
the guarantee buys nothing.

Conversely: name what it does **not** retire — clause *ordering*, guard conditions the checker
cannot translate into type operations, and everything behind a `dynamic` boundary.

### Type-directed generators — the payoff to check for

Ticket 04 established that CDuce prints a **sampled counter-value** from a residual type. That
machinery is a *value generator*: given a type, produce an inhabitant.

Property-based testing is well established on the BEAM (PropEr, StreamData). If types can generate
values, then property test inputs come from the type declarations for free — no hand-written
generators, and they stay in sync with the types by construction. Establish whether the sampling
in ticket 04's algorithms is good enough to serve as a real generator (uniform enough? able to hit
edge cases? terminating on recursive types?), or whether it only produces one witness.

This may be the strongest practical argument for the type system beyond exhaustiveness, and
nobody has checked it. Consider splitting it into a research ticket.

### Testing across the process boundary

- How are OTP callbacks tested — through `gen_server` or by calling `HandleCall/3` directly? The
  second is implementation testing but is what almost everyone does.
- What does the language or its tooling provide for deterministic tests of concurrent code?
- Does the test framework live in-language, or does beam-sharp use an existing Erlang/Elixir one?
  Note that **test tooling was ruled out of scope** on the map ("tooling and ecosystem"), so this
  ticket must decide only the *language-level* question — what the language must expose for
  testing to be possible — and hand the rest to that later effort.

### Under agent authorship

If an agent writes both the code and the tests, a test that merely restates the implementation is
worse than useless — it locks in whatever the agent did. Boundary tests written against the
*specification* are the only ones that can catch an agent's misreading. Whether the language or
its conventions can enforce that distinction is an open question, and probably a convention rather
than a language matter (→ ticket 22).

## A testing trap from ticket 10 — resolved 2026-08-12

**A test written with literal strings cannot measure atom-minting behaviour**, because `erlc`
constant-folds `binary_to_atom/1` on a literal binary: the atom lands in the atom chunk and is
interned at module load, before the code under test runs. The "not yet interned" state is
unobservable, so the test passes while measuring nothing. Any such test must build the string
at runtime ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl)).

The general shape is worth more than the instance: **compile-time evaluation can make a test's
precondition unreachable**, and the test still goes green. This bit twice while producing ticket
10's evidence — once via constant folding, once via the probe mentioning its own atom in value
position, which interned it. Both times the failure mode was a *passing* test.

That argues this ticket should decide something about **tests whose preconditions the compiler
can erase** — whether the language or its test tooling can detect them, or whether it is purely
a discipline. It bears directly on the standing constraint: an agent writing tests in a loop
will not notice a green test that measures nothing.

## Notes

HITL. Raised 2026-08-12 after the observation that test support had never been charted. Blocked by
11 because what the type system computes determines both what testing is retired and whether
type-directed generation is available.

## Constraints from ticket 11 — resolved 2026-08-12

- **The guarantee bounds what tests are still for.** *"Every case your types admit has a clause —
  and everything from outside is a `term` until you match it."* Exhaustiveness is proved, so
  case-coverage tests are largely redundant; **provenance is not checked at all**, so the tests
  that still earn their place are the ones exercising foreign callers and boundary terms.
- **`ValidateAs<T>` failure paths are testable surface**: it returns `T | :error`, and the
  `:error` branch is ordinary code that a test can reach without a foreign process.
- **A foreign fun cannot be called**, so no test needs to fake one — but a test may need to check
  that a fun is correctly *held and returned* to Erlang unchanged.

## Constraints from ticket 14 — resolved 2026-08-12

- **Draining a mailbox and selectively receiving are different operations.** Ticket 14 §5 makes
  `receive` a **filter**: unmatched messages stay in the mailbox by design, so no catch-all is
  forced and no exhaustiveness applies. A test helper that "waits for a message" therefore has two
  meanings, and picking the wrong one leaves messages behind that the next assertion then sees.
  Gleam demonstrates the confusion this causes when it is left implicit — it ships both behaviours
  at two layers and names neither ([`14f`](../prototypes/14f_gleam_selective_receive.md)).
- **Test doubles are bare pids.** Ticket 14 §1 declined `Pid[τ]`, so a fake server is any process,
  and nothing in the type system distinguishes it from the real one. What *does* distinguish them
  is the client API function's signature, which is where the message type lives — so testing at
  the boundary means calling the client API, not sending tuples at a pid.
- **Four of five wrong-recipient failures are exits, not values**
  ([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)), so tests for the unhappy path at the OTP
  boundary assert on process exits and exit reasons rather than on returned error values.
- **The blind spot is a test-shaped problem.** A mis-shaped system-message clause never fires and
  the catch-all absorbs it silently ([`14g`](../prototypes/14g_handle_info_blind_spot.erl)).
  Ticket 14 §6 closes it in the compiler, but it is worth asking here whether the testing story
  should make "the catch-all ran" observable, since that is the signal a silent absorption
  produces.

## Constraints from ticket 27 — resolved 2026-08-12

**Type-directed generation now has a boundary it did not have.**

This ticket noted that type-directed generation is available. 27 §8 puts a hard limit on it:
**a codegen obligation requires a ground type argument.** `ValidateAs<T>` and `ParseAtom<T>` are
generated, monomorphic at every use, and `ValidateAs<TSource>` inside a polymorphic function is
rejected at compile time — you cannot generate a structural check for a type nobody has chosen yet.

If generated test data or generated property tests follow the same mechanism, **they inherit the
same limit**: there is nothing to generate for a bare type variable. The open question this ticket
now owns is whether generation for a polymorphic function means (a) generating at a chosen set of
ground instantiations, (b) generating only for the ground parts of a signature, or (c) something
that does not exist yet.

**A second, sharper consequence.** 27 §2 makes type variables opaque, which means a polymorphic
function's behaviour **cannot depend on the type it was instantiated at** — that is exactly what
the restriction buys. So testing a polymorphic function at *one* ground instantiation is, for the
first time in this language, defensible as evidence about all of them. That is a real reduction in
test surface and it follows from a type-system decision, which is the kind of thing this ticket
should be looking for.

**Also**: 27 §6 measured that emitted polymorphic `-spec`s are not enforced by Dialyzer. If any part
of the testing story leans on Dialyzer over emitted output, it does not cover polymorphic
functions.

## Constraints from ticket 15 — resolved 2026-08-12

**One test category retired, one created.**

*Retired*: a test asserting that a function's failure channel is reachable. Ticket 15 §1 makes an
absorbed failure member a **declaration error**, so `option<atom>` does not compile. A test that the
error case is distinguishable from the success case is testing the compiler.

*Created*: `option<T>` is now the first **partial** prelude type — legal for most `T`, rejected for
some. That is exactly the kind of rule that gets rediscovered painfully at an instantiation three
modules away, and it is worth an exemplar exercising it at the boundary rather than a unit test of
the checker.

Also relevant to this ticket's boundary question: ticket 15 measured that `monitor` + `receive`
converts a callee crash into a value with a **better reason** than `try` does
([`15c`](../prototypes/15c_surviving_a_callee_crash.erl)). Testing a client API's failure path
therefore means killing a real process, not stubbing an exception — which pushes the default test
boundary further toward the process API and away from the individual operation.

## Answer — 2026-08-13

Decision brief: <https://claude.ai/code/artifact/0c88956f-8591-4190-8e3f-455f9700ad64>

**The headline: exhaustiveness does not reduce the number of tests, and the map's own framing
assumed it would.** Three test categories genuinely retire, and the ticket found them. What it did
not anticipate is that ticket 23's clause synthesis *adds* code needing value tests at the same
time — the compiler hands an agent a head it cannot get wrong and the agent fills a body that is a
guess, so the pre-scaffolded guess is precisely the untested thing. Exhaustiveness converts coverage
tests into value tests. It does not delete them.

**And the ticket's single strongest hope was resting on a misreading.** §3 asked whether CDuce's
sampled counter-value is good enough to be a property-test generator, on ticket 04's report that it
"prints a sampled counter-value". Measured at last ([`24a`](../prototypes/24a_cduce_sampling.sh),
CDuce 0.6.0): **it prints a *type*, never a value** — `51--100` and not `51`, `[ Int ]` and not
`[7]` — and `--help` carries no flag that asks for an inhabitant. There is no inherited generator.
Nobody shipped one.

### 1. The unit is the client API, exercised against a running process

Ticket 13 made the directory the BEAM module, so *"test the exported surface"* does not
discriminate: the client API and the OTP callbacks are exported from the same `.beam`, the latter
because OTP requires it. The default boundary is the **client API function** — `StartLink`, `Apply`,
`Fetch` — driven against a live process. `HandleCall/3` and its siblings are not a test target.

Three beam-sharp facts push harder here than the general heuristic does. The callback is the
**most compiler-owned function in the language** — 14 §4 checks its signature against the
`GenServer` contract, 04 proves its clauses exhaustive against the declared request type, 23
synthesises its missing heads, 18 §3 writes code into `code_change/3` — so a direct callback test
asserting "an unknown request is rejected" is testing the compiler. Hand-building a state to pass it
constructs an aggregate no production path ever constructed. And moving a guard from `HandleCall`
up into `Apply` is behaviour-preserving, which only the client-API test survives.

The cost is real and measured on the other side: ticket 15 found that reaching a crash path through
the process means killing a real process and reading a monitor's exit reason. That is heavier than
calling a function, and it is why almost everyone tests the callback directly. Paid anyway.

**Carve-out**: unchanged from the team's own rule — a genuinely complex operation whose edge the
client API cannot reach, and only that edge.

### 2. The boundary is published, and the behaviour contract is the discriminator

§1 is a phrase, not something the compiler knows. Visibility is undecided and belongs to
[ticket 22](22-how-opinionated.md), which is deferred, so **every function in an aggregate is
exported today** and `ls orders/` returns `Apply.bs`, `Fetch.bs`, `HandleCall.bs`,
`RecomputeTotal.bs` undifferentiated — a listing 23 §10 deliberately made part of the API surface.

It does not need visibility. Ticket 14 §4 already has the compiler know the `GenServer` contract as
a type, so **the contract names every callback and the remainder is the client API**:

```
boundary:    Apply/2, Fetch/1, StartLink/1
callbacks:   GenServer — HandleCall/3, Init/1, HandleInfo/2, CodeChange/3
unclassified: RecomputeTotal/1
```

`RecomputeTotal` is why this is a decision rather than a derivation: it is neither, the compiler has
nothing to say about it, and **an agent writing tests in a loop will target it because it is the
easiest thing in the directory to test.** It stays `unclassified` and goes to ticket 22 unresolved —
inventing a visibility rule here would answer 22's question from the wrong ticket.

### 3. Exhaustiveness retires coverage tests; the count does not fall

**Retired, and the spec says so plainly** so that codebases stop writing them:

- *"an unknown event is rejected"* — 04 proves clause coverage against the declared request type.
- *"the error case is distinguishable from success"* — 15 §1 makes an absorbed failure member a
  declaration error, so `option<atom>` does not compile.
- *per-instantiation tests of a polymorphic function* — 27 §2 makes type variables opaque, so
  behaviour cannot depend on instantiation and **one ground instantiation is evidence about all of
  them.** This is the first real reduction in test surface the map has produced from a type
  decision, and it is the one most likely to be missed.
- *coverage of compiler-generated code* — 16's encoder, 20's opaque refinements, 18 §3's
  `code_change` validation. A test asserting a generated encoder round-trips is testing the
  compiler. The **contract** it enforces is still the user's, tested at the boundary.

**Not retired.** Clause *ordering* among overlapping clauses that are each reachable — 23's
`unreachable_clause` catches the dead one and nothing catches two live ones in the wrong sequence.
Guards the checker cannot credit, which the skeleton's own soundness bug was: an uncreditable guard
now contributes nothing to coverage (`Certain` and `Possible` are separate bounds), so its logic is
untested by construction. And everything foreign, since 11 checks shape and 18's guarantee is only
*"will crash, never silently"* — whether supervision handles that crash is behaviour.

**The spec must state that the test count does not fall.** Claiming the reduction is the flattering
reading and it is false; worse, a codebase that believes it skips the value tests the compiler never
had.

### 4. No inherited generator; the language publishes the residual instead

[`24a`](../prototypes/24a_cduce_sampling.sh), CDuce 0.6.0, `local`:

| Declared | Handled | CDuce's "sample" |
|---|---|---|
| `` `red \| `green \| `blue `` | two | `` `blue `` |
| five atoms | two | `` `blue \| `cyan \| `magenta `` |
| `1--100` | `1--50` | `51--100` |
| `1--100` | `1--39 \| 61--100` | `40--60` |
| `Int` | `0--10000` | `*--1 \| 10001--*` |
| `[ Int* ]` | `[]` | `[ Int ]` |
| `Tree` | leaf only | ``(`node,(X1,X1)) where X1 = (`leaf,Int)`` |
| `(S,E)` 3×3 | one pair | ``(`void \| `closed, E)`` |

**Retracts a ticket 04 claim.** Every one is a type. CDuce's error reporter is proving
non-subtyping, and a type is all that needs.

Two findings worth more than the retraction. The recursive case **terminates by emitting a binder**
rather than unrolling to a depth — which makes ticket 09's contractivity requirement, adopted for
subtyping decidability, also the property that would make a generator terminate. And the product
case is **partial**: `(S,E) \ (`open,`add)` is `` (`closed|`void,E) | (`open,`remove|`ship) `` and
CDuce printed one rectangle. beam-sharp's checker computes the full residual (04's algebra, the
skeleton's `Certain`/`Possible`), so this is a shortcut it does not inherit.

So the language **publishes the residual as a structured term and generates nothing.** Value
generation is a library, out of scope on the tooling track, consuming a guarantee that is in scope.
27 §8 bounds it before it is built — a codegen obligation requires a ground type argument — which
settles §3's own open (a)/(b)/(c): generation happens at ground instantiations or not at all.

CDuce formats its residual into a string at exactly the point a consumer wants it, which is the
failure 23 measured in `erlc` and refused. beam-sharp's residual is a term by decision.

### 5. Every asynchronous operation owes a synchronous observation

§1 makes every test concurrent, which makes determinism the language's problem. Measured,
[`24b`](../prototypes/24b_cast_observability.erl), OTP 28.5, 200 reps:

| Shape | Observed |
|---|---|
| same process: `cast` then client-API `call` | 200/200 |
| same process: `cast` then `sys:get_state/1` | 200/200 |
| different processes, genuine race, caller released first | 200/200 |
| **positive control**, caller given a 20 ms head start | **0/200** |

**`sys:get_state/1` buys no determinism at all** — identical to a client-API call, because both are
messages riding the same pairwise ordering guarantee. Its only purchase is state the client API does
not expose, which is the implementation test through the back door and the read half of the channel
18 §3 named a limit. **A test that reaches for it is a defect, and not even a useful one.**

**The trap is the third row.** A cast sent from a process other than the observer passed 200/200 on
scheduling bias alone — `gen_server:call` sets up its monitor before sending and hands the caster a
head start. Twenty milliseconds flips it to 0/200. That is a test that passes two hundred times
locally and fails in CI, and nothing in the type system can see it.

So the rule is a constraint on the **client API**, not on a test framework: *every asynchronous
operation must have a synchronous observation in the same client API, or it cannot be tested at the
boundary §1 chose.* The manifest advises where one is missing — **advisory, not an error**, because
a genuinely fire-and-forget aggregate (a logger, a metrics sink) has no natural observation and
would otherwise be nagged forever.

### 6. The compiler publishes its elisions — one boundary manifest

Ticket 10 found `erlc` constant-folds `binary_to_atom` on a literal, making a test's precondition
unreachable and the test green while measuring nothing. **beam-sharp has at least three of its own,
and unlike Erlang's they are enumerable by decision**: 20 §4 makes a literal a `string` by
construction so its UTF-8 entry check is elided; 18 §1 emits a boundary guard only where the body
would not object; 17 §2 inlines compiler-known prelude operations, so what runs is not what was
called.

The compiler knows exactly which it did — 18 §4 made the analysis function-local so the guard count
is predictable per function, and said the corpus can *count* emitted guards rather than estimate
them. Throwing that away is `erlc`'s failure again.

**§2, §5 and this consolidate into one artefact, the boundary manifest** — what the boundary is,
what it promises, and what the compiler decided not to check. Named as one thing deliberately: 18 §5
weighed a build artefact and noted it must be defined, versioned and kept stable, and that cost is
paid once here rather than three times. It is the first capability in the map serving testing alone,
and it clears the scope bar on the 2026-08-13 clarification — one capability the language owes its
author, not the ecosystem track.

### 7. Tests are ordinary beam-sharp, with no exemption

Exhaustiveness applies to a test. The universal BEAM idiom is a partial destructuring bind whose
crash *is* the assertion; in beam-sharp `Fetch` returns `Order | (:error, atom)` per 15's untagged
shape, the residual `(:error, atom)` is open because `atom` is cofinite, and 12 therefore permits a
catch-all. **The idiom survives, but the failure arm must be written:**

```csharp
switch Fetch(pid) {
    Order o => Assert(o.Total == 100),
    _       => Fail("expected an order, got an error")
}
```

Near-free to write under the standing constraint, and it earns its place on the read side, which
carries full weight: the arm forces the test to state what it expected. **The cost is paid where it
hurts most** — 12 measured that the compiler's *emitted* failure arm gives `function_clause` with
the offending argument, a good crash report for free, and this idiom opts out of it at exactly the
moment a test wants it. A hand-written `Fail` is only as good as what the agent typed.

A `test` construct exempting partial matches was refused on 12's own grounds: it is a second
semantics for the headline guarantee, and 12 already rejected a uniform `_` for putting that
guarantee one character from being switched off invisibly.

### 8. `handle_info` is boundary-testable, by causing the event

Ticket 14 §6 asked whether the testing story should make *"the catch-all ran"* observable, since a
mis-shaped `handle_info` clause never fires and the mandatory catch-all absorbs it in silence.

**No, and the reason is §1.** Nothing in the client API produces a `handle_info` message, so the
apparent conclusion is that this path is unreachable from the boundary. It is not: a monitor fires
because a monitored process died, and a test can kill it. **Cause the real event and assert the
effect** — if the clause is mis-shaped the effect does not happen and the test fails. Sending a
fabricated message at the pid is the implementation test, the exact analogue of calling `HandleCall`
directly, and it is what would make the blind spot invisible.

Consistent with the same section's other measured facts: four of five wrong-recipient failures are
exits ([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)), so boundary tests of the unhappy path
assert on **exits and exit reasons**, and 15 measured `monitor`+`receive` yields a better reason
than `try`.

### Out of scope

- **Test runner and framework.** Already the map's tooling track. The language-level part is
  answered: 13 emits ordinary BEAM modules with specs, so any BEAM runner works and beam-sharp needs
  no runner of its own.
- **A mailbox-drain helper.** Ticket 14's finding that *"wait for a message"* has two meanings —
  drain versus selectively receive, which Gleam ships at two layers and names at neither
  ([`14f`](../prototypes/14f_gleam_selective_receive.md)) — is real, but a `Drain` is a prelude
  function and that is standard-library breadth. Under §1 a test rarely does a raw `receive` at all;
  where it does, 14 §5's filter semantics already govern it.

### What this ticket owes

- **The boundary manifest's concrete format** — a spec-drafting detail, but a versioned one, and it
  now has three consumers.
- **A question to [ticket 22](22-how-opinionated.md)**: `unclassified` functions. §2 works without
  visibility and stops there; what a helper *is* remains 22's.
- **A question to the map's _module and namespace system_ fog**: test file layout under one function
  per file. 23 §10 made file names part of the API surface, so where a test lives is that patch's
  business, not a tooling detail.
- **A measurement for the skeleton**: nothing new. §5's determinism rests on the BEAM's pairwise
  ordering guarantee, which is the platform's and not beam-sharp's to prove.

### Evidence

| Source | Claim | Provenance |
|---|---|---|
| [`24a_cduce_sampling.sh`](../prototypes/24a_cduce_sampling.sh) | CDuce's inexhaustive-match "sample" is a type, never a value; recursive types terminate via a `where` binder; product residuals are partial; no CLI flag requests an inhabitant | `local`, CDuce 0.6.0 |
| [`24b_cast_observability.erl`](../prototypes/24b_cast_observability.erl) | cast-then-call from the same process observes 200/200; `sys:get_state/1` identical, no better; cross-process cast passes 200/200 on scheduling bias and 0/200 with a 20 ms head start | `local`, OTP 28.5 |

*Method note kept because it repeats this ticket's own subject: the first version of 24b's
cross-process probe had the caster signal the observer before it called, creating a happens-before
chain. It reported 200/200 like every other row and could not have recorded a miss if one existed —
the §"testing trap" reproduced while measuring it. The positive control was added for that reason
and is the only row proving the harness works.*

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [The testing story](issues/24-testing-story.md) — **exhaustiveness converts coverage tests into
  value tests; it does not reduce their number**, because 23's clause synthesis adds guessed bodies
  at the same rate it removes coverage questions. Four categories genuinely retire, and 27 §2's is
  the one to notice: opaque type variables make **one ground instantiation evidence about all of
  them**. The unit is the **client API against a running process** — the OTP callback is the most
  compiler-owned function in the language, so testing it directly tests the compiler — and the
  boundary is **published by `bsc --api` with the behaviour contract as discriminator**, needing no
  visibility feature and so not waiting on 22. **Ticket 04's "sampled counter-value" is retracted**:
  measured, every CDuce sample is a *type*, never an inhabitant, so no generator is inherited and
  the language publishes the residual instead — 09's contractivity turns out to be what would make
  one terminate. Measured too: `sys:get_state` buys **no** determinism a client-API call does not,
  and a cross-process cast passes 200/200 on scheduling bias, flipping to 0/200 with a 20 ms head
  start — hence *every async operation owes a synchronous observation in the same client API*.
  §2, §5 and the compiler's published **elisions** consolidate into one **boundary manifest**.
  Tests are ordinary beam-sharp, no exemption. Closes 14's catch-all question with a **no**: cause
  the real event and the boundary test catches a mis-shaped clause.
```
