# 62 — What B# looks like from the outside: the outbound ABI

Type: grilling
Status: open — [ENG-252](https://linear.app/davewil/issue/ENG-252)

> **Another offset, another data point for the no-formula rule.** 62 is ENG-252 — `+190`, which no
> previous ticket has used. Read the number, never compute it.

Raised 2026-08-25 by David, mid-session on [ticket 50](50-naming-a-foreign-struct.md): *"B# modules
called from elixir will presumably be FFI and require that translation same way erlang or gleam
do?"* — and then, on the first result: *"Do you think a `BSharp.Shop` i.e with BSharp hidden prefix
inside B# would help or not needed if lowers to `:Shop` anyway?"*

**Every measurement in this repo so far runs inbound** — B# consuming Elixir
([32](32-ffi-surface.md), [50](50-naming-a-foreign-struct.md),
[51](51-a-build-and-dependency-tool.md), 56). Nothing covered the other direction, and the map had
no patch for it.

## Question

**What contract does a B# module present to an Erlang, Elixir or Gleam caller, and how much of it is
deliberate?**

## What is already measured

[`62a`](../prototypes/62a_from_the_outside.sh), against the built compiler, OTP 28, Elixir, and
gleam 1.18.1.

**The reassuring half first: calling *into* B# needs no declaration at all.** Erlang and Elixir are
dynamic, so a B# module is an ordinary `.beam` with exports and there is nothing to declare. The FFI
burden sits entirely on the typed side, which means this is **not symmetric** with B# calling out —
the answer to David's opening question is *no, it is not FFI in that sense*. The three frictions
below are the part that is not reassuring.

### 1. Elixir cannot call a PascalCase export, and no module prefix fixes it

```
:Shop.New(1)                 -> SYNTAX_ERROR
:"BSharp.Shop".New(1)        -> SYNTAX_ERROR
:"Shop.Reports".Totals(1)    -> SYNTAX_ERROR
:"Elixir.Shop".New(1)        -> SYNTAX_ERROR
:"BSharp.Shop".new(1)        -> parses
apply(:Shop, :New, [1])      -> parses, and runs
```

Elixir's parser reads `.Capitalized` as an alias. **Not even Elixir's own prefix rescues it**, which
settles the prefix question directly: the blocker is the capitalised *function* name, and no module
naming scheme touches it.

The contrast is what makes it Elixir's problem rather than the BEAM's. **Erlang is unaffected** —
`'Shop':'New'(1)` works with ordinary syntax, because Erlang quotes atoms freely. **Gleam is
unaffected** — it names foreign functions as strings, and `@external(erlang, "Shop", "New")`
compiles. *(Measured as far as compiling the declaration; the call was not run.)*

### 2. A B# record arrives as a plain tagged map, not a struct

`apply(:Shop, :New, [7])` returns `%{Kind: :"Shop.Order", Id: 7, Total: 0}` — `is_struct?` **false**,
no `__struct__`. Elixir can match it as a map (measured, works), but `%Order{}` is unavailable and it
gets none of the struct machinery.

This is the exact mirror of ticket 50's inbound problem, and the two share one cause: **two tag
conventions that do not know about each other.**

### 3. The minted `Kind` tag is a required part of the ABI

| caller hands in | result |
|---|---|
| `%{Kind: :"Shop.Order", Id: 9, Total: 5}` | `:order` |
| `%{Kind: :"MyApp.Order", …}` | **`FunctionClauseError`** |
| an Elixir struct with identical fields | **`FunctionClauseError`** |

[Ticket 26](26-data-modelling.md) calls `Kind` *"the one key a construction may not name"* — inside
B#, because minting it is what guarantees aggregate identity. **Outside B#, every caller must name
it.** The tag is private and public at once, and every B# function taking a record has a
foreign-facing contract nobody has written down.

## What the module atom actually is, and why a prefix is not the answer

Measured from the emitted beams: `Shop`, `Shop.Reports`, `Shop.Collections.List` — the dotted path,
no language prefix. In context:

| | top-level | nested | language prefix |
|---|---|---|---|
| Erlang | `shop` | flat | no |
| Elixir | `Elixir.Shop` | `Elixir.Shop.Reports` | **yes** |
| Gleam | `caller` | `deep@nested` | no |
| **B#** | `Shop` | `Shop.Reports` | no |

**A `BSharp.` prefix is not needed and would not help**, on four counts:

- It fixes **nothing** measured above — §1 is the function name.
- Namespacing is **already in the atom**; B# emits the dotted path today.
- Collision risk is already near-zero: the three namespaces are disjoint *by shape* — Erlang
  lowercase, Elixir prefixed, B# PascalCase-dotted — and atoms are case-sensitive.
- Elixir needs its prefix because it has **alias resolution**: a bare capitalised token in source
  must become an atom, and `Elixir.` is that encoding. B# has no such indirection — `module Shop`
  *is* the atom, spelled identically. There is nothing to disambiguate.

And it would cost two real things. Erlang callers currently have the **working** path and would get
a longer one to fix nothing; and the minted tag would grow from `Shop.Order` to `BSharp.Shop.Order`
in every foreign caller's source, lengthening a de facto ABI string and leaking more implementation
detail.

**Gleam is the closer precedent and takes no prefix** — it encodes the path (`deep@nested`) and
stops. B# already does the same thing with `.` instead of `@`.

## The decision this ticket actually holds

**B#'s PascalCase function naming is the interop friction**, not the module naming. Three
candidates, none costed:

1. **Accept it.** Elixir callers use `apply/3`. Honest, and it makes B# awkward to adopt
   *incrementally inside an existing Elixir codebase* — which is the likeliest way anyone tries it.
2. **Emit snake_case aliases alongside**, so `:Shop.new(1)` works from Elixir while `New` still
   works from Erlang and B#. Costs two exports per function and a rule for deriving the name.
   **There is a precedent already in the map's own fog patch**, recorded by ticket 10 §7 long before
   this question was asked: Gleam **downcases when it emits to the BEAM** — *"PascalCase becomes
   snake_case"*. So candidate 2 is a transformation a neighbouring BEAM language already ships, and
   the borrow heuristic has somewhere to look before this is costed from first principles.
3. **Change B#'s own convention** to snake_case functions. Largest blast radius, and it fights the
   C#-family syntax that is the language's whole premise.

And separately, a question the frictions raise together: ~~**should the foreign-facing contract be
written down at all?** The `Kind` tag's spelling is load-bearing for external callers and is
documented nowhere.~~

**Answered 2026-08-25, the same day it was asked** — David: *"write down the Kind contract for
external callers"*. `LANGUAGE.md` §12, *"Being called from Erlang and Elixir"*, now states it: the
module atom, the PascalCase exports and what they cost Elixir, the full erasure table read off the
emitted `-spec`, the two arms that surprise a BEAM caller (`result<T, E>` succeeds as the **bare**
value; `option<T>` is absent as the atom `nothing`), and the `Kind` rule itself — key, minted value,
the full dotted path, and the three-line demonstration that a wrong tag and an Elixir struct are
both `FunctionClauseError`.

The section names the asymmetry as the reason it exists: `Kind` is the one key a construction may
not name *inside* B#, and the one key every caller must name *outside* it. **So the tag is now a
published interface rather than an accident**, and the remaining open decision in this ticket is
the function-name casing alone.

## Notes

**Do not treat this as ticket 50 reversed.** 50 asks how B# *names* a foreign aggregate; this asks
what B# *presents*. Different construct, different candidates — 50's shapes are about declaration
syntax, these are about emission.

**The prefix question is answered and should not be re-opened** without new evidence: it is measured
above that no module prefix, including Elixir's own, changes the call syntax.

**This bears on the clean-room handoff.** The destination is a spec an agent fleet implements without
David in the room. §3 means there is a contract every foreign caller depends on which no document
states — so whatever this ticket decides, the tag's spelling stops being an implementation detail
and becomes something the spec owes a section.
