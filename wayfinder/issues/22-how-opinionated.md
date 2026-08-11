# 22 — How opinionated is the language? Grammar, attributes, or convention

Type: grilling
Status: open
Blocked by: 21

## Question

beam-sharp wants to support a DDD style for rapid business-application development, with ports
and adapters out to everything else. **How much of that opinion goes in the language?**

Three places an opinion can live, and the decision is which conventions go where:

1. **In the grammar** — keywords like `aggregate`, `command`, `query`. Maximum enforcement,
   permanent, and every user of the language inherits the architecture.
2. **In attributes** — `[Aggregate]`, `[Command]`, `[Port]`. Opt-in, compiler-visible, removable.
   The mechanism already exists in the prototype for `[Erlang("lists", "reverse")]`, and it is
   what C# itself uses to let ASP.NET and EF layer strong opinions onto a neutral language.
3. **In convention and tooling** — directory names, linting, generators, documentation. Fully
   reversible, project-configurable, unenforceable by the compiler.

### The arguments already on the table

**For baking it in.** The compiler can enforce invariants a general language can only document —
an aggregate may not reach into another aggregate's internals; a command must return the
aggregate; a query may not mutate. Every codebase looks the same, so onboarding collapses, and a
constrained shape is markedly easier for LLM-assisted development to generate correctly. Errors
can speak the domain rather than the type system.

**Against.** The opinion is permanent — you can add to a grammar, never remove from one without
breaking somebody, and Elm 0.19's removal of native modules is the case study (→ ticket 21). Not
every BEAM program is a business app; a gateway, a protocol parser, a game server all fight a DDD
grammar. That matters more here than usual because [ticket 03](03-prior-art-static-multiclause.md)
found BEAM languages die of **no users and no ecosystem**, and narrowing the addressable set is
precisely that failure mode. And architecture is fashion on a far shorter cycle than a language —
Phoenix's contexts changed more than once while Elixir's `defmodule` did not.

### The agent-authorship argument, which the original analysis missed

The map's standing constraint — **written by agents, read by humans** — adds an argument for
opinionation that a human-authorship analysis does not produce: **an enforced convention is a
guardrail on the agent.** A general, flexible language gives an agent more rope, and the
characteristic failure of agent-written code is plausible-looking structural drift — code that
compiles, reads acceptably, and quietly diverges from how the rest of the system is built.
Conventions the compiler enforces are exactly what prevents that.

Weigh this against the arguments above; it does not cancel them. Narrowing the addressable set
still risks the ecosystem failure mode ticket 03 identified, and a grammar still cannot be
retracted. But "conventions cost the author effort" is a much weaker objection when the author is
a program, and "conventions keep the author honest" is a much stronger benefit.

### The candidate synthesis

Split by kind rather than by strength:

- **Structural conventions in the grammar** — directory is the module, one function per file,
  signatures mandatory on multi-clause functions. These are architecture-neutral. Go bakes in
  exactly this kind and no domain opinion at all, which is why it serves web services and
  compilers equally.
- **Domain conventions as attributes** — enforceable where present, absent where irrelevant, and
  ownable by a framework that can change its mind.

Decide whether that split is right, and if so **exactly which conventions land on each side**.

### The sub-question that will not go away

**What does a port owe the guaranteed core?** If the core's invariants are enforced, an adapter
that hands it a badly-shaped value must not be able to break them silently — and ticket 06 found
that on the BEAM an untyped caller does *not* always crash, with silent unsoundness the worst of
three outcomes. Elm validates values crossing a port at runtime; Gleam and purerl do not validate
at all. This ticket and [ticket 18](18-boundary-defence.md) must agree, and 18 cannot be decided
without this one's answer about how much the core claims.

## Notes

HITL. Raised 2026-08-12 from ticket 01's design conversation. Blocked by 21 because the precedents
carry the failure modes, and this decision is close to irreversible.
