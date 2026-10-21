# Brief — ticket 62 (ENG-252): the outbound ABI — PascalCase functions seen from Elixir

Status: **open, left open.** Evidence for David; nothing here is decided. Probes: `artifacts/probes/62/`.
What is still open in the ticket after its 2026-08-25 amendment is **the function-name casing alone**.

## Two things in the ticket and in `LANGUAGE.md` §12 do not survive being run

**1. Elixir *can* call a PascalCase export, and the spelling is one pair of quotes.** (`62-p1`, Elixir 1.18.4 on OTP 28;
Elixir 1.14 on OTP 25 gave the same table when I first ran it.) Against an Erlang module `'Shop'` exporting `'New'/1`:

```
:Shop.New(1)                 -> SyntaxError            (the ticket's measurement: true)
:"BSharp.Shop".New(1)        -> SyntaxError            (true: no prefix helps)
:Shop."New"(1)               -> %{Id: 1, Kind: :"Shop.Order", Total: 0}      <- runs
:"Shop"."New"(1)             -> same
apply(:Shop, :New, [1])      -> same                   (what LANGUAGE.md §12 calls "the way in")
```

`Code.format_string!` keeps `:Shop."New"(1)` unchanged and a compile of a module calling it emits no warning. An adopter
who wants an idiomatic name writes one line per function in their own code:

```elixir
defmodule MyApp.ShopApi do
  defdelegate new(id), to: :Shop, as: :New       # measured: MyApp.ShopApi.new(7) returns the record map
end
```
So the ticket's "Elixir callers use `apply/3`" understates the floor: the floor is a quoted function name, and
`LANGUAGE.md:3324-3325` (`# SyntaxError … apply(:Shop, :New, [1])  # the way in`) is incomplete on the current
evidence. That is a spec correction independent of what is decided.

**2. Gleam is not a precedent for emitting a snake_case function from a PascalCase one.** Ticket 62 offers, as precedent for candidate 2,
that Gleam "downcases PascalCase to snake_case when it emits to the BEAM" (the line comes from ticket 10, whose
own sentence is about *variants*: "fieldless variants compile to atoms … PascalCase to snake_case"). Run (`62-p2`) and read
(`compiler-core/src/strings.rs:70` `to_snake_case`, used at `erlang.rs:369,383` for **type and constructor** names):

```
type Event { OrderPlaced(id: Int)  HTTPGet  GetID }   ->   {order_placed, integer()} | h_t_t_p_get | get_i_d
pub fn New(id: Int) -> Int { id }                      ->   error: I'm expecting a lowercase name here
```
Gleam *forbids* PascalCase functions, so it never maps one; its snake-casing is for constructor atoms, and it
mangles acronyms (`HTTPGet` → `h_t_t_p_get`). Gleam calls a PascalCase Erlang function without trouble:
`@external(erlang, "Shop", "New")` compiled **and ran** (the ticket measured compile only; `62-p2`(a) printed the
returned map).

## The options, as programs and compiler deltas

**A — Accept; document the quoted spelling and the `defdelegate` shim.**
```elixir
:Shop."New"(1)                 # direct
defdelegate new(id), to: :Shop, as: :New   # idiomatic, in the adopter's code
```
Compiler delta: **none.** Doc delta: `LANGUAGE.md` §12's Elixir lines gain the quoted form and the shim.
*Strongest counterargument:* the ticket's own premise — incremental adoption inside an existing Elixir codebase is
the likeliest way anyone tries B# — means every B# function an Elixir team calls needs a shim line or a quoted call;
that is a recurring tax on exactly the first user.

**B — Emit a snake_case alias beside every exported function (candidate 2).**
```erlang
'New'(Id) -> ….            new(V1) -> 'New'(V1).      % :Shop.new(1) now parses in Elixir
```
Compiler delta: in `bs_emit` after the export list is built, for each `{Name,Arity}` add one clause calling the original,
one `-export`, one copied `-spec`; a refusal at the declaration for two exports that derive the same alias.
Measured (`62-p4`, real `.abstr` of the 31 modules bsc builds from `compiler/examples`, aliases added to the same forms
and both versions compiled by the same call): **109 aliases, +65.0 B each, +7080 B total = +10.5% of beam size** (compiled with `debug_info` as bsc does; without it the probe read 34.1 B / 9.8%)
(3 of 112 exports are already lowercase OTP callbacks and need none). The derivation rule is a design choice that
matters: on the real corpus Gleam's rule and Elixir's `Macro.underscore` agree on all 86 distinct names and neither
collides inside a module (`62-p3`), but they diverge on acronyms an author can write today:

```
GetID    -> get_i_d (Gleam rule)   get_id (Elixir)      GetId -> get_id both    => under Elixir's rule GetID and GetId collide
HTTPGet  -> h_t_t_p_get            http_get
```
*Strongest counterargument:* it reintroduces a snake_case⇄PascalCase mapping that `LANGUAGE.md` refuses (`:3122`, `:3460`)
("a mapping was measured unable to spell `'PKCS-1'` or a quarter of Elixir's function names"). That refusal was about the
*inbound* direction, where the mapping must be total over foreign names; outbound it only needs to be total over B#
names, which are `[A-Z][A-Za-z0-9_]*` (`bs_lexer.xrl:14,16,150`) — so the objection does not transfer — but the collision rule above is
new surface and a second spelling of every export is permanent ABI.

**C — Emit an alias only where the author asks, and let them choose the name.**
```csharp
[ElixirName("new")]
public order New(int id)       // exports 'New'/1 and new/1
```
Compiler delta: an attribute production, the same per-function alias emission as B restricted to annotated
functions, a collision check on the chosen names (no derivation rule at all). Cost is B's ≈65 B, paid only where used.
*Strongest counterargument:* it adds a language-level concept (an attribute that exists only for another language's
syntax) and asks the author to do per call what A asks the adopter to do per call; the burden only moves.

(The ticket's candidate 3 — snake_case functions in B# itself — I did not measure: it contradicts the C#-family
surface the language is premised on, and nothing in a probe bears on it.)

## Recommendation

**A now**, with the §12 correction, because the measured friction is a pair of quotes and a one-line shim, not an
impossibility, and A costs no bytes and no permanent ABI. If adopters report the quoting as a barrier, **C** is the
upgrade: it adds no derivation rule, no collision surface and no cost for functions nobody calls from Elixir.
**B** is the option I would not take blind: it doubles the export surface of every module (+10.5%), it needs a
derivation rule whose acronym behaviour two reference implementations disagree on, and the evidence for it (the
"Gleam precedent") does not hold.

## What I could not measure

- Whether Elixir teams find the quoted call acceptable: a judgement, not a probe.
- Elm's treatment of foreign callers (not exercisable offline; `elm make` needs the blocked package registry).
- Gleam 1.18.1 (the ticket's version); I ran 1.12.0. Constructor casing and the lowercase-function rule are old
  features, but I have not run the newer release.
