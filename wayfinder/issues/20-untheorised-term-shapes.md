# 20 — What must the type system model that set-theoretic theory doesn't yet cover?

Type: grilling
Status: open
Blocked by: 11

## Question

Ticket 04 established that the exhaustiveness mechanism is solved and shipped — but it also
listed what the theory **has not addressed at all**. These are *untheorised*, not merely
unimplemented, and this language inherits every one of them:

- **Binaries and bitstrings.** There is no `<<>>` typing anywhere in either Elixir type-system
  paper. For a BEAM language this is not an edge case: binaries are the string type, the wire
  format, and a first-class pattern-matching construct with size and unit specifiers. A
  multi-clause head matching on binary patterns is *idiomatic Erlang* and the theory is silent.
- **Improper lists.** Zero mentions in the literature.
- **Recursive and parametric types together.** Elixir's own signature milestone is explicitly
  gated on implementing both efficiently — the roadmap language is that failing to would "make
  the type system unfeasible".
- **Row polymorphism** — relevant if maps are to be typed structurally with extensibility.
- **OTP behaviours** — the callback contract as a typed object.

Decide, for each: does this language model it, approximate it, or exclude it — and if
excluded, what does a programmer write instead?

**Binaries deserve the most attention**, because excluding them quietly makes the headline
feature unusable in the domain the BEAM is most used for. Establish what a binary pattern in a
clause head would have to mean type-theoretically before deciding, rather than assuming it
falls out.

[Ticket 25](25-exemplar-programs.md) sharpens this considerably: of six ordinary BEAM workloads,
**three are binary work** — dynamic web pages, WebSocket frames and event-queue payloads. The most
common things people build on this platform sit precisely where the theory is missing. That should
be weighed before the type system is settled, not after.

Also weigh a product risk named by Castagna himself as an open problem: **readable error
messages and type pretty-printing** — and note that under the map's standing constraint (written
by agents, read by humans) this is a *product* problem rather than a cosmetic one, since the
diagnostic is consumed by an agent in a loop. See [ticket 23](23-what-the-language-owes-an-agent.md). For a language whose entire pitch is "the compiler proves
your clauses cover the input", an unreadable proof failure is not a cosmetic defect — it is
the feature failing in the only place a user meets it.

## Added by ticket 09 — resolved 2026-08-12

**The newtype gap.** [Ticket 09](09-union-representation.md) made naming pure aliasing, so
`Meters` and `Feet` over `float` are **one type**, as are `OrderId` and `CustomerId` over
`string`. The compiler will not catch passing one where the other is meant. Ticket 09 named the
cost explicitly rather than hiding it, and left the remedy here.

Two answers, and this ticket should pick one or say both:

- **Tags** — `{ :meters, float }` and `{ :feet, float }` are genuinely distinct *sets*, so the
  distinction is bought with a tuple rather than with type identity. Free, idiomatic Erlang,
  works today, and needs no theory. Cost: it changes the term, so it is visible at the interop
  boundary and in every pattern that touches the value.
- **Refinement types** — a predicate narrowing a type without changing its representation. This
  is the answer that would *also* settle the DDD-invariant question ticket 22 parked here ("only
  aggregate boundary enforcement is checkable and non-vacuous; the rest needs refinement
  types"), and it may supply a dispatch key for [ticket 16](16-ad-hoc-polymorphism.md), which
  lost nominal resolution to the same decision. Three open questions converging on one mechanism
  is worth noticing before deciding it is out of reach.

**Recursive and parametric together is now half-committed.** The bullet above records that
Elixir's roadmap is gated on implementing both efficiently. Ticket 09 has committed this
language to **equirecursive types with coinductive subtyping and a contractiveness rule** — so
the recursive half is decided, and only the interaction with parametricity is still open here.

## Added by ticket 10 — resolved 2026-08-12

**Value provenance (taint): can the language express that a value arrived from outside, and
should it?**

Ticket 10 went looking for a rule that prevents exhausting the BEAM's atom table (bounded at
1,048,576 by default, ~10,449 gone at a bare boot, never garbage collected) and found that no
rule available to the type system does the job. The reason is sharp:

- **Minting from a literal is not a runtime operation.** `erlc` constant-folds
  `binary_to_atom/1` on a literal binary, so the atom lands in the atom chunk and interns at
  module load — indistinguishable from writing `:foo`
  ([`prototypes/10b_atom_interning.erl`](../prototypes/10b_atom_interning.erl)).
- **So the table can only ever be exhausted by a string built at runtime**, and only when that
  string derives from untrusted input. The operative property is the value's *provenance*, not
  its type.

**No BEAM language expresses this.** Gleam's own documentation states the rule as prose
precisely because it cannot be checked: *"Never convert **user input** into atoms as filling
the atom table will cause the virtual machine to crash!"* — note "user input", not "strings".
Ticket 10 §4 responded by keeping minting out of the prelude, which is containment by omission
rather than by checking, and leaves the underlying question here.

This sits alongside the other entries on this ticket as a capability set-theoretic types do not
supply. It is worth deciding explicitly rather than by default, because the answer is plausibly
**no** — ticket 21 found that opinionated languages control *who may be on the other side*
rather than *what the data is*, and a taint system is a large surface for one hazard that a
prelude omission already blunts. If the answer is no, say so and say what a programmer relies
on instead.

Note the boundary with **[ticket 18](18-boundary-defence.md)**: that ticket owns checks emitted
*where an external term becomes a typed value*. Provenance is a different claim — that the
property travels *with* the value afterwards — which is why it is filed here rather than there.

## Added by ticket 11 — resolved 2026-08-12

**Integer intervals and guard refinement — folded in here from ticket 11.** Ticket 11 was the
keystone and held six decisions; it kept the `dynamic` boundary, the subtyping relation and the
guarantee, and sent this debt here because it is the same *kind* of question as the rest of this
ticket: a capability the type language may or may not have.

The debt comes from ticket 01's prototype. **No function whose totality rests on a guard can be
proved total without it** — which is most arithmetic recursion. `Fib` is the worked case:
`Fib(int n) when n <= 1` and `Fib(int n)` are only exhaustive and only terminating if the type
system can see that the second clause receives `n > 1`. That needs two things ticket 11 did not
decide:

- **Integer interval types** — CDuce has them, so this is a paved path rather than an invention.
- **Guard refinement** — narrowing a parameter's type inside a clause by the guard that selected
  it. Note this is *narrowing by a predicate*, which is the same machinery the refinement-type
  option above would need, so it converges with the newtype gap rather than adding a fourth
  mechanism.

**What ticket 11 settled that bounds this**: patterns over a `term` are **O(1) guard-decidable
only**, and BEAM guards are the vocabulary. Guard refinement therefore has an obvious ceiling —
whatever a BEAM guard can decide is refinable, and nothing else is. Decide whether the *type
language* is allowed to be richer than that ceiling in positions that are not boundary patterns.

**Also from ticket 11**: the top type is spelled **`term`**, and there is **no `dynamic`** — so
none of the gaps on this ticket can be papered over by weakening a type. If binaries are not
modelled, a binary is a `term` and must be matched.

## Notes

HITL. Surfaced by ticket 04's gap analysis. Was blocked by 11, since what the type system *is*
determines what these questions even mean; ticket 11 closed 2026-08-12.

## Status after ticket 16 — 2026-08-12

**Nothing foreclosed.** [Ticket 16](16-ad-hoc-polymorphism.md) refused an ad-hoc polymorphism
construct, so it supplies **no dispatch key**. The newtype gap ticket 09 §5 left open (`Meters` and
`Feet` over `float` are one type) therefore keeps exactly the status it had: if this ticket answers
it with **refinement types**, that answer is still free to supply a discrimination key, and ticket
16 does not compete with it.

Row polymorphism remains ticket 27 §7's refusal, unchanged and not revisited here.

One thing ticket 16 *does* hand over: its §4 decree that the language publishes a serialisation
mapping presumes every modelled shape has one. **Binaries and bitstrings — this ticket's headline
gap — are exactly where that presumption is untested**, and ticket 25 notes three of six ordinary
BEAM workloads are binary work. Whatever this ticket decides about `<<>>` typing owes a line on
what those shapes encode to.
