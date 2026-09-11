# 73 — Does a record name cross `using`?

Type: grilling
Status: resolved 2026-09-11, the day it was raised —
[ENG-360](https://linear.app/davewil/issue/ENG-360). Raised by the
[ENG-307](https://linear.app/davewil/issue/ENG-307) item 3 grill, round 2 Q2
Blocked by: —

## Why this is raised

ENG-307 landed the gate that keeps the hand-written minted tag out of the corpus and left its
item 3 to David: whether `{ Kind: :'Shop.Order' }` stays legal in source at all. Grilled
2026-09-11. Round 1 measured every position the tag can be written or read in, and the last row
of that table is this ticket:

| Position | Example | At `a51da4a` |
|---|---|---|
| clause head pattern | `Which({ Kind: :'Shop.Order' }) -> :order` | compiles; `check-record-idiom.sh` refuses it in the corpus, the compiler does not |
| switch arm pattern | `d switch { { Kind: :'Shop.Order' } => :order, ... }` | compiles |
| type declaration | `type Round = { Kind: :'Shapes.Circle', Radius: int }` | compiles, and **is** `Shapes.Circle` — tag plus the exact field set; tag alone, or tag with other fields, is refused where it meets `Shapes.Name` |
| guard | `Grd(d) when d.Kind == :'Shop.Order' -> :order` | compiles |
| projection | `Proj(o) -> o.Kind` | compiles, returns the atom |
| bare map literal in a body | `Mk(i) -> { Kind = :'Shop.Order', Id = i, Total = 0 }` | syntax error; construction is `Order { ... }` only, and [ticket 48](48-a-map-type-in-the-prelude.md) gave maps no literal |
| a second module naming the record | `Go(Circle c)` after `using Shapes` | `error: no type named Circle` |
| the same, qualified | `Go(Shapes.Circle c)` | `syntax error before: '.'` |

**Q1 of that grill asked whether B# source ever spells a minted tag. David: B# operates the way
Elixir does with `__struct__`.** The tag is an ordinary key; `Order o` is the sugar and the idiom;
the raw key is always available beneath it and the compiler refuses it nowhere. That answer made
the last two rows a question rather than a curiosity: with the hatch legal and the type name not
crossing, the hatch is the **only** way a consumer module can declare a producer's record as a
parameter. `bs_api.erl:6` states the rule as the compiler has it — *"a type NAME does not cross
the module boundary — only the resolved type reaches a dependent"* — and
[ticket 16](16-ad-hoc-polymorphism.md)'s 2026-08-27 amendment leads its open-extension refusal
with it. No ticket decided it; `import_env/3` builds no table of types, and the sentence
describes that.

## Round 2, Q2 — asked 2026-09-11

**The program.** In Elixir `%Orders.Order{}` is writable from any module because module names are
global. In B# today neither line below parses or resolves; what compiles instead is
`DueToday({ Kind: :'Orders.Order', Id: int, Total: int } o)`, which under Q1 is the hatch and not
the idiom.

```csharp
module Billing

using Orders

// unqualified, the way 41 §2 brings functions in
public int Due(Order o)
Due(o) -> o.Total

// qualified, the way 41 §5's namespace tier names a function
public int Owed(Orders.Order o)
Owed(o) -> o.Total
```

**The compiler delta.** `import_env/3` carries the producer's `record` and `type` declarations —
resolved, the way `exports_of/1` already resolves signatures — into the consumer's type table under
both the unqualified and the qualified name. `type_prim` in `bs_parser.yrl` gains `uident '.'
uident`, measured for yecc conflicts before and after. The `no type named` diagnostic learns to say
which `using` would supply the name. Ticket 16's leading ground comes out; its refusal stands on
what ENG-261 measured — the clause set is closed at the call — which the same probe showed survives
a consumer naming the union: `type Wide = Orders.Doc | Triangle` is still refused where it meets
`Orders.Which`.

**Recommended: yes, both spellings, mirroring 41 §2 and §5 exactly.** A record is part of a
module's interface the way its functions are, and `--api` already prints it.

## Answer — resolved 2026-09-11

**David: yes, both spellings.**

What follows, and where it goes:

- **The build is a feature, not this ticket.** It owes the delta above: the type table crossing
  `using`, the qualified `type_prim`, the diagnostic, and the yecc measurement. A `type` alias
  crosses by the same mechanism as a `record`, since under [ticket 09](09-union-representation.md)
  §1 a `type` introduces no new type and there is one table.
- **Collisions inherit 41 §2.** An unqualified name that two `using` lines supply has no meaning
  and is refused at the use; the qualified spelling is what disambiguates, exactly as for
  functions. Nothing new is decided about that here.
- **Ticket 16 loses a ground, not a decision.** "A type name does not cross the module boundary"
  was the compiler's behaviour, cited as if architectural. Open extension stays refused: a consumer
  can now *name* `Orders.Doc`, and still cannot add a clause to `Orders.Which`, whose clause set is
  one aggregate's source and is checked at every call that reaches it. Amended in 16 the same day.
- **ENG-261 resolves on the same measurement.** The asymmetry it predicted is real and narrower
  than it said: the type is spellable by structure, not by tag alone.

## Not decided here

- Whether the hatch spelling `{ Kind: :'Orders.Order', ... }` in a *type* position earns a
  diagnostic hint once `Orders.Order` parses. Q1 says it stays legal; whether the compiler
  volunteers the shorter spelling is a printer question for the feature.
- Construction through the raw key. No map literal exists; when one does, a literal wearing the tag
  is typed structurally like any map, which is stricter than Elixir by the type system and not by
  a hatch check.

## Decisions entry

<!-- This ticket's entry. The `issues/…` link is relative to the old decisions.md, so it is
     fenced rather than live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Does a record name cross `using`?](issues/73-a-record-name-crosses-using.md) — **yes, in both
  spellings ticket 41 gave functions: `Order o` after `using Orders`, and `Orders.Order o`
  anywhere.** Raised and answered 2026-09-11 inside the ENG-307 item 3 grill, whose Q1 David
  answered first: **B# treats the minted tag the way Elixir treats `__struct__`** — an ordinary
  key, the type prefix the sugar and the idiom, the raw `{ Kind: :'Shop.Order' }` legal in every
  position the grammar admits and refused by the compiler nowhere; the corpus gate is the
  enforcement. That answer exposed this question, because a consumer module could name a
  producer's record **only** through the hatch: `Order` after `using Orders` was "no type named",
  `Orders.Order` a syntax error, and `bs_api.erl:6`'s "a type name does not cross the module
  boundary" was the compiler's behaviour, never a decision. The build is a feature's: the import
  environment carries `record` and `type` declarations resolved under both names, `type_prim`
  gains the qualified form, collisions inherit 41 §2. Ticket 16's 2026-08-27 leading ground is
  withdrawn the same day and its open-extension refusal stands on the clause set being closed at
  the call, which ENG-261 measured.
```
