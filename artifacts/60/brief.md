# Decision brief: ticket 60, which modules may name this one (ENG-242)

Status of this file: a brief, not a decision. The ticket file, Linear and the repo's compiler are untouched. Everything under `artifacts/60/probes/` is reproducible with `probes/run_all.sh`.

## Question

A module controls what it exposes (`public`/`private`, F12) and nothing about who may name it. Ticket 60 asks four things: the unit of the rule, which side declares it, whether it is a third marker or a separate construct, and what it costs the checker. Measured first, the ticket's premise is weaker than it reads: the consumer it names is already served (E1), and the corpus has almost no demand (E9). What is left is one real, narrow program, a helper shared by sibling modules (E2), and the decision is whether to build anything for it.

## Sub-decisions, gating one first

1. **Is there a B# program worth writing that `private` plus the aggregate cannot express?** This gates everything. Probes say: for ticket 24's `RecomputeTotal/1`, no (P1). For a helper two sibling modules share, yes (P2). If David judges that second program too rare to pay for, the ticket closes with no construct (Option A) and the rest never gets asked.
2. **If yes: is the rule a fact about where a module sits (path), or a line the module writes (declaration)?** Options B and C. This one question settles the ticket's "unit", "marker or construct" and, together with P2's finding, "direction".
3. Follow-ons, settled by 2 and stated in the options: caller-side direction, per-function third marker. Both are argued against in "Not offered" below.

## Evidence

| # | Claim | Probe | Result | Status |
|---|---|---|---|---|
| E1 | Ticket 60 and 24 §2: an agent testing `RecomputeTotal/1` is a waiting consumer, the helper is `unclassified` | `p1_private_helper.sh` | **REFUTED for this case.** `private int RecomputeTotal` in its own file of the `Shop.Orders` aggregate is reachable from sibling `Apply` (`Apply(3)` = 7) and a test module in another directory is refused: `Test calls RecomputeTotal/1, which Shop.Orders declares private`. `--api` lists only `int Apply(int)`. 24 §2 was written 2026-08-13, F12 shipped 2026-08-17 and 60 (2026-08-23) did not re-read it | VERIFIED |
| E2 | A helper shared by two sibling modules cannot be `private`, so anyone can name it | `p2_shared_helper.sh` | `Shop.Ledger.Round` must be `public` for `Shop.Billing`; `Web.Checkout`, unrelated, also calls it and gets 101 | VERIFIED |
| E3 | `using` is the only door by which one B# module names another, so a check at the `using` line is a complete check for B# callers | `p2_shared_helper.sh` (third block) | `Shop.Ledger.Round(c)` with no `using` is refused: `Shop.Ledger is called but never imported` | VERIFIED |
| E4 | Ticket 18 §5 / 60: the emitter cannot hide a function from some callers, so the rule is a compile-time check "or nothing" | `p3_ffi_escape.sh` | Consistent, and sharper. A typed foreign block cannot even spell a B# function (`foreign_sig` takes a `lident`, B# names are `uident`, `bs_parser.yrl:178` vs `:306`; attempt 1 in `p3_ffi_escape.attempt1-failed.out`). But `:erlang.apply(:'Shop.Ledger', :'Round', [cents])` compiles with no `using` and runs (100). Any rule is advisory against a determined author. 18 §5's own measurement (`prototypes/18a`, OTP 28) was not re-run on this OTP 25 | VERIFIED (bypass); 18a UNVERIFIED here |
| E5 | F15: a directory of `.bs` files is a module, so `Shop/Orders/Internal/` is its own module beside `Shop.Orders` | `p4_nested_modules.sh` | Both compile to separate beams (`Shop.Orders.beam`, `Shop.Orders.Internal.beam`). Nothing stops sibling `Shop.Reports` from `using Shop.Orders.Internal` (`Peek(100)` = 10) | VERIFIED |
| E6 | The unit can be a subtree and the check fits at one site | `p5_option_b_prototype.sh`, `p6_...sh` | Prototype refuses `Shop.Reports` naming `Shop.Orders.Internal` and `Web.Checkout2` naming `Shop.Internal.Ledger`; accepts the owner and the intended sibling. Namespace-tier door (`using Shop` then `Internal.Ledger.Round`) shut by filtering children, see the wrong-advice caveat in Option B | VERIFIED (prototype only) |
| E7 | A declared list fits the same site | `p7_option_c_prototype.sh` | `friend Shop.Billing`, `friend Shop.Orders` in `Shop/Ledger/index.bs`: both named modules pass, `Web.Checkout` refused. yecc conflicts 6 before and after | VERIFIED (prototype only) |
| E8 | The check costs compile time | `p10_check_cost.sh` | No measurable cost. 15 runs each, stock median 367 ms vs 349 ms patched in the first run, 358 vs 412 in the second; VM boot dominates and noise exceeds the difference | VERIFIED (no signal) |
| E9 | There is demand in the corpus | `p8_corpus_census.py` | 102 `.bs` files, 63 modules, **5** `using` edges between corpus modules, 158 public functions of which 4 are named from another module. No program has the shared-helper shape. The corpus is single-aggregate programs, so this bounds present demand, it does not predict it | VERIFIED |
| E10 | Ticket: `add_module_import/5` reads only the callee's export set (`bs_check.erl:407-425`) | read | Line drift: it is `add_module_import/3` at `bs_check.erl:504`, and it reads `exports` and `types`. There is still no `internal`, `friend`, `sealed` or `visible_to` anywhere in `compiler/src` | VERIFIED (line cite stale) |
| E11 | The new diagnostic works on the JSON channel | `p11_option_b_json.sh` | **Could not run**: `json:encode` is OTP 27+ and this box has OTP 25 (`undef`). The map handed to it already has `parent` as a binary | UNVERIFIED |
| E12 | The query mode (`--api`) should or should not refuse a violation | `p5_...sh` last block | The prototype refuses in `--api` too (exit 1), because the check sits in the branch both modes take. Whether that is wanted is undecided, see risks | VERIFIED (behaviour), policy open |

## Survey of neighbours

Installed Erlang and Elixir ship beams only: there are no `.erl` or `.ex` sources under `/usr/lib/erlang` or `/usr/lib/elixir`, so **no file:line citations are available** and none are given. Behaviour below is what ran.

- **Erlang.** No caller restriction exists at all. `:erts_internal.cmp_term(1, 2)` called from user code returns -1 (`p9_elixir_erlang_internal.out`). Export is module-wide.
- **Elixir.** `@moduledoc false` hides a module from docs and nothing else: `Lib.Internal.Helper` is called by `Outsider` with no warning (`p9`). 36 of Elixir's own 253 `:elixir` modules carry it. The convention is wide and unenforced.
- **Gleam 1.12.0.** `internal` is also docs-and-interface hiding and **not enforcement**. Another package imports `lib/internal/helper` and calls an `@internal` function, `gleam build` exits 0 with no warning; the package interface omits both (`gleam_internal.out`, blocks A and D). Caveat: block C (explicit `internal_modules`) printed `Compiled in 0.00s`, so it may have been served from cache; A is the evidence. The `@internal` and `internal_modules` spellings themselves are taken from the compiler's behaviour, not a doc page (docs not installed).
- **Elm.** Not available. `elm init` needs packages from the network and fails through the proxy. `exposed-modules` in `elm.json` is a package-level list, but that is recalled, not verified, and is not evidenced here.
- **Go (`internal/`), C# (`internal`, `InternalsVisibleTo`), C++ (`friend`).** No toolchain installed, not surveyed. Ticket 22's warning that C#'s `internal` is assembly-scoped is taken from the ticket, not re-measured.

What was measured: all three BEAM-family languages surveyed (Erlang, Elixir, Gleam) let the compiler accept the call, and two hide internals from documentation. The only enforced design in this brief is one B# would be the first of them to build.

## Measurements

- Diff size of the two prototypes, against stock `compiler/src`: **B** +32/-2 lines, two files (`bs_check.erl`, `bs_diag.erl`), no grammar change. **C** +33/-4 lines, five files (lexer keyword, yecc production and terminal, `bsc.erl` world entry, `bs_check.erl`, `bs_diag.erl`). Patches: `probes/option_b.patch`, `probes/option_c.patch`.
- Generated code: identical. Neither option changes a `.beam`; the rule is erased at compile time (E1, P1 export lists unchanged).
- Compile time: no signal (E8).
- Not measured: the repo's own suite against either prototype (no `rebar3`; suite not run). Stock build is a hand build with a lexer deviation: OTP 25 `leex` has no `TokenLoc`, so every column prints as 1. Nothing here depends on a column.

## Options

### Option A: build nothing; close with a correction

```csharp
// Shop/Orders/RecomputeTotal.bs      one function per file, aggregate Shop.Orders
module Shop.Orders
private int RecomputeTotal(int total)
RecomputeTotal(total) -> total * 2
```

- **Compiled form:** as today. `private` is unexported (E1).
- **Compiler delta:** none. The ticket records that 24 §2's `unclassified` is discharged by F12 and that the shared-helper shape has no program (E9).
- **What it leaves:** E2. A shared helper is public to the world. The honest mitigation today is to not split that helper out.
- **Strongest counterargument:** the ticket exists because the gap will arrive with the first real multi-module system, and by then renaming a path or adding a declaration touches many files. A cheap rule now is cheaper than a rule after 50 modules depend on an open helper. E9 cannot answer this: the corpus has not reached multi-module code yet.

### Option B: a path rule, no declaration

A module whose dotted path has an `Internal` segment may be named only by modules at or under that segment's parent. Go's `internal/` rule, unit = subtree, callee-side, enforced at `using`.

```csharp
// Shop/Internal/Ledger/Round.bs
module Shop.Internal.Ledger
public int Round(int cents)
Round(cents) -> cents - cents % 5

// Shop/Billing2/Bill.bs        under Shop: accepted
module Shop.Billing2
using Shop.Internal.Ledger
public int Bill(int cents)
Bill(cents) -> Round(cents)

// Web/Checkout2/C.bs           outside Shop: refused
module Web.Checkout2
using Shop.Internal.Ledger
//  error: Web.Checkout2 cannot name Shop.Internal.Ledger
//    a module under an `Internal` directory may be named only by modules under Shop.
```

- **Compiled form:** unchanged beams. `Shop.Internal.Ledger.beam` still exports `Round/1` (E1 pattern); the refusal is at the caller's check (E6).
- **Compiler delta (from `option_b.patch`, what actually had to change):**
  1. `internal_parent/1` and `allowed/2`, 14 lines in `bs_check.erl`.
  2. `may_name/3` called from `add_import/7` in the module branch (`bs_check.erl:~494`), and a child filter in the namespace branch, or `using Shop` re-opens the door.
  3. One new tag `internal_module` in `bs_diag` (`built/2` and `message/1`).
  4. **Owed but not prototyped:** tests, a `diagnoses:` block in `LANGUAGE.md`, the F-file, and a JSON-wire check of the tag (E11, could not run here).
- **Measured evidence:** E5, E6, E8.
- **Costs specific to B:**
  - `Internal` becomes a segment with a meaning. B# reserves no name today (ticket 65 is open); this spends one, in a position no one has to have written yet.
  - A module's identity is its path, so making a helper internal is a directory move and a module rename, and every caller's `using` changes (the atom `'Shop.Internal.Ledger'` is the tag prefix of its records too, 26 §1).
  - The word is C#'s, with Go's meaning. Ticket 22's false-friend rule says refuse a word whose meaning is adjacent but wrong. A C# reader expects assembly scope. This is the exact trap 22 named, unless the word is something else (`Private`, `Local`), which costs the borrowed recognition.
  - Wrong advice, found by probing: through the namespace door the refusal reads `Internal.Ledger is called but never imported; add using Internal.Ledger`, advice that leads to another refusal (`p6` third block).
- **STRONGEST COUNTERARGUMENT:** the rule is stated by a directory name, so a reader of `Bill.bs` learns nothing from the file itself, and an agent that "fixes" a refusal by renaming `Internal/` to `Shared/` removes the protection and every test passes. A rule that can be defeated by a rename was a convention with a checker attached.

### Option C: a declaration in the callee

The helper module lists who may name it. Silent means open; one or more `friend` lines mean closed to everyone not at or under a named module.

```csharp
// Shop/Ledger/index.bs
module Shop.Ledger
friend Shop.Billing
friend Shop.Orders

// Shop/Ledger/Round.bs
module Shop.Ledger
public int Round(int cents)
Round(cents) -> cents - cents % 5

// Web/Checkout/C.bs            refused
//  error: Web.Checkout cannot name Shop.Ledger
//    Shop.Ledger declares `friend Shop.Billing, Shop.Orders`, so only those modules and the modules under them may.
```

- **Compiled form:** unchanged beams.
- **Compiler delta (from `option_c.patch`):**
  1. Lexer: `friend : {token, {'friend', TokenLoc}}`; this **takes the word out of identifier position** (`friend` is a legal lowercase name today), so it is a ticket 65 decision by another route.
  2. Parser: terminal `'friend'`, nonterminal `friend_decl`, `decl -> friend_decl`. Conflicts measured 6 before and 6 after.
  3. `bsc.erl`: world entry gains `friends`; a dependent reads it at `using`.
  4. `bs_check.erl`: `allowed/3`, `may_name/4`, namespace child filter. `bs_diag.erl`: one tag.
  5. **Owed, not prototyped:** `bs_api` surface for the declaration (does `--api` list friends?), a walker audit, since F34 found that adding a node to the grammar can reach a silent catch-all in `bs_emit:used_vars/2` and `bs_check:expr_vars/1` (here the node is a module-level decl so it probably stays out of expression walkers, but no test has run), tests, LANGUAGE.md, the F-file.
- **Measured evidence:** E7, E8.
- **Costs specific to C:**
  - **Every new caller edits another module's `index.bs`.** Adding `Shop.Reports` to the friends of `Shop.Ledger` is a write outside the caller's own file. One function per file plus `write_scope` is the agent story (F15); this is a cross-file edit an agent must know to make, and the refusal message has to tell it where. The probe's diagnostic names the list but not the file to edit.
  - `friend Shop.Billing` names modules by path, so a rename of `Shop.Billing` breaks a line in another module with no compiler help unless unknown friends are refused (not prototyped: an unknown name is currently silently accepted).
- **STRONGEST COUNTERARGUMENT:** a friend list is a second copy of the `using` graph, and it goes stale in exactly the direction that is hard to see. The callee's list grows to `friend Shop`, which is Option B's rule with more typing.

### Not offered (argued, not probed)

- **Caller-side direction** ("this module declares what it depends on", closer to `using`). A rule written by the caller restricts only callers that opt in; `Web.Checkout` in P2 has no declaration and would be unrestricted, so it protects nothing against the module it exists to exclude. It is an architecture-lint (layering) feature, not a visibility feature. Reasoned from E2, no probe.
- **A third per-function marker** (`internal int Round(...)`). The BEAM exports a function to every caller or none (E4, P3); the marker would need its own per-function table beside `privates` (`bs_check.erl:4260-4272`), and its list of grantees is per-module information repeated per function. No probe: the conclusion rests on E4.

## Recommendation

**Option A now.** Reasoning, in order:

1. The consumer the ticket names is already served (E1, REFUTED). F12 made `RecomputeTotal` a `private` file in the aggregate, and a test cannot name it.
2. The one shape that remains (E2) has zero instances in a 63-module corpus (E9), and the neighbours that tried this either stop at docs (Elixir, Gleam, see Survey) or are unsurveyed here. Building a checker for a program nobody has written is the pattern CLAUDE.md warns about for gates.
3. The decision costs little later. The prototypes show B is 32 lines at one site and C is 33 across five, and the site (`add_import`, E3) is the only door. Waiting does not raise the price of the build; it only raises the price of migrating callers, which E9 says is currently five edges.

**If David wants the rule now, Option B, with two changes to the prototype:** refuse the namespace-door advice `add using Internal.Ledger`, and pick the segment word knowing it is 22's false-friend trap. I prefer B to C because C's cost lands on the file the agent is not editing, and because B adds no keyword. The ticket should record that neither blocks the other: `friend` can be added later over B without breaking a B program.

## Open risks

- **Tests.** A test module under the same subtree passes the rule. If tests live inside `Shop.Orders` (24's layout question is still open), the rule admits a test naming an `Internal` helper, which is the drift the ticket wants to stop. The rule only holds if tests sit outside the protected subtree. Not probed.
- **The FFI bypass is permanent (E4).** `:erlang.apply` ignores any of these rules, and Erlang/Elixir callers ignore them by design. The claim to make is "B# code cannot name it by accident", not "cannot name it".
- **`--api` refuses too (E12).** 22 decided `--api` answers for a half-written module. Whether it should answer for a module that violates visibility is a separate small decision.
- **JSON wire unverified (E11).** OTP 25 here, `json` module needs 27+. Run `p11_option_b_json.sh` on the pinned OTP 28.5 before believing the tag is wire-safe.
- **Hand build, not the suite.** No `rebar3`, and the stock compiler here is built without columns. The prototypes were not run against `rebar3 eunit`, so regressions in existing tests are unmeasured.
- **Ticket 65.** Options B and C both take a word out of the language. That is a named, open policy question, not something these prototypes can close.

## Reproduce

From a clean shell, repo root `/home/user/beam-sharp`, OTP 25, Elixir 1.14, gleam at `/tmp/tools/gleam`, python3:

```
artifacts/60/probes/run_all.sh          # builds compiler/src into /tmp/bsc-build-60, reruns all, rewrites every .out
```

Individually (after `probes/build_bsc.sh /tmp/bsc-build-60`):

```
artifacts/60/probes/p1_private_helper.sh                  # E1
artifacts/60/probes/p2_shared_helper.sh                   # E2, E3
artifacts/60/probes/p3_ffi_escape.sh                      # E4
artifacts/60/probes/p4_nested_modules.sh                  # E5
artifacts/60/probes/p5_option_b_prototype.sh              # E6, E12; also writes option_b.patch
artifacts/60/probes/p6_shared_helper_under_option_b.sh    # E6
artifacts/60/probes/p7_option_c_prototype.sh              # E7; also writes option_c.patch
artifacts/60/probes/p10_check_cost.sh                     # E8
python3 artifacts/60/probes/p8_corpus_census.py           # E9
elixir  artifacts/60/probes/p9_elixir_erlang_internal.exs # survey
artifacts/60/probes/gleam_internal.sh                     # survey
artifacts/60/probes/p11_option_b_json.sh                  # E11, fails on OTP < 27 (kept, labelled)
```

Failed attempts kept, per the honesty rule: `p3_ffi_escape.attempt1-failed.out` (typed foreign block cannot name a B# function), `p6.attempt1-fixture-polluted.out` (an unrelated violating module in the source root broke the namespace-door probe), `p9.attempt1-failed.{exs,out}` (docs chunk of a script-defined module).
