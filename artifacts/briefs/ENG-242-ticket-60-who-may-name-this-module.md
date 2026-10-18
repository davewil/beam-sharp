# Decision brief — ticket 60 (ENG-242): which modules may name this one?

**Status of the ticket: left open.** This brief recommends; it decides nothing.
Probes: `artifacts/probes/60/` (`probe.sh`, `output-probe.txt`, `proto.patch`). Toolchain and caveats: `artifacts/probes/README.md`.

## The gating question (ask this one alone)

> Is the unit a **directory subtree** — "this module may be named only from inside the namespace that contains it" — or an **explicit list** of modules?

Ticket 60 §1. Direction (§2) and marker-vs-construct (§3) follow: a list lives on the callee, a subtree can be read off the callee's own name.

## Measured facts that shape the question

1. **Today nothing restricts naming.** Baseline (`output-probe.txt`, variant `c`): `Other.App` does `using Shop.Internal.Tax` and calls `Vat(n)` — it compiles with no output. The checker's import site (`bs_check.erl:498`, `add_import/7` → `add_module_import/3` at `:512`) reads only the callee's export set; confirmed the ticket's measurement at the current tree.
2. **`using` is already the single gate.** A qualified call that skips it is refused: `Other/App2/App2.bs:3:31: error: Shop.Internal.Tax is called but never imported`. So one check at `add_import` covers both spellings; no second site in the qualified-call path (`bs_check.erl:3173`, `qual_table` at `:537`) is needed.
3. **The consumer from ticket 24 is real but unmeasured here.** I did not measure how many functions land `unclassified`; this brief says nothing about that.

## Sub-decisions

| # | Sub-decision | Settled by |
|---|---|---|
| a | The unit: subtree or list | the gating question |
| b | Direction: callee names who may call it, or caller declares dependencies | (a). A caller-side list cannot protect a callee — other callers are not listed in it — so only callee-side restricts *others* |
| c | Marker on the signature, or a construct on the module | (a): both options below are module-level; per-function visibility to *some* callers is a compile-time check on the caller in every case (ticket 18 §5), so function-level granularity adds nothing the module-level check lacks |
| d | The diagnostic's name and wording | follows |

## Prototype (what the compiler must gain, for the subtree option)

`60/proto.patch`, applied to a scratch copy of `bs_check.erl` (not the repo): in `add_import`, before `add_module_import`, `may_name(Self, M)`; a module whose name has an `Internal` segment is nameable only from a module whose name starts with the segment's parent. 17 added lines including the helper.

```csharp
// Shop/Internal/Tax/Tax.bs
module Shop.Internal.Tax
public int Vat(int net)  ;  Vat(n) -> n / 5

// Shop/Billing/Billing.bs   — compiles under the prototype:  using Shop.Internal.Tax
// Other/App/App.bs          — refused under the prototype:   using Shop.Internal.Tax
```

Measured (`output-probe.txt`): baseline compiles both; prototype compiles `Shop.Billing` and refuses `Other.App`. The prototype reuses the `unknown_module` diagnostic, whose text ("names no module and no namespace") is wrong for this case; a real version needs its own `internal_module` tag in `bs_diag.erl` (`built/2` and `message/1` — `message/1` has no catch-all, so a missing clause crashes, per the lexer note in `rebar.config`).

An early bug in my prototype (`lists:join` returns a deep list; `lists:prefix` then never matched, so it refused `Shop.Billing` too) shows the helper is easy to get subtly wrong; the patch committed in the probes directory is the fixed one and the output above is from it.

## Survey

| language | mechanism | does it stop a caller? | evidence |
|---|---|---|---|
| Gleam 1.19.1 | `internal_modules = [...]` in `gleam.toml`; `@internal` attribute on a `pub` item | **not observed**: a second package (path dependency) imported `lib/internal/secret` and called an `@internal pub fn`; both built with no error and no warning | `60/probe.sh` (executed). I cannot rule out enforcement for registry packages or in `gleam publish`/docs, which this sandbox cannot reach (hex.pm blocked) |
| Elixir 1.20.4 | `@moduledoc false` / `@doc false` | no: `Other.App.cheat(50)` called `Shop.Internal.Tax.vat` → 10 | `60/probe.sh` (executed) |
| Erlang | `-export` only (function-level, caller-blind) | n/a | not probed; from the language definition |
| Elm | `exposed-modules` in `elm.json`, package-level | not probed — package server unreachable | — |

Reading: of the three BEAM neighbours, none enforces module-level "who may name me" in anything this sandbox could run. Gleam's spelling is a config-file list of path patterns; it is the nearest prior art for option A. The ticket's warning against borrowing C#'s `internal` spelling stands: Gleam's `@internal` and `internal_modules` are about documentation and publishing, a third meaning.

## Options

**A. Subtree by name: a module with an `Internal` segment may be named only from inside its parent namespace.** No new syntax; the unit is F15's directory.
```csharp
using Shop.Internal.Tax     // in Shop.Billing: fine.   In Other.App: error: Shop.Internal.Tax is internal to Shop
```
Compiler delta: one rule at `add_import` (≈17 lines measured), one diagnostic tag, one test per side.
Strongest counterargument: it reserves a word inside module paths — any existing module whose path contains `Internal` changes meaning (I grepped `compiler/examples` and `handoff`: none does) — and it cannot say "Billing and Reports but not Shipping". It is also the exact false-friend the ticket warns about: `internal` here means *subtree*, not *assembly*.

**B. Explicit list on the callee.** `module Shop.Tax visible_to Shop.Billing, Shop.Reports` (spelling illustrative).
Compiler delta: parser rule for the header, a `visible_to` entry in the world map, one check at `add_import`, a diagnostic. **Not prototyped.**
Strongest counterargument: the callee must be edited every time a legitimate client is added, which inverts the dependency the `using` list already records; a new module that compiles fine today starts failing in a *different file*. It also needs a way to name "the whole namespace" or it reproduces A with more typing.

**C. Do nothing; keep `public`/`private` as the whole story.** Delta: none.
Strongest counterargument: measured — baseline lets `Other.App` call `Shop.Internal.Tax.Vat` freely, and the neighbours that "have" the feature (Elixir `@doc false`, Gleam `@internal`) block nothing either, so the evidence says the convention is cheap and unenforced everywhere. If C is chosen the ticket-24 consumer must classify helpers some other way.

## Recommendation

**A**, narrowly: it is the only option whose cost I could measure (≈17 lines, one check site, no syntax), it uses the one unit the language already has, and `using` being the single gate means it cannot be bypassed by a qualified call. Do not ship it before the diagnostic exists and a test seen to fail (the project's "gate believed only once seen to fail" rule). Prefer **C** if David judges that no one has yet been harmed by the absence; the ticket itself says "not owed a decision soon", and nothing measured here contradicts that.

## Not done / limits

- B is unprototyped.
- No gate run; no rebar3; see README for the 448 environmental eunit failures.
- Gleam enforcement for registry packages, Erlang and Elm unprobed.
- The ticket-24 consumer ("unclassified" functions) is unmeasured.
