# 52 — Dependency provenance: what does a `.bs` file say about what it needs?

Type: grilling
Status: open — [ENG-234](https://linear.app/davewil/issue/ENG-234)

Raised 2026-08-21 as the residual of [ticket 51](51-a-build-and-dependency-tool.md), which decided
beam-sharp builds no dependency tool and reads what rebar3 or mix already produced.

## Question

51 measured that `ERL_LIBS` alone reaches Req 0.7.3 with no compiler change. It also measured what
that leaves undone:

**Nothing in a `.bs` file records which dependencies it needs.**

`ERL_LIBS` is an environment variable. A module that opens with

```csharp
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

names the **module** and says nothing about the **application** `req`, its version, or the fact that
the program will not run without it. Compile it on a machine with a different `ERL_LIBS` and it
fails at the call site with `error:undef`, having promised nothing.

**Does the language record its dependencies, and if so where?**

## Why this is not the thing the scope boundary refuses

`scope.md` rules out a *package manager*, and 51 confirmed beam-sharp needs none: no resolution, no
locking, no fetching, no publishing. This is the other half — **what the source says about itself**,
which is a language question. The destination is a clean-room specification an agent fleet
implements without David in the room; a program whose dependencies exist only in the environment
that happened to build it **cannot be handed over**, and that is the argument, rather than
ergonomics.

## The candidate 51 captured

**The FFI declaration may already be the right home.** `using :'Elixir.Req' { … }` is the one place
the source already names a foreign thing, so extending it to carry the application costs no new
file and no new concept — something like

```csharp
[external: elixir, app: req] using :'Elixir.Req' { … }
```

keeping provenance in the language where the spec can see it, and out of tooling entirely. Ticket 32
already settled that *"a foreign function is declared, and the declaration carries both spellings"*
— this asks whether it should carry a third thing.

Open against it, and unmeasured:

- **A version, or only a name?** A name is checkable at compile time (is the application present?);
  a version constraint is resolution, which is the boundary's territory and should stay refused.
- **Per `using` block, or once per module?** Several `using` blocks may draw on one application, and
  repeating it is the kind of write-cost the standing constraint prices as near-free but the reader
  pays for.
- **What does the compiler DO with it?** Checking that the application is on the code path at
  compile time is one line and turns a run-time `error:undef` into a diagnostic. That may be the
  whole feature, and it would be the first thing `bsc` does with a dependency.

## Notes

**Do not re-open 51.** Whether beam-sharp builds a tool is decided: it does not. This asks only what
the source declares.

**Sequence it with [ticket 50](50-naming-a-foreign-struct.md)**, which asks how a foreign *struct* is
named. Both are questions about what an FFI declaration carries, and answering them apart risks two
extensions to the same construct designed by different sessions.
