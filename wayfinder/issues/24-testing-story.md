# 24 — The testing story

Type: grilling
Status: open
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

## Notes

HITL. Raised 2026-08-12 after the observation that test support had never been charted. Blocked by
11 because what the type system computes determines both what testing is retired and whether
type-directed generation is available.
