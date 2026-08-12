# 16 — Ad-hoc polymorphism: what replaces interfaces and extension methods?

Type: grilling
Status: open
Blocked by: 09, 27

## Question

Ticket 05 dropped both of C#'s ad-hoc polymorphism mechanisms — **extension members** and
**static abstract interface members** — as load-bearing on OOP and the CLR, and flagged the
consequence explicitly: the language currently has **no ad-hoc polymorphism story at all**.

That is a hole, not a simplification. Without one there is no way to write a function that
works over "anything that can be compared", "anything that can be serialised", or "anything
with a length" — and every BEAM language has had to answer this somehow.

Decide the mechanism. Candidates, each with a real precedent:

- **Type classes** — PureScript/purerl and Haskell. Powerful, principled, needs dictionary
  passing at runtime and interacts non-trivially with set-theoretic subtyping.
- **Protocols** — Elixir's runtime dispatch on term shape. Idiomatic on the BEAM and cheap
  to implement, but dispatch is dynamic, which sits awkwardly against enforced exhaustiveness.
- **Structural dispatch** — since types are (probably) structural after ticket 09, dispatch
  on shape directly, with no nominal declaration at all. Fits the type system, but overloads
  the same mechanism the headline feature already uses.
- **Nothing** — no ad-hoc polymorphism; callers pass functions explicitly. Honest and small.
  Gleam largely takes this line. State the ergonomic cost if chosen.

Whatever is chosen must answer: how does it interact with **multi-clause head dispatch**,
which is already a dispatch mechanism? Two dispatch systems in one language need a clear
story about which fires when.

## The central constraint, from ticket 09 — resolved 2026-08-12

The "(probably)" in the structural-dispatch candidate above is now settled, and it is a harder
constraint than that bullet suggests.

**With no nominal identity anywhere in the language, dispatch cannot key on a name.** Ticket 09
made types structural and open, made naming pure aliasing, and left the language with *no*
nominal construct — so two names over the same set are the same type. That removes the thing
every dictionary-passing scheme resolves against:

- **Type classes are not simply "powerful but costly" here — their resolution key is gone.**
  PureScript, Haskell and Rust all select an instance by the *nominal head* of a type. With
  aliasing, `instance Show OrderId` and `instance Show CustomerId` are instances for the same
  type, and the language cannot tell which was meant. Adopting classes would require
  reintroducing nominal identity for exactly this purpose — which is a reversal of ticket 09,
  not an extension of it, and would need to answer ticket 09 §5's finding that nominal identity
  is unenforceable across the Erlang boundary.
- **Structural dispatch is the candidate that survives unchanged**, and it now has machinery
  waiting for it: ticket 09 §4 requires the compiler to synthesise a **BEAM guard expression**
  deciding membership for each member of a union, and rejects unions where it cannot. That
  synthesiser is a structural discriminator — the same thing structural dispatch needs.
- ~~**Elixir-style protocols sit between the two** and inherit the problem in a weaker form:
  protocol dispatch keys on term shape, which is structural, so it survives — but the
  *registration* step is nominal in Elixir and would need a structural replacement.~~
  **Wrong, corrected 2026-08-12 — see the next section. Nothing about Elixir's mechanism is
  nominal, and no replacement is needed.**
- **"Nothing" (explicit function passing) is unaffected**, and its cost is unchanged.

## Correction — Elixir's structs and protocols, verified

**Raised by David, 2026-08-12: "Elixir solves dispatch by using structs and protocols."**
Correct, and the bullet struck through above got the reason wrong. Verified locally on Elixir
1.19.5 / OTP 28 — [`prototypes/16a_elixir_protocol_dispatch.exs`](../prototypes/16a_elixir_protocol_dispatch.exs),
runnable:

| Observed | Result |
|---|---|
| What a struct is | `%{name: "d", __struct__: User, age: 1}` — a plain map carrying an **atom** |
| Two structs with identical field sets | Dispatch differently; the tag is the whole discriminator |
| How the impl is found | `Describe.impl_for(u)` → `Describe.User` — a module named from the tag |
| **Hand-built plain map with `__struct__: Admin`** | **Dispatches as an Admin; `is_struct/2` returns `true`** |

**There is no nominal type identity anywhere in this mechanism.** Elixir has no static types at
all. `defimpl ... for: User` names a module at compile time, but what dispatch *reads* is an atom
sitting in the term. **The name is data.** So this is not a counter-example to the constraint —
it is the worked demonstration of ticket 09 §5's remedy, at ecosystem scale, in map form rather
than tuple form.

### The constraint, restated precisely

Not *"dispatch cannot key on a name"* but: **dispatch cannot key on a name that is not in the
term.** Elixir's answer is to put the name in the term. beam-sharp can do exactly that, and
ticket 09 already commits it to the mechanism — a tag makes two otherwise-identical field sets
genuinely distinct *sets*.

What still does not work is unchanged: **type-class resolution keyed on a compile-time name with
no runtime witness.** `instance Show OrderId` where `type OrderId = string` has nothing in the
term to dispatch on, and `OrderId` and `CustomerId` are the same type. That option stays dead.

### What this makes newly available, and it is better than Elixir's version

The ticket body complains that protocol dispatch "is dynamic, which sits awkwardly against
enforced exhaustiveness". **Under ticket 09 that complaint mostly dissolves**, because the tag is
part of the *type*, not merely of the value:

- The compiler knows the tag **statically** from the declared type, so an impl can be **resolved
  at compile time** rather than by a runtime `impl_for` lookup.
- **Impl coverage becomes an exhaustiveness question the type system already answers** — the set
  of tags in a union is exactly the set of impls required, computed by the same subtraction
  ticket 04 specified. A missing impl is a residual, not a runtime `Protocol.UndefinedError`.
- Elixir needs **protocol consolidation** as a Mix build step precisely because it cannot know
  any of this statically. beam-sharp would get consolidation by construction.

**Consequence for framing this ticket**: "protocols" and "structural dispatch" are not two of the
four candidates — they are the same candidate, and the protocol version is what it looks like once
you give the dispatch table a name. The live question is narrower than the ticket's list suggests:
whether that mechanism earns a language construct, and how it relates to multi-clause head
dispatch, which keys on the same tags. **Still open; still HITL. This section sharpens the
options, it does not choose between them.**

### One caution carried forward

Result 4 above — the forged tag — is also **independent local evidence for ticket 09 §5's derived
claim** that the BEAM has no construction discipline. Even Elixir's nominal-*looking* dispatch is
defeated by a hand-built term. So whatever dispatch mechanism this ticket picks, it inherits
[ticket 18](18-boundary-defence.md)'s problem: a tag arriving from raw Erlang is an assertion, not
a guarantee.

The interaction question this ticket already asks — how the mechanism relates to multi-clause
head dispatch — gets sharper rather than easier: if dispatch keys on structure, then it and
clause-head matching are **the same kind of operation**, and the story about which fires when is
now mandatory rather than tidy-minded.

Related: the newtype gap ticket 09 §5 leaves open (`Meters` and `Feet` are one type; tag them
to distinguish) is the *same* gap in a different place. If ticket 20 answers it with refinement
types, that answer may also supply a dispatch key — worth checking before deciding here.

## Notes

HITL. Surfaced by ticket 05's inventory, which named the gap rather than papering over it.
Blocked by 09 (nominal vs structural changes what dispatch can even key on) and 11 (whether
the type system supports constraints).
