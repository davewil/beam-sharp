# Brief for ticket 60 (ENG-242): which modules may name this one?

Decision brief only. Nothing under `wayfinder/`, `compiler/` or Linear was touched. Probes: `artifacts/probes/60/` (`bash artifacts/probes/60/run.sh`, about 60 s, exit 0 here).
Toolchain: OTP 25, Elixir 1.14.0, Gleam 1.12.0, Elm 0.19.2. `bsc` cannot be built here, so every claim about `bsc` is read from source at HEAD `0dddf8b` and marked "cited, not re-run".

## 1. Question and the gating sub-decision

A B# module controls what it exposes (F12, `public`/`private`). It cannot control who may name it. The ticket lists four sub-decisions: unit, direction, third marker or separate construct, checker cost.

**The gating one is the unit: is a module's audience a subtree of the directory tree, or a list somebody writes down?**
- If the unit is the subtree, the module path already holds the data. No declaration is needed, so direction (2) and marker (3) have nothing to attach to. Cost (4) becomes one check at the existing import site.
- If the unit is a list, direction and marker both have to be decided, and cost grows with them.

Ask the unit alone, as two programs, one compiling under each answer (section 5). One correction before that: the ticket and ticket 22 cite `add_module_import/5` at `bs_check.erl:407-425`, measured at `0b761f6`. At HEAD it is `add_module_import/3` at `bs_check.erl:504-517`. The behaviour the ticket describes still holds (below).

## 2. Evidence

| # | Claim | Probe / citation | Result | Status |
|---|---|---|---|---|
| E1 | On the BEAM, an exported function is callable by any module, and `-opaque` is not enforced by `erlc` | [`erlang/run.sh`](probes/60/erlang/run.sh) step 1: `outsider:run()` calls `priv_mod:helper()` and builds `{secret,1}` for an `-opaque` type | `{42,{secret,1},7}`, `erlc` silent | measured here |
| E2 | Erlang can answer "who uses module M" only after compile, by a separate tool | same, step 2: `xref:analyze(s,{module_use,priv_mod})` then compare to an allow-list | `[outsider]` flagged. Needed `+debug_info`: without it xref fails with `unknown_constant` (first run, kept as found) | measured here |
| E3 | `-deprecated` is Erlang's only per-callee marker. It warns in xref, never refuses | same, steps 3-4 | `use.beam` produced, `erlc` silent. xref: `[{{use,g,0},{dep,f,0}}]` | measured here |
| E4 | Elixir `@moduledoc false` hides docs only; the call works | [`elixir/run.sh`](probes/60/elixir/run.sh) (a) | `Anywhere.g(): :reachable` | measured here |
| E5 | A caller-side check IS possible on the BEAM, as a compile tracer, in 20 lines | same (b): `tracer.exs` rejects `Shop.Reports` naming `Shop.Orders.Internal.Helper`, allows `Shop.Orders` and `Shop.Orders.Apply` | `REFUSED: lib_bad/b.ex:2: Shop.Reports may not name Shop.Orders.Internal.Helper.recompute/1 (internal to Shop.Orders)`. Control without the tracer: compiles | measured here |
| E6 | The tracer is blind to dynamic calls | same (e): `apply(Module.concat(...), :recompute, [x])` | compiles under the tracer | measured here |
| E7 | The tracer costs nothing measurable | same (d): 301 files, 30,000 `remote_function` events, 3 runs each | plain 8864 / 8282 / 9075 ms, traced 8885 / 9153 / 9046 ms: difference inside run-to-run noise (about 10%) | measured here |
| E8 | Gleam 1.12 does NOT refuse a cross-package import of an `internal_modules` module | [`gleam/run.sh`](probes/60/gleam/run.sh) (1): package `app` (path dep) imports `lib/internal/secret` | **builds, rc 0** | measured here |
| E9 | Gleam `@internal` on a `pub fn` is not refused either | same (2): `lib.helper(3)` from `app` | **builds, rc 0** | measured here |
| E10 | What Gleam's `internal` does do: remove the item from the package interface and docs | same (2b): `gleam export package-interface` | modules `['lib','lib/other']`, functions of `lib` = `['total']`. `lib/internal/secret` and `@internal helper` are absent, public `lib/other` present (the control) | measured here |
| E11 | Inside the package, the internal module is imported freely, and on the BEAM it is a plain export | same (3), (4) | `lib@internal@secret:recompute(21)` returns `42` from `erl` | measured here |
| E12 | In `bsc`, every cross-module reference already requires a `using` entry, so `using` is the one chokepoint | `bs_check.erl:4346-4360`, `qualified_module/3` + `require_imported/3`: "Qualified calls still require a `using` entry"; unqualified names come only from the `funs` table that `add_module_import` fills (`bs_check.erl:4332-4344`) | `module_not_imported` otherwise | cited, not re-run |
| E13 | `add_module_import/3` reads `exports` and `types` of the callee and nothing about the caller; `Self` is available one frame up | `bs_check.erl:490-517`: `add_import(L, M, Self, World, ...)` has `Self` and does not pass it down. All four `import_env` callers pass a `Self` (`bs_check.erl:318, 363, 376, 1540`) | confirms the ticket's measurement | cited, not re-run |
| E14 | A namespace `using` is a second door: `add_namespace_import/3` (`bs_check.erl:519-526`) adds **every child** of a prefix to `mods` and `imported` | same | any rule checked only in `add_module_import` is bypassed by `using Shop.Orders;` then `Internal.Pricing.X()` | cited, not re-run |
| E15 | F12 already refuses a call to a private function reached through `using` | `bs_check.erl:3646-3649` and `4188-4192` emit `{private_function, M, Name, Arity}`; builder `bs_diag.erl:358-360` | so an unmarked `RecomputeTotal/1` is unnameable from any other module | cited, not re-run |
| E16 | The aggregate-identity tag is minted from the qualified module path | ticket 22 MEASUREMENT section, item 3 ("record tag from the **qualified** module path, built as F3"); ticket 40 §1 decisions entry | moving a module renames its atom and its record tags | cited |
| E17 | One entry label per function, so per-caller export is impossible in the emitter | ticket 18 decisions entry: "a BEAM function has one entry label" | agrees with E1 and E11 | cited |
| E18 | The module's atom is its directory path, so subtree membership is an atom-prefix test | F15 ("`Shop/Orders` emits one `'Shop.Orders'.beam`"); `bs_check.erl:582-584` `children/2` already does the prefix test | | cited, not re-run |

**Contradiction with the working assumption.** The brief I was given expected Gleam to refuse an internal import. It does not (E8, E9). Gleam's `internal` is documentation and discovery hiding, not access control. The ticket itself does not claim otherwise, but the "closest neighbour enforces this" premise is false. What would have falsified my reading: `gleam build` exiting non-zero in either probe. The probe asserts the opposite and fails loudly if a later Gleam starts refusing. I could not reach gleam.run for the docs (proxy 403), so the probe output is the only source.

**Ticket 24's consumer is mostly gone (E15).** Ticket 24 §2 (2026-08-13) lists `RecomputeTotal/1` as `unclassified` because visibility was undecided and "every function in an aggregate is exported today". F12 (2026-08-17) made private the default. A helper nobody marked `public` is now unexported and refused from other modules with `private_function`. The test agent cannot reach it. What remains for ticket 60 is narrower: a function that is `public` so that its sibling modules can use it, but that the rest of the program should not name. I found no ticket or feature that records this narrowing. `grep unclassified` over `wayfinder/issues` and `compiler/features` hits only tickets 22, 24, 60 and F47 (an unrelated diagnostic tag).

## 3. Neighbour survey

- **Erlang.** No caller-side control. `-export` is global (E1); `-opaque` and `-export_type` bind only Dialyzer (not installed here, so not probed); `-deprecated` is advisory (E3). xref can compute violations after the fact against a hand-kept allow-list (E2), as a separate tool run. `-compile(nowarn_*)` silences warnings and has no bearing on access; the OTP application boundary is a packaging unit (the `modules` key of `.app`) and does not restrict calls. Neither was probed; I include them only to say they are not mechanisms. Erlang source (`xref.erl`) is not installed, only beams, so no line cites.
- **Elixir.** `@moduledoc false` hides docs only (E4). The compiler tracer API gives a genuine caller-side check (E5), documented in the installed `Code` module's docs chunk ("`{:remote_function, meta, module, name, arity}` ... traced whenever a remote function or macro is referenced"; reproduced by probe step (f)). It costs 20 lines and no measurable compile time (E7). It misses dynamic calls (E6). The Elixir `Boundary` library builds on this; it is not installed, so not probed. Elixir source is not installed (beams only).
- **Gleam.** `internal_modules` in `gleam.toml` is a list of path globs in package config, and `@internal` marks single items. Both are enforced only as hidden-from-interface (E8-E10). The name is the same word C# uses and the meaning is different: documentation hiding versus assembly access control.
- **Elm.** `exposed-modules` in `elm.json` should make non-exposed modules unimportable from other packages. **Not probed:** `elm make` needs `package.elm-lang.org` even for a one-package project and the proxy returns 403 ([`elm/run.sh`](probes/60/elm/run.sh) prints this and exits 0, claim unverified). Elm's unit is the package, and Elm has no shared-source-tree between packages, so it transplants less than the others.
- **C#.** `internal` / `InternalsVisibleTo`: **not probed** (no .NET here), not stated from memory. The ticket's own statement (assembly-scoped) is taken as the ticket's, not as verified.

**False friend, with evidence.** Gleam's `internal` hides from docs and does not refuse (E8-E10); the ticket records C#'s as assembly-scoped. Neither is "who may name this module in a directory tree". Borrowing the word would import one of two wrong meanings. The brief below spells nothing with `internal`.

## 4. Measurements

| What | Number | Command |
|---|---|---|
| Elixir caller-side check, source size | 20 non-blank lines | `grep -c . probes/60/elixir/tracer.exs` |
| Same check, compile-time cost on 30,000 remote-call events | no measurable difference (8.3-9.2 s either way) | `elixir/run.sh` step (d) |
| Gleam: internal module reachable from `erl` after build | yes, `42` | `gleam/run.sh` step (4) |
| `bsc` delta, estimated from the code read (not measured) | about 15 lines in `bs_check.erl` (one predicate, a call in `add_import`, a filter in `add_namespace_import`) plus one `bs_diag.erl` builder and one message clause beside `private_function` | read `bs_check.erl:490-526`, `bs_diag.erl:358` |

## 5. Options

The gating question as two programs. Placeholder spelling for the segment in A is `Inside`; spelling follows the decision and must not be `internal` (section 3).

### A. The unit is the subtree, and the path is the declaration. No new syntax.

```csharp
// Shop/Orders/Inside/Pricing/Recompute.bs
module Shop.Orders.Inside.Pricing;
public int Recompute(Order o)
Recompute(o) -> o.Lines |> List.Sum()

// Shop/Orders/Total.bs
module Shop.Orders;
using Shop.Orders.Inside.Pricing;      // ok: caller is under Shop.Orders
public int Total(Order o)
Total(o) -> Recompute(o)

// Shop/Reports/Daily.bs
module Shop.Reports;
using Shop.Orders.Inside.Pricing;      // error: Shop.Reports may not name
                                       //   Shop.Orders.Inside.Pricing (reserved to Shop.Orders)
```

A module whose path contains the reserved segment is nameable only from modules whose path starts with the segments before it. This is exactly the rule probe E5 enforces in Elixir, with the rule written into the compiler rather than a Mix option.

Compiles to: nothing new. `Recompute/1` is an ordinary export (E11, E17). Enforcement is `bsc` only; Erlang and Elixir callers bypass it, as ticket 22 already accepted for visibility.

Compiler delta (cited sites, work estimated):
1. `bs_check.erl:490` `add_import/7` gains, in the `true` branch, `ok = nameable(M, Self, L)` before `add_module_import`; `nameable/3` splits `atom_to_list(M)` at the reserved segment and does the same prefix test `children/2` (line 582) already does. It raises `erlang:error({not_nameable, M, Self, L})`, the same way the `unknown_module` error is raised at line 497.
2. `add_namespace_import/3` (line 519) filters `Children` through the same predicate (E14), otherwise the namespace door leaks.
3. `bs_diag.erl`: one `built/2` clause beside line 358 and one `message/1` clause. The message names the callee, the caller and the subtree that is allowed.
4. `reachable/2` (line 459) feeds `type_module_not_imported` hints and should drop non-nameable candidates so the compiler never suggests a `using` it will refuse.
5. A `World` change is **not** needed: `Self` and `M` are both module atoms in hand. No parser change, no new keyword, no new `World` field.

Strongest counterargument. The unit is fixed by the tree, so a legitimate second customer (`Shop.Billing` needs `Pricing`) forces a move. A move renames the module atom and therefore the record tags minted from it (E16), so the cure for one over-narrow rule is a cross-codebase rename. Also, a reserved path segment is a naming convention with teeth: a file placed under `Inside/` by accident silently narrows its audience.

### B. The unit is a list in the callee's header.

```csharp
// Shop/Orders/Pricing/Recompute.bs
module Shop.Orders.Pricing visible_to Shop.Orders, Shop.Billing;
public int Recompute(Order o)
Recompute(o) -> o.Lines |> List.Sum()

// Shop/Reports/Daily.bs
using Shop.Orders.Pricing;     // error: not in visible_to of Shop.Orders.Pricing
```

Compiles to: nothing new, same as A.

Compiler delta: grammar (`module_decl` gains an optional clause, one new keyword, and every `.bs` file of an aggregate must carry the same clause because F15 aggregates files into one module, so a disagreement between sibling files needs its own check, like `module_path_mismatch`); a `visible_to` field in each `World` entry built at `bsc.erl:227` and `:293`; the check in `add_import` as in A plus list membership; `add_namespace_import` filter; diagnostics as in A; a rule for what `visible_to Shop.Orders` means (that module only, or its subtree?), which brings back the unit question inside the list.

Strongest counterargument. An edit to the callee's header changes whether a caller in another directory compiles. Ticket 18's decisions entry refused analysis wider than one function because "an edit to one file silently moves another file's emitted boundary". This is the same shape: the blast radius of a header edit is the whole program. A name list of module paths also drifts from the tree on every rename, which is the drift F15's path check exists to stop.

### C. No language feature: a query over the compiled program.

The same check as an `xref`-style report (E2), consuming F17 (compiler query mode) output, run by CI. No change to `bs_check.erl`.

Strongest counterargument. Ticket 24's reader is an agent that runs the compiler in a loop and sees what the compiler prints. Probe E2 shows the Erlang answer requires a separate run and a hand-kept allow-list, and probe E8 shows that Gleam's equivalent (documentation-only `internal`) produces no signal at the moment the wrong import is written. A rule that only a separate tool states is a rule the loop does not meet.

## 6. Recommendation

**Option A, taken in two steps: decide the unit alone first.** The evidence for it: the rule is 20 lines in a neighbour with a working counter-example (E5), it adds no field to `World` and no syntax (E12-E14), and it uses information the compiler already holds because F15 made the path the module atom (E18). The checker cost is one predicate at the one door plus its sibling door (E14).

Do not decide the spelling in the same question. Of the four sub-decisions, 2 and 3 disappear under A, and 1 and 4 are answered. That leaves exactly one question for David: does a reserved path segment (and which word) serve, or does the first legitimate cross-subtree caller make the move cost (E16) too high?

**What would change my mind.**
1. A real exemplar needing a second customer outside the subtree, which would point to B.
2. Evidence that agents hit the F12-private default far less often than I think, which would make the whole ticket not worth a language feature (an option C world).
3. Evidence that the `public`-but-sibling-only case never occurs in the exemplar corpus. I did not search the `.bs` corpus for it, so I do not know. The narrowing of ticket 24's consumer (section 2) makes this the first thing to check before building anything.

## 7. Not verified here / limits

- `bsc` cannot be built here (its lexer needs OTP 26+ `leex`; no rebar3). Everything in E12-E15 and E18 is read from `bs_check.erl`, `bs_diag.erl` and F15, not run. Line numbers were re-verified by `grep` at `0dddf8b`; they differ from the ticket's `0b761f6` numbers.
- OTP 25 and Elixir 1.14 here, not OTP 28.5. The Erlang and Elixir probes show mechanisms that exist in both; tracer event names are from the 1.14 docs chunk and could differ in newer Elixir.
- Elm: not run (package fetch 403). C#: not probed. Dialyzer and the Elixir `Boundary` library: not installed, not probed. Gleam docs: unreachable; behaviour is from probe output only. Gleam's language server was not run, so I cannot say whether it hides internal modules from completion.
- Gleam probe used an explicit `internal_modules` in `gleam.toml`. I did not test the default (`<package>/internal`) separately.
- "A about 15 lines" in section 4 is an estimate from reading the code, not a measurement.
- No search of the `.bs` corpus for a `public`-but-sibling-only function was done.
