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
