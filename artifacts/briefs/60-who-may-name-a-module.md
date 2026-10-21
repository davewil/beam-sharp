# Brief — ticket 60 (ENG-242): which modules may name this one?

Status: **open, left open.** Evidence for David; nothing here is decided. Probes: `artifacts/probes/60/`.
The ticket says "not owed a decision soon". This brief prices the decision so it can wait cheaply.

## What is true today

`60-p3`: the *what* half is enforced and the *who* half is absent.

```csharp
// Shop/Internal/Pricing/pricing.bs
module Shop.Internal.Pricing
public int Total(int qty)   Total(qty)  -> Helper(qty)
int Helper(int qty)         Helper(qty) -> qty * 3

// Other/other.bs — a module with no relation to Shop.*
module Other
using Shop.Internal
public int Go(int q)        Go(q) -> Pricing.Total(q)           // compiles; bsc … Go 4  prints 12
// OtherPrivate/otherprivate.bs
GoPrivate(q) -> Pricing.Helper(q)
//   error: GoPrivate calls Shop.Internal.Pricing.Helper/1, which Shop.Internal.Pricing declares `private`
```

The checker site is where the ticket put it: `add_import(L, M, Self, World, …)` at `bs_check.erl:500-510`
(the ticket's `407-425` has moved). It receives **both** the importing module (`Self`) and the callee (`M`), and
`World[M]` is a map with `exports`, `types`, `private`, `polys`. A who-rule needs one more key in that map and one
list check per import edge; no emitter change and no change to the beam.

A compile-time rule cannot bind a foreign caller. `60-p3`'s last step compiles `Shop.Internal.Pricing` and calls it
from Elixir: `:"Shop.Internal.Pricing"."Total"(4)` → `12`, because a BEAM export belongs to the module, not to a
caller (18 §5's finding, reproduced). So any answer here guards **B# authors and agents** — the stated
consumer (ticket 24's `unclassified` remainder) — and nobody else.

## How the neighbours answer (all run)

| | mechanism | does the compiler refuse the caller? | probe / source |
|---|---|---|---|
| Gleam 1.12 | `internal_modules` globs in `gleam.toml`, default `<pkg>/internal` + `@internal` on a pub item | **No.** A consumer package imports `lib/internal/secret` and calls an `@internal` function: build succeeds, exit 0, no warning | `60-p1`; `compiler-core/src/config.rs:255-257` ("hidden in the docs"), `analyse.rs:1255` (publicity becomes `Internal`), `language_server/completer.rs:365` (filtered from completion) |
| Elixir 1.18 | `@moduledoc false` / `@doc false` | **No.** `Lib.Internal.hidden/0` is called from `App`; no warning | `60-p2` |
| Erlang OTP 28 | `-moduledoc false` | **No.** | `60-p2` |
| Elm 0.19.1 | `exposed-modules` in a *package's* elm.json | Not exercised: `elm make` needs the package registry, which this container's network policy blocks (403). I make no claim about Elm. | — |

The three BEAM neighbours I could run all treat "internal" as **documentation and tooling, not a compile error**.
The ticket's framing — "Gleam has `internal`" — is true of the spelling and false of the enforcement. A B# rule that
refuses would be stricter than any neighbour I could measure; that is a position, not a borrow.

## The decision, asked as one gating question

Per the repo's rule, one question gates the rest: **does a refusal belong in the compiler at all, or is
"internal" a documentation/tooling fact like every neighbour's?** Everything below is the answer "refuse", priced.

### Option A — the callee names a subtree; the compiler refuses a caller outside it

```csharp
module Shop.Internal.Pricing
visible Shop                 // only Shop and Shop.* may `using` this module

module Reports               // compile error: Reports may not name Shop.Internal.Pricing (visible to Shop)
using Shop.Internal
```
Answers the ticket's four questions as: unit = a path prefix (F15's directory is already the unit); direction =
callee; marker = a **module-level declaration**, not a signature marker (it is about modules); cost = in
`add_import`, `lists:prefix(path(Visible), path(Self))` against one new `World[M]` key, plus a
`visible_to_refused` diagnostic with the fix printed (`bs_diag.erl`, beside the `private` one). One new
keyword, one grammar production. I did not prototype it: the lexer/grammar change is the real work and the
checker part is a single comparison on a path already in hand.
*Strongest counterargument:* it is stricter than Gleam, Elixir and Erlang, none of which refuse, and it is
bypassed by every Erlang/Elixir caller (probe above); the guarantee is "B# authors cannot", which
only matters if an agent writing B# is the threat.

### Option B — location implies it: a path segment is the declaration (Gleam's `internal` convention made enforcing)

```csharp
module Shop.Internal.Pricing     // may be named only from Shop.*  (everything before `Internal`)
```
No keyword and no grammar change; the check is the same prefix comparison, keyed on the segment.
*Strongest counterargument:* it gives the path segment `Internal` a meaning, which ticket 67 Q6 (restated in 96's round 3) declined to
do even for a reserved qualifier ("a user module with that short name is refused where it would be written as the
word; a dotted path holding it is not"). It also means renaming a directory silently changes visibility —
the "edit in one file changes another file's rules" shape that 18 §4 rejected function-local analysis to avoid.

### Option C — no language construct; the consumer reads `public`/`private` and a convention

The `unclassified` problem (ticket 24 §2) is a test-targeting problem: `RecomputeTotal/1` is neither callback nor
client API. `bsc --api` already lists `public` exports per module; tooling can classify a module's `public`
functions that are not callbacks as client API. Nothing in `bs_check.erl` changes. This is what every
neighbour does.
*Strongest counterargument:* a classifier is a convention, and the ticket's point is that an agent in a loop
targets whatever is easy; only a refusal stops that, and `private` already stops the function-level case — the
residual is a *module* that is `public` but internal in intent.

## Recommendation

**C now, A held ready.** The consumer the ticket cites has no code behind it yet (`grep unclassified` finds only the
design in tickets 22/24 and an unrelated diagnostics tag), the BEAM neighbours I could run all ship the advisory
form without complaint, and a compile-time refusal cannot bind the Elixir/Erlang callers the language is
explicitly meant to coexist with (ticket 62). Build A only when the agent-drift consumer exists and shows the
failure; its price is written above (one keyword, one `World` key, one prefix compare) so it can be added without
a redesign. **B should not be taken**: it spends a path segment the repo has twice declined to spend.

## What I could not measure

- The checker cost of A: not prototyped (needs a grammar change); the estimate is from reading `add_import`.
- Elm's package-level `exposed-modules` (network policy blocks the registry).
- Whether an agent actually drifts toward `unclassified` functions: ticket 22's claim, no data in the repo.
