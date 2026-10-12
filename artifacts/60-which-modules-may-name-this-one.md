# Decision brief: ticket 60 / ENG-242 — which modules may name this one?

**DRAFT FOR HUMAN REVIEW — ticket remains open.** Nothing in the repo, Linear or any ticket was edited.
Probes: `artifacts/probes/60/<letter>/run.sh` + `out.txt` (source `env.sh` first; letters in the index at the end).
The prototype is a patch (`probes/60/proto/ticket60.patch`, +64 lines) applied to a *copy* of `compiler/`
by `proto/build.sh`.

## What the ticket bundles, and what gates what

Four sub-decisions (ticket "What has to be decided"): (1) the unit, (2) the direction, (3) third visibility
marker or separate construct, (4) checker cost. **Gating: 1 and 2 together, because 2 is half-answered by
code that already exists.** `using` is already the caller's dependency list and a call that skips it is
refused (`Shop.Orders is called but never imported`, probe a #7). What is
unbuilt is only a *callee-side refusal*. 3 and 4 are measured below and follow from 1.

## The gating question, alone

> A module `Shop.Orders.Recompute` is `public` to its callers today, so `Tools.Rogue` in another tree names
> it (probe a). Should the **callee** state a **subtree of the module path** outside which it cannot be
> named — and if the unit is not a subtree, what is it?

## Three findings the ticket does not have (read before the options)

1. **The consumer is stale in part.** The ticket (and 22 line ~393) say `RecomputeTotal/1` "lands `unclassified`"
   and an agent's test will target it. F12 (done 2026-08-17, before the ticket was written) made *private the
   default*: an unmarked helper cannot be named from another module — `Tools/Report/Peek2.bs:6:28: error: Peek2
   calls Shop.Orders.Recompute/2, which Shop.Orders declares private` (probe a #3). The residue is a helper
   made `public` because a *sibling* needs it; `bsc --api` prints it as plain API (`int RecomputeTotal(list<int>)`,
   probe a #5) and a test-shaped module in a third tree compiles against it (a #6). Also: `bsc --api` on
   `examples/Counter` prints a module line plus signatures, not the `boundary:/callbacks:/unclassified:`
   listing 24 §2 sketches (24:216-236); the only `unclassified` in `compiler/src` is a diagnostic tag
   (`bs_diag.erl:75`). I ran `--api` on one module only, so "that manifest is unbuilt" is **not** established.
2. **Citation drift.** The ticket's checker site is now `bs_check.erl:498-525` (`add_import/7` at 498,
   `add_module_import/3` — arity 3, not 5 — at 512; `add_namespace_import/3` at 527). Commit `0b761f6` is not in
   this clone (probe l). "18 §5" is *No opt-out* (18:852); the exported-vs-local claim is at 18:439-440 and
   18:613 (§1) — it holds, probe e.
3. **A module-level rule cannot hide `RecomputeTotal` while it sits in `Shop.Orders` itself.** It hides *modules*.
   To restrict a helper it must move to its own directory (F15: a directory is a module). That is a real cost of
   every option below; I did not measure how many corpus helpers would need to move.

## Why direction is not a free choice

*Caller-side* checks already exist and do not protect the callee (the rogue module simply omits the declaration).
*Runtime* enforcement is out: the BEAM has one entry label per function — a local and an exported function
assemble identically except the `{exports,…}` line (probe e) — and a runtime caller check costs ~43x a plain
call and is unsound under tail calls (probe f: plain 8.3 ns, stacktrace check 375 ns median; a rogue module
tail-calling the checked function is **admitted**, and so is `Y = f(), Y`, which erlc silently turns into a tail
call). So the rule is a compile-time check at the caller's edge, or nothing. The ticket's premise holds.

## Option A — callee-side, unit = subtree (Go / Rust `pub(in)` shape)

```csharp
// Shop/Orders/Recompute/index.bs        module Shop.Orders.Recompute
within Shop            // nameable only from Shop and below      (spelling is the NEXT question, see below)

// Shop/Billing/Charge.bs     using Shop.Orders.Recompute   -> compiles (under Shop)
// Tools/Rogue/Peek.bs        using Shop.Orders.Recompute   ->
//   Tools/Rogue/Peek.bs:3:1: error: Tools.Rogue may not name Shop.Orders.Recompute
```

Compiler delta (prototyped, probes b/i/k): one `World` entry field per module (`within => [Path]`), one predicate
`visible_to(Self, M, World)` called once per `using` edge in `add_import` (`bs_check.erl:498`), a namespace-import
filter in the same function, one `resolve_error` clause. Emitted code: **none** (no beam changes). Cost: +43 lines
in `bs_check.erl`, +8 in `bs_parser.yrl`, +3 lexer, +3 `bsc.erl`, +7 `bs_diag.erl` for all four spellings I
tried together (`internal`, `within`, `friend`, `Internal` segment); **zero new yecc conflicts** (6 shift/reduce before and after). Check cost: predicate ~15 ns when
nothing is restricted, ~0.4 us when restricted (probe d micro, a *copy* of the function) x ~285 edges = ~0.1 ms;
end-to-end on 60 modules/285 edges, 9 runs x2: repo bsc median 659/723 ms, patched 659/685, patched with 20
restricted modules 700/730 ms — **not distinguishable from run-to-run spread (~100-200 ms)** (probe d).
Existing suite on the patched copy: see "Regression" below.

Precedent, executed: **Go** `internal/` — `go build` accepts `shop/orders` and `shop/orders/tests`, refuses
`shop/billing` and `tools/rogue` with `use of internal package … not allowed` (probe j); **Rust**
`pub(in crate::shop)` — refuses the outside caller, accepts the inside one, and is written *on the function*
(probe m). Both are callee-side, both a subtree.

**Strongest counterargument.** The subtree includes the module's own test directory: `Shop.Orders.Tests` names
`Shop.Orders.Recompute` fine (probes b, i, j). The consumer ("an agent writing tests targets the easy
helper") is served only if tests live *outside* the subtree and see only public API; nothing enforces where
tests live (24 §7: tests are ordinary B#, no exemption). A tree-shaped rule also cannot express "Billing and
Reports, but not Inventory" without widening to `Shop`.

*Spelling sub-question (follows, not gating):* (A1) a path segment named `Internal`, Go's way — **zero grammar**
(probe k: `Shop/Orders/Internal/Recompute/` refuses Billing and Rogue, accepts Orders and Orders.Tests) — but it
changes the module atom, and therefore every record tag minted from the qualified path (40 §1, 26 §1); (A2) a
declaration in `index.bs`, which keeps the atom but spends 1-2 lexer rules (a repo-wide grep finds no `.bs` using
`internal`/`within`/`friend` as a word, probe l). Do not spell it `internal` bare: see Gleam below.

## Option B — callee-side, unit = explicit list

```csharp
// Shop/Orders/Recompute/index.bs
friend Shop.Orders
friend Shop.Billing        // Shop.Orders.Tests is NOT admitted unless listed (probe c)
```

Delta: same predicate with `lists:member(Self, Friends)`; same order of cost (not separately timed; probe c shows the behaviour).
Precise, non-hierarchical; the C# `InternalsVisibleTo` and Java 9 `exports … to` shape (knowledge only).

**Strongest counterargument.** `index.bs` is the module's *contended* file by construction (41 §4: "every new
type, record and `using` line lands there"); a `friend` list makes every new legitimate caller edit the
callee's index, the thing 41 §4 spent its argument avoiding. Explicit lists also rot silently (a deleted
caller stays listed; nothing diagnoses an unused `friend`; not built, not measured).

## Option C — caller-declared dependency

```csharp
module Tools.Rogue
uses only Shop.Orders      // hypothetical: restrict what *this* module may use
```

Delta: a second allowlist beside `using`, checked in the same loop. Precedent: Elixir's `Boundary`
(third-party; knowledge only) and `mix xref` (`lib/mix/lib/mix/tasks/xref.ex:29,105` "compile-connected",
analysis of the graph, not a refusal). I executed the Elixir hook such a library uses — a compiler tracer
that sees `env.module` per remote call and raised `Tools.Rogue2 may not call Shop.Orders.Internal.recompute/1`
while accepting `Shop.Orders.Total` (probe h) — so the mechanism is available and cheap.

**Strongest counterargument.** It protects nothing: the module you want to stop is the one that does not
declare. It restricts *layering* (a real need) but not *this ticket's* need. Not recommended as an answer
to the ticket; fine as a later, separate question.

## Neighbour languages (what each word already means)

| Language | Mechanism | Enforced by compiler? | Evidence |
|---|---|---|---|
| Erlang | `-export`; `-doc false`/`hidden` | export: yes; doc: **no** | probe h (`e2:go()=42` over `-doc false`); `erl_lint.erl:1095-1098` accepts `false`/`hidden` for docs only. OTP xref has no caller restriction: its `restriction` operators are set-algebra on call sets (`xref.erl:413`); analyses listed at `xref.erl:1497-1503`. The "restricted-calls" xref feature in the task brief **does not exist** in tools-4.1.4.1 |
| Elixir | `defp`, `@moduledoc false`, `@doc false`, `:tracers` option | `defp`: yes; the docs flags: **no** | `module.ex:318` ("invisible to documentation extraction tools"); `code.ex:1668` tracers; probe h |
| Gleam 1.19.0 | `@internal`, `internal_modules` in `gleam.toml` | **no, not by `gleam build` across a path dependency** | probe g (executed; no compiler source installed): `app` named `lib.helper` (`@internal`), `lib/internal/deep` and the `@internal` type `lib.Secret`; build exit 0, no warning. The only effect I could observe: `gleam docs build` omits the `@internal` function; the `.beam` still exports it. Hex-dependency case and `gleam publish` not testable (hex blocked) |
| Elm | `module M exposing (..)` lists, opaque types | yes, but **not run**: `package.elm-lang.org` returns 403 and `~/.elm` is empty, so `elm make` cannot resolve `elm/core` | knowledge only |
| Go | `internal/` path segment | yes, subtree of the parent | probe j (executed, go1.24.7) |
| Rust | `pub(in path)` / `pub(crate)` | yes | probe m (executed, rustc 1.97.0) |
| C# / F# / Java | `internal` (assembly), `InternalsVisibleTo`, JPMS `exports … to` | yes | **knowledge only**, not run |

The CLAUDE.md false-friend rule, tested: C# `internal` is assembly-scoped and enforced; Gleam `@internal` is
package-scoped and (1.19.0) **unenforced**; a B# `internal` that refuses a subtree would be a third meaning of the
word. Go gets the same semantics B# wants with the word as a *directory name*, not a keyword.

## Recommendation

**Answer the gating question A: callee-side, subtree.** Reasons: (i) the only direction that can refuse the
rogue/test module; (ii) the checker cost is one predicate per `using` edge, no emitter change, nothing
measurable at compile time (d); (iii) both executed precedents with enforcement (Go, Rust) are subtrees; (iv)
B (a list) loads the contended `index.bs` and C protects nothing. **Module-level, not a third visibility value
on the signature**: a third marker must be read as "exported" by five sites that test `=:= public`/`=/= public`
(`bs_check.erl:299,365,376,479`, `bs_emit.erl:141`; F12's own amendment records that getting one wrong exports
too much and no test of a working program sees it), and it still needs a per-call table like
`private_callee` (`bs_check.erl:4332`). Next question to ask alone, as code: `within Shop` in `index.bs` versus
an `Internal` directory — the atom/record-tag change decides it. Say it before choosing `Internal`: tests inside
the subtree are admitted.

## Not decided / not measured

- Whether the consumer (test discipline) is worth a new construct once F12's private default is counted (finding 1);
  a convention "tests live outside the subtree" would need its own enforcement.
- Function-level granularity: not prototyped (Rust shows it is expressible); cost estimated from the five reader sites only.
- Namespace-import edge: I filter hidden children and refuse with `may not name Vault.Hidden`; a *partly* visible
  namespace (one hidden child, one visible) and a qualified call `Hidden.Open` after such an import were **not** tested.
- Diagnostic wording is a placeholder; `--api` should probably mark restricted modules (not done).
- Unused-`friend`/stale-`within` diagnostics; `--diagnostics json` shape; REPL (`ibs`) and LSP behaviour.
- Elm behaviour, Gleam via Hex, C#/F#/Java: not run.
- Compile times are end-to-end `bsc` runs dominated by `erlc` per module and VM start; the checker share was not isolated beyond the micro.

## Regression

REGRESSION_PLACEHOLDER

## Probe index

| Probe | Claim checked | Result |
|---|---|---|
| `a/` | any public function is nameable from any tree today; private is refused (control); `--api` cannot tell a cross-module helper from client API; caller-side `using` is already mandatory (#7) | confirmed (exit 0 / refusal text / `--api` listing) |
| `b/` | prototype: parent-derived `internal` admits Orders and Orders.Tests, refuses Billing, Rogue, namespace-imported Vault.Hidden | as stated |
| `c/` | explicit `friend` list: Tests refused unless listed | confirmed |
| `d/` | compile-time overhead; `micro.sh` predicate cost | within noise; ~15 ns / ~0.4 us |
| `e/` | export vs local = one `{exports,…}` line, same labels | confirmed |
| `f/` | runtime caller check cost and soundness | ~43x; tail call admits rogue |
| `g/` | Gleam `@internal` / `internal_modules` enforcement | **not enforced** (1.19.0, path dep) |
| `h/` | Erlang `-doc false`, Elixir `@moduledoc false`/`defp`/tracer | docs-only; tracer can refuse |
| `i/` | `within Shop`: subtree named by callee | Billing admitted, Rogue refused |
| `j/` | Go `internal/` | executed, subtree rule confirmed |
| `k/` | `Internal` path segment, zero grammar | refuses Billing/Rogue; atom changes |
| `l/` | ticket's checker premises at HEAD | no `internal/friend/sealed/visible_to`; `0b761f6` absent; lines moved |
| `m/` | Rust `pub(in path)` | executed, outside caller refused |
