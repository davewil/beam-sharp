# 32 — The FFI surface: how a foreign function is declared and called

Type: grilling
Status: resolved 2026-08-14

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

## Measurements, 2026-08-14

The prior art the ticket said to consult first was **run rather than read**, per the map's
provenance rule. Four prototypes, all `local`: Gleam 1.18.1, OTP 28.5, Elixir 1.19.5, .NET 9.0.306.

| # | Prototype | What it settles |
|---|---|---|
| 32a | [Gleam's `@external` lowering](../prototypes/32a_gleam_external.md) | borrow the syntax, refuse the **lowering** too |
| 32b | [Name-mapping census](../prototypes/32b_name_census.md) | §3 and §4, by counting |
| 32c | [C#'s `DllImport`, run](../prototypes/32c_csharp_foreign_declaration.md) | §1, and a correction to this ticket's framing |
| 32d | [Where the boundary code lives](../prototypes/32d_where_boundary_code_lives.md) | prices a fork the ticket did not know it had |

**A. The sub-questions that measurement closes on its own.**

- **§4 — one arity per declaration, no defaults, and the reason is stronger than "safe".** 23.3% of
  stdlib+kernel name/arity pairs carry more than one arity, and **45 of those 756 have gaps** in the
  arity set (`inet_udp:send/2,4` with no `/3`; `io_lib:write/1,2,3,5`). A default-argument reading
  generates a *contiguous* ladder, so a foreign arity family is not ticket 08's generated arities and
  cannot be described as them.
- **§2 — per function.** Per-module import cannot select an arity, and §4 makes arity the thing being
  named. This also follows Gleam and C# together.
- **§6 — the call site is not specially marked.** Ticket 17 §1 already made every call qualified, and
  the foreign module name carries it.

**B. A finding the ticket did not anticipate: the tier-1 borrow has the same hole as Gleam.**
Two C# names over one foreign symbol with **different declared return types** both compiled and both
ran (32c). This ticket framed unchecked FFI as Gleam's flaw against a clean C# borrow; measured,
`extern` is unchecked too. So ticket 18's guard is a **deliberate divergence from both audiences**,
not merely from Gleam, and the spec owes that sentence — a C# reader expects `extern` to be a
promise nobody checks. The compensation is real and worth stating beside it: because 18 checks,
**beam-sharp can emit the `-spec` Gleam emits and unlike Gleam's it is not a lie.**

**C. A fork the ticket did not know it had — and it is a *lowering* question, not a syntax one.**
Gleam's `@external` emits a wrapper function where the **module's API** needs one and never where
the **boundary** does: a public external that is never called still gets a function and a `-spec`,
while a private external that *is* called is erased entirely, its call inlined (32a). beam-sharp
cannot copy that, because ticket 15's `try` wrapper and ticket 18's guard have to live somewhere.
Priced in 32d: **~60 bytes once as a function, versus ~65 bytes per call site inlined** — flat
against linear, 43× apart at 40 call sites. Gleam's inlining is affordable *only because it checks
nothing*.

This ticket decides syntax and says so. **The number is recorded here; the choice is not taken
here** — see fork 3 below.

## Answer — 2026-08-14

**A foreign function is declared, and the declaration carries both spellings.** David, reading the
three shapes written out as ordinary code in [`32e`](../prototypes/32e-ffi-on-the-page.md):
*"A clearly reads better."*

**That is the standing constraint reaching its own conclusion, not a preference.** The three shapes
divide exactly along the constraint's line: declaring up front is **write cost**, priced near-free;
narrowing a `term` at each use is **read cost**, which carries full weight. Elixir's zero-ceremony
shape is shorter to write and noisier to read, and its cost is *regressive* — nearly free on values
you were going to validate anyway, most annoying on `system_time`, `byte_size`, `length`, the
trivial calls made most often. Recorded because the answer was available from the constraint before
any of the four measurements were taken, and nobody derived it.

### 1. The construct — and fork 1 dissolves rather than being decided

**A foreign declaration is a signature with no clauses carrying an `[external: …]` attribute.** It
shares its *grammar* with [ticket 23](23-what-the-language-owes-an-agent.md) §7's stub — signature,
no clause list, one attribute — and shares nothing else, because the two markers mean opposite
things:

| | 23 §7's stub | a foreign declaration |
|---|---|---|
| Means | **not finished** — clauses are owed | **finished elsewhere** — no clauses will ever exist |
| Residual | the entire declared parameter type, as a diagnostic | none; there is nothing to be inexhaustive about |
| Release gate | **must** trip a text search for incompleteness | **must not** |

So they must stay distinguishable *because* of the gate 23 §7 built the marker for. **Ticket 32
therefore does not decide any part of deferred [ticket 22](22-how-opinionated.md)** — 22 still owns
how the *stub* marker is spelled; 32 owns the *foreign* one, and answers it independently as a
tier-1 borrow of C#'s `[DllImport]` on the attribute-target syntax `[module: GenServer]` already
established.

### 2. The declaration binds the module; functions are declared under it

The flat form invents a beam-sharp name per foreign function and collides immediately, so you prefix
(`EtsLookup`, `EtsInsert`) — Hungarian notation reinvented, and a name that lies about where the
function lives. Binding the *module* removes both:

```csharp
// index.bs
[external: erlang, "ets"]
module Ets {
    list<term> Lookup(atom, term);
    true       Insert(atom, term);
}

[external: erlang, "erlang"]
module Erlang {
    int SystemTime(atom);
    int ByteSize(binary);
}
```

```csharp
(table, id) -> Ets.Lookup(table, id) switch { ... };
(s) when s.ExpiresAt > Erlang.SystemTime(:second) -> s;
```

**This is not per-module import** — §2's measured answer stands, and each function still carries its
own signature and its own single arity. What is per module is the *name binding*, which is the part
that has no arity to select. Ticket 26's casing rule reads `Ets.Lookup` as a call because both
segments are uppercase; a lowercase foreign name would have lexed as a field projection, which is
what closed the C# "identity by default" shape (32e §C).

### 3. Naming — no mapping rule exists, and 32b's census answered a question nobody had

Both spellings are written: the Erlang atom in quotes, the beam-sharp name in the declaration.
**There is no snake_case ⇄ PascalCase rule anywhere in the language.** The census stands as the
evidence for *why not* rather than as the input to one: a mapping reaches 1,920 of 1,924
stdlib+kernel names but cannot spell `'PKCS-1'`, `'OTP-PKIX'` or `'ELDAPv3'` at all, and cannot
spell a quarter of Elixir's function names (`fetch!`, `valid?`, `&&&`) under any rule. A quoted
string has no failure case, and the 265 unspellable module names cost nothing.

**This also settles the direction of the module-naming fog patch that runs inwards.** That patch
owes an answer for what atom a beam-sharp module *emits*; the incoming direction needs no answer at
all, because nothing is derived. One detail is genuinely owed and recorded below.

### 4. Arity — exactly one per declaration, no defaults

Measured (32b): 23.3% of stdlib+kernel name/arity pairs carry more than one arity and **45 of those
756 have gaps** — `inet_udp:send/2,4` with no `/3`, `io_lib:write/1,2,3,5`. Ticket 08's generated
arities produce a *contiguous* ladder, so a foreign arity family is not that and cannot be described
as it. Two arities of one Erlang function are two declarations, which the module block makes cheap.

### 5. Elixir is the same construct with a different module spelling

```csharp
[external: elixir, "Enum"]
module Enum { list<term> Map(list<term>, fn(term) -> term); }
```

The `elixir` tag selects the `'Elixir.'` prefix; nothing else differs, and Elixir's module atoms are
already dotted PascalCase so they arrive unchanged. **But its macros are unreachable** — measured,
Elixir exports them as `MACRO-`-prefixed functions (`MACRO-__using__`, `MACRO-defcallback`) which
are compile-time constructs of Elixir's own compiler and not callable from another language. So
`use GenServer` cannot cross this boundary, ever. That is a fact for the bootstrapping patch, not a
limit of this construct.

### 6. The call site is not marked, and the module binding is what makes that safe

Ticket 17 §1 already made every call qualified. Under §2's binding the qualifier is a name the
reader can look up in `index.bs` and find an `[external: …]` on — so the seam is discoverable
without being decorated. Note this is the one place Elixir's shape was better on read cost: `:ets.`
marks every crossing for free with no rule at all. The trade is deliberate.

### 7. The lowering — recorded, and the choice is taken

Fork 3 asked whether the lowering is 32's to decide given the ticket's "decides syntax" line. **It
is, because §2 just made the declaration a named thing with a signature** — that *is* a function,
and the question stops being open. A foreign declaration lowers to **a real emitted function**
carrying ticket 15's `try` wrapper and ticket 18's guard, called normally.

Measured (32d): **~60 bytes once, flat at every call count, against ~65 bytes per call site if
inlined** — 43× apart at 40 call sites. Gleam does the opposite, emitting a wrapper where the
*module's API* needs one and never where the boundary does, erasing private externals entirely
(32a); it can afford that only because it checks nothing. **Borrow Gleam's syntax, refuse its
semantics (already decided by 18), refuse its lowering (decided here).**

### 8. A correction this ticket owes the spec

This ticket framed unchecked FFI as Gleam's flaw against a clean C# borrow. **Measured, `extern` is
unchecked too** — two C# names over one foreign symbol with different declared return types both
compiled and ran (32c). So ticket 18's guard is a deliberate divergence from **both** audiences, and
a C# reader will expect `[external: …]` to be a promise nobody checks. The compensation belongs in
the same sentence: because 18 checks, **beam-sharp emits the `-spec` Gleam emits and unlike Gleam's
it is not a lie.**

## Owed, small, and named

- **A foreign module binding introduces an identifier that is not a beam-sharp module.** `Ets` is an
  alias to an atom, and nothing yet says what happens when a real beam-sharp module wants that name.
  A resolution rule is owed — it belongs with the module-and-namespace fog patch, which is where
  the outgoing direction already lives.
- **Whether a foreign module block may be declared outside `index.bs`.** Assumed yes; not decided.

## Superseded forks — kept for the record, all three closed above

*Fork 1 dissolved (§1: the markers mean opposites, so 22 is untouched). Fork 2 answered by the page
rather than the census (§3: no mapping rule exists). Fork 3 answered yes (§7: §2 made the
declaration a named thing with a signature, so the lowering stopped being open).*

**Fork 1 — does the foreign marker share ticket 23 §7's clauseless-signature construct?**
23 §7 made a signature with no clauses legal with an explicit marker and left the *marker's
spelling* to [ticket 22](22-how-opinionated.md), which is deferred. A foreign declaration is the
same construct with a different marker (confirmed against C# in 32c). Folding them together gains
the language an FFI for the cost of an attribute — and decides a slice of 22 from here, which is a
scoping call rather than a routine one.

**Fork 2 — naming: identity-plus-override, or always both spellings?** The two candidates are not
symmetric and the asymmetry is measured (32b):

- *Mechanical mapping* reaches **1,920 of 1,924** stdlib+kernel names (99.8%), failing only on a
  segment that begins with a digit (`bin_is_7bit`, `read_4`). But across the whole loadable tree
  **265 module names cannot be spelled at all** (`'PKCS-1'`, `'OTP-PKIX'`, `'ELDAPv3'`), so a
  mapping *must* carry an override or part of OTP is unnameable.
- *Always both spellings* (Gleam's) has **no failure case anywhere**, and pays ceremony on the 1,920
  names where the mapping would have worked — which the standing constraint prices at near-free to
  write and non-free to read.
- C#'s own answer is a third shape: **identity by default, `EntryPoint` override when they differ**
  (32c). Note Elixir inverts the problem — its module atoms are already dotted PascalCase and map
  losslessly, while **a quarter of its function names cannot be spelled by any mapping** (`fetch!`,
  `valid?`, `&&&`).

**Fork 3 — is the lowering 32's to decide?** The measurement is unambiguous, but this ticket's own
scope line says it adds no checking rule and decides syntax. Either it takes the lowering as an
explicit sub-answer, or the number lands as a note the spec owes and the choice moves elsewhere.

## Notes

Grilling. Blocked by nothing. The skeleton lists FFI as out of slice, so nothing forces it yet —
but it gates the bootstrapping patch and ticket 31, and it is the smallest of the three
bootstrapping axes.

**One measured fact belongs to the bootstrapping patch rather than to this ticket.** Elixir exports
its macros as `MACRO-`-prefixed functions (`MACRO-__using__`, `MACRO-defcallback`), which are
compile-time constructs of Elixir's compiler and **not callable from another language** (32b). So an
FFI to Elixir reaches its functions and never its macros, and `use GenServer` is unreachable across
the boundary — which means bootstrapping axis (c), *"a beam-sharp `GenServer`, as Elixir has one"*,
cannot be Elixir's shape at that seam even after this ticket lands.
