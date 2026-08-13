# 32 — The FFI surface: how a foreign function is declared and called

Type: grilling
Status: open

Raised 2026-08-13 from the map's **Bootstrapping** fog patch, axis (b). Everything about what a
foreign declaration may *mean* is decided; nothing about how one is *written* is.

## Question

**How does beam-sharp declare and call `:lists.keyfind/3`?**

That is the whole ticket. It is narrow on purpose — the semantics are settled and this is the
spelling.

## What is already decided — do not re-raise any of it

| Decided | By |
|---|---|
| A foreign declaration may promise only what **one BEAM guard decides in O(1)**. `list<Order>` is an error *at the declaration* and crosses as `list<term>` plus `ValidateAs<T>`. | [18](18-boundary-defence.md) §2 |
| A boundary guard is emitted where generated code consumes the value, **no opt-out** | [18](18-boundary-defence.md) |
| A foreign call declared to return a `result` gets a **compiler-emitted wrapper** catching all three exception classes into `foreign_error` | [15](15-error-model.md) |
| There is **no `try`** in the surface — the wrapper is the only exception handling | [15](15-error-model.md) |
| Foreign **funs** are holdable and returnable, never callable; the boundary is **MFA**, which is guard-decidable data | [11](11-type-system-shape.md) |
| **Guard** refinements are legal at an FFI boundary; **opaque** refinements are barred from foreign declarations | [20](20-untheorised-term-shapes.md) §5, [29](29-refinement-type-prior-art.md) |
| The FFI `-spec` sub-question is **dissolved**, not deferred — a checked claim needs no exception | [18](18-boundary-defence.md) §2 |

So this ticket adds no checking rule and weakens none. It decides syntax.

## The sub-questions

**1. Is a foreign declaration a distinct construct, or a signature with no clauses?**
[Ticket 23](23-what-the-language-owes-an-agent.md) §7 already made **a signature with no clauses
legal**, carrying an explicit marker, and deliberately left the marker's spelling to
[ticket 22](22-how-opinionated.md). A foreign function is *exactly* a signature with no clauses and
a different marker. If those two land on one construct, the language gains an FFI for the cost of
an attribute.

**2. Per function, or per module?** Gleam declares per function. Erlang's `-import` is per module
and is discouraged by its own community. Per function is more verbose and the standing constraint
says write cost is near-free while read cost is not — but a 40-function module is 40 declarations,
and ticket 23 §10 made the directory listing part of the API surface.

**3. How does a snake_case Erlang name become a beam-sharp name?** `:lists.keyfind/3` is
`lists`/`keyfind`, beam-sharp is PascalCase for modules and functions. Either the declaration
carries both spellings (Gleam's approach) or a mechanical mapping is imposed. **This collides with
the module-naming fog patch**, which already owes an answer to what atom a beam-sharp module
identifier emits — and note the collision runs the other way here: this is Erlang's atom coming
*in*, not beam-sharp's going *out*.

**4. Arity is part of BEAM identity, and beam-sharp's arities are generated.** Ticket 08 kept
defaults and variadics with **arity generation as codegen**, so a beam-sharp function name maps to
several BEAM arities. A foreign declaration names exactly one. Whether a foreign function may carry
defaults at all is open, and the safe answer is probably no.

**5. Elixir as well as Erlang.** An Elixir module is the atom `'Elixir.Enum'` and Elixir functions
with default arguments generate multiple arities of their own. Ticket 06 found Elixir *"needs no
special machinery"*, which was about the calling convention — it is not obviously true of the
naming.

**6. Is the call site marked?** A call to a declared foreign function could look like any other
qualified call, or could be visibly foreign. Ticket 18's guarantee is *"a foreign term that breaks
your types will crash — not always where it entered, but never silently"*, and a reader tracing a
crash backwards benefits from seeing which calls cross the boundary. Against that, ticket 17 §1
made every call qualified already, so the module name may carry enough.

## Prior art to consult first

- **C# has this construct exactly.** `[DllImport("user32.dll")] static extern int MessageBox(...)`
  is a signature with no body plus an attribute naming the foreign entity — a **tier-1 borrow**
  under the map's own heuristic, and the same attribute syntax `[module: GenServer]` already uses.
  Read it before designing anything.
- **Gleam's `@external(erlang, "lists", "keyfind")`** — per function, both spellings carried. But
  ticket 18 **measured** that Gleam *trusts* the declaration and publishes the false claim as a
  `-spec`: a function declared `-> Int` returned `41.5`. So Gleam supplies the syntax to borrow and
  the semantics to refuse.
- **Elixir declares nothing at all** — `:lists.keyfind(k, l, d)` is an ordinary call because module
  names are atoms and nothing is checked. The zero-ceremony baseline, and the reason beam-sharp
  cannot have it: the boundary check needs a declared type to check against.
- **purerl's `foreign import`** plus a hand-written `.erl` file, which is the shape ticket 21 found
  fails for a different reason.

## Why it matters more than a syntax question usually would

**Everything in the map's bootstrapping patch is blocked on it.** Elixir's `GenServer` is Elixir
code calling `:gen_server` directly, and its `Kernel`, `Supervisor`, `Agent` and `Task` are the
same shape — measured 2026-08-13, all `.ex` over an Erlang runtime. If beam-sharp is to have its
own OTP layer rather than only compiler-known types over Erlang's, this is the construct that
layer is written in. Ticket 00 made `handle_call/3` the showcase, so the headline demo's
implementation strategy waits on this.

## Notes

Grilling. Blocked by nothing. The skeleton lists FFI as out of slice, so nothing forces it yet —
but it gates the bootstrapping patch and ticket 31, and it is the smallest of the three
bootstrapping axes.
