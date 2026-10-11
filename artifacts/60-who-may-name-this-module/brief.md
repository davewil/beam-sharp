# Decision brief: ticket 60 (ENG-242), "Which modules may name this one?"

| | |
|---|---|
| Ticket | 60 / ENG-242, `wayfinder/issues/60-which-modules-may-name-this-one.md` |
| Status | **OPEN, undecided.** This brief is a recommendation. Nothing under `wayfinder/` or Linear was touched. |
| Date | 2026-10-11 |
| Repo | `compiler/src` measured at `019533d` (HEAD is now `8e180cc`; `git diff 019533d HEAD -- compiler/src` is empty) |
| Toolchain | OTP 29 (Elixir 1.20.4 was built against OTP 27), Gleam 1.19.1, Elm 0.19.0 (could not run, see 7), Go 1.24.7, rustc 1.97.0 |
| Probes | `probes/` (one command each, `probes/README.md`); prototype diffs in `patches/` |

---

## 0. What the ticket gets wrong, up front

1. **"`add_module_import` is the site" is wrong twice.** It is no longer `/5` at lines 407-425: at
   `019533d` it is `add_module_import/3` at `bs_check.erl:512-525`. More importantly it is **one of four
   doors** by which a module names another, and a check there alone leaves three open (probe `a_checker_today.sh`,
   sections 3-5, and the prototype's `Ty`/`Ns` cases):
   - `using Shop.Orders` -> `add_import/7` (498) -> `add_module_import/3` (512). Reads the callee's exports.
   - `using Shop` (a namespace) -> `add_namespace_import/3` (527). **Reads no export set at all.** It puts every child in `mods`/`imported`, so `Orders.RecomputeTotal(n)` resolves. Probe: `Ns` compiles clean today.
   - a qualified call -> `qualified_module/3` (4420) -> `require_imported/3` (4428), which only asks "did a `using` mention it".
   - a **type name**, `Shop.Orders.Thing` in a signature -> `imported_types/2` (1307) builds a fully-qualified entry for **every module in the build's `World`**, not only the ones the file `using`s. A module that merely sits in the dependency closure can be named in type position with no `using` of its own. Probe: `Ty` (reaches `Shop.Orders` through `Shop.Reports`) compiles clean today; `Ty3` (no path to it) is refused with "never imported".
2. **Ticket 24 sec.2's premise is stale, and it was stale before ticket 60 was filed.** 24 (resolved 2026-08-13) says "every function in an aggregate is exported today". F12 landed 2026-08-17 and the same day made **private the default**. At HEAD the `RecomputeTotal` helper the ticket worries about is **not nameable** from another module unless somebody writes `public` (probe `f_unclassified_helper.sh` case 1). The `unclassified` bucket as 24 defined it is mostly empty already.
3. **The remaining leak is the diagnostic, not the language.** The F12 refusal reads: "Mark it `public` in Cart, or move the call inside it." (probe f, case 1). An agent in a loop takes the first clause; probe f case 3 shows the test then compiles. The guardrail is one edit wide, and the compiler hands over the edit.
4. **Two leaks no visibility construct can reach**, both measured: (a) a behaviour callback must be `public` (F12's `private_callback` check, `bs_check.erl:297`), so a test can call `HandleCall` directly today (probe f case 2: `(:reply, 7, 7)`); (b) a test **file** placed inside the module's directory and declaring the module's name *is* the module (F15), so it reaches `private` functions and **ships inside the production `.beam`** (probe f case 4: exports `TestRecompute/1`). Where tests live is still open (`40-module-and-namespace-system.md:438`, `24-testing-story.md:402`) and no ticket owns it. Any rule in this ticket is moot against (b).

---

## 1. The sub-decisions, in dependency order

**Q1 (gates everything). Does a public function ever need an audience narrower than "every module"?**
Everything else only matters if yes. See 6 for why I answer "not yet".

Follow-ons, asked only if Q1 is yes:
- Q2 the unit (subtree / explicit list / named group). Q3 direction. Q4 separate construct or a third marker. Q5 checker cost.

Q3 is settled by the ticket's own consumer and I do not offer it as a choice. *Caller-declared* ("this module may name only X") restricts a module by the module's own consent, and the module under restriction is exactly the test an agent writes. `using` already is the caller's declaration of what it depends on, and it restricts nothing (probe a, `Elsewhere` section 3). So the rule has to sit with the **callee**. (A caller-side *layering* rule, "this module may name only the client API", is a different feature, and would need the callee-side knowledge Q1 asks about. Not prototyped.)

Q4 is answered by the code (section 5, "third marker"): a marker on the signature is read in seven places and has to encode a subtree argument; a module-level rule is read in one.

---

## 2. Claim ledger

| # | Claim | Probe | Result |
|---|---|---|---|
| 1 | `add_module_import/5` at `bs_check.erl:407-425` reads only the callee's export set | `a_checker_today.sh` s.2 | **Partly.** Now `/3` at 512-525; true that it reads exports only, but it is 1 of 4 doors (0, item 1) |
| 2 | No `internal`/`friend`/`sealed`/`visible_to` in the checker | `a_checker_today.sh` s.1 | **Confirmed.** `internal` has 2 hits in `bs_check.erl`, both comments (188, 4928); `friend` etc. 0 in lexer, parser, checker; control `private` hits all three |
| 3 | A module can name any other module's public function | `a_checker_today.sh` s.3 | **Confirmed.** `Elsewhere` (unrelated, top level) compiles and links `Shop.Orders.RecomputeTotal` |
| 4 | `internal` as a modifier | `a_checker_today.sh` s.7 | **Refused with the wrong remark:** `Kw/Kw.bs:3:10: error: syntax error before: int`. It names the token after the unknown word (F7's costume), not `internal` |
| 5 | The `what` half is enforced (control) | `a_checker_today.sh` s.6 | **Confirmed.** `Poke calls Hidden/1, which Shop.Orders declares `private`` |
| 6 | Qualified call needs a `using` | `a_checker_today.sh` s.4 | **Confirmed**, but a *namespace* `using` satisfies it (s.5) |
| 7 | Ticket 24 sec.2: helper lands `unclassified`, tests will target it | `f_unclassified_helper.sh` 1, 3 | **Refuted at HEAD for non-callbacks.** Private is the default; test module is refused. Control (case 3): make it `public` and the same test compiles |
| 8 | Ticket 24: callbacks are not a test target | `f_unclassified_helper.sh` 2 | **Not enforced.** `HandleCall` is public and a test names it (`(:reply, 7, 7)`) |
| 9 | 22/60: per-function export control is not cheap, so enforcement is caller-side | `e_emit_unchanged.sh` | **Confirmed.** `bs_emit.erl:35,141` has one `Exports` list. With the friend rule, `Shop.Reports.abstr` is byte-identical to the unmodified compiler's; `Shop.Orders.abstr` differs only by one file attribute for the extra source file |
| 10 | C# `internal` is assembly-scoped, B# has no assembly | not probed (no C# toolchain, per brief) | Ticket 22 says only that the useful notion is "a different feature from C#'s `internal`" that "should not borrow its spelling without borrowing its semantics" (`22-how-opinionated.md:434-435`); the "assembly-scoped" gloss is ticket 60's own and was not verified here. Rust and Go below show the two shapes that *do* fit a directory tree |
| 11 | Gleam enforces `@internal`/`internal_modules` | `gleam_internal.sh` | **Refuted.** Not enforced at compile time (3.1) |
| 12 | Elixir `@doc false` / `@moduledoc false` / `@deprecated` restrict callers | `elixir_probe.sh` | **Refuted.** `@doc false` call: clean. `@deprecated`: a warning. Even `defp` from another module is only a *warning* (3.2) |
| 13 | OTP can state "only X may call Y" | `erlang_xref.sh` | **Partly.** As a post-build xref query, not a compile check (3.3) |
| 14 | Elm `exposing` / `exposed-modules` | `elm_probe.sh` | **Not observed.** Package server blocked (3.4) |

---

## 3. Neighbour survey

Real source was read only for Erlang (xref, erl_lint). Gleam, Elixir and Elm are binaries or `.beam`-only in this environment, so for them **the citation is a probe run of the real compiler** (command and verbatim output below); no source line is cited.

### 3.1 Gleam 1.19.1: hidden, not forbidden (`probes/gleam_internal.sh`)

Two packages, `app` -> `lib` by path dependency (hex is unreachable, so both have zero dependencies). `lib` has `lib/internal/secret.gleam`, an `@internal pub fn attr_internal`, and an `@internal pub type HiddenType`. `app` imports `lib/internal/secret` and calls `lib.attr_internal(2)`:

```
### 1. app (other package) imports lib/internal/secret and calls @internal lib.attr_internal
  Compiling lib
...
   Compiled in 0.45s
gleam build exit=0
app:main() = 16  (5*2 + 2*3 = 16 means BOTH the internal module and @internal fn were reached)
### 2. what the package interface (docs/tooling) shows of lib
module lib functions ['public_api'] types ['Visible']
module lib/helper functions ['via_helper'] types []
NOT listed: module lib/internal/secret, fn attr_internal, type HiddenType
### 3. explicit internal_modules in gleam.toml, other package still imports it?
   Compiled in 0.54s
exit=0
### 4. NEGATIVE CONTROL: the compiler DOES enforce a non-pub function
error: Unknown module value
4 │   helper.really_private(1)
The module `lib/helper` does not have a `really_private` value.
exit=1
```

Not enforced at compile time, in either spelling, with the default `internal_modules` or an explicit one. What Gleam does is **omit** the module/function/type from `gleam export package-interface` (and, per its docs, from generated documentation, which was not run). I did not run the language server, so completion/hover behaviour is unobserved. Gleam gives B# a *subtree convention with no enforcement*; ticket 60 would be the enforced version.

### 3.2 Elixir 1.20.4: documentation-level only, plus a hook (`probes/elixir_probe.sh`)

```
### 1. Elsewhere calls Shop.Orders.recompute_total (@doc false in a @moduledoc false module) and old_total (@deprecated)
    warning: Shop.Orders.old_total/1 is deprecated. use apply_order/1
exit=0
### 3. defp across modules
    warning: Shop.Orders.hidden/1 is undefined or private
exit=0  <- a WARNING, the build succeeds
** (UndefinedFunctionError) function Shop.Orders.hidden/1 is undefined or private
--- escalated with --warnings-as-errors:
Compilation failed due to warnings while using the --warnings-as-errors option
### 4. ... @compile {:no_warn_undefined, Not.Defined}  ->  0 'undefined' lines   (it only silences the missing-module warning)
```

- `@doc false` / `@moduledoc false`: **not enforced**, no diagnostic at all.
- `@deprecated`: a warning at the call site; the build passes.
- Calling a `defp` from another module is, in Elixir, **a warning and a run-time `UndefinedFunctionError`**. B# is already stronger than Elixir here (`private_function` is a hard error).
- `mix xref callers Shop.Orders` lists the callers (`lib/elsewhere.ex (runtime)`, `lib/reports.ex (runtime)`): a report, exit 0.
- **The compiler offers a hook and no rule.** `elixirc_options: [tracers: [...]]` calls a module on every `:remote_function`. An about-25-line tracer (`probes/elixir/mix_tracer.exs.txt`) turns a table `%{Shop.Orders => [Shop.Reports]}` into a compile error:
  ```
  ** (CompileError) lib/elsewhere.ex:3: Elsewhere may not call Shop.Orders.recompute_total/1; friends: [Shop.Reports]
  ```
  and with the offender removed the friend alone compiles (exit 0). So Elixir's answer to "who may name me" is *not in the language*; it is a tracer in the build. That is the Boundary library's mechanism; I could not read it (hex blocked), so that attribution is from the hook's design, not from its source.

### 3.3 Erlang/OTP 29: the question is answerable, as a post-build query (`probes/erlang_xref.sh`)

- `-export` is the only gate, and `erlc` never checks a cross-module call: `elsewhere.erl` calls the unexported `shop_orders:hidden/1`, `erlc` prints nothing, and the run-time result is `{'EXIT',{undef,[{shop_orders,hidden,[1],[]},...`.
- `-compile(export_all)` warns: `exportall.erl:2:2: Warning: export_all flag enabled - all functions will be exported` (`erl_lint.erl:357-358`, `1087-1088`).
- xref answers both halves. `xref:analyze(S, undefined_function_calls)` finds the call `erlc` missed (`analysis(undefined_function_calls, functions) -> "(XC - UC) || (XU - X - B)"`, `xref_base.erl:402-403`). `xref:q(S, "XC")` returns every call edge, and ten lines of Erlang over it give "only X may call Y":
  ```
  friends(shop_orders)=[shop_reports] -> violations: [{{elsewhere,poke,1},{shop_orders,recompute_total,1}},
                                                      {{elsewhere,poke_hidden,1},{shop_orders,hidden,1}}]
  CONTROL friends(shop_orders)=[shop_reports,elsewhere] -> violations: []
  ```
  `{module_use, M}` (`xref_base.erl:428-429`) lists the modules that use `M`.
- Not part of `erlc`; a separate tool nobody must run. This is the shape ticket 21 already rejected for B# ("the one precedent that needed a second tool in the build ... was simply not run", `22-how-opinionated.md:422-424`).
- OTP 29's `erl_lint` has `nominal` types (line 1199) and nothing named `private`/`internal`/`friend`; I grepped, not exhaustively.

### 3.4 Elm 0.19.0: not observed

`elm make` needs `elm/core` from `package.elm-lang.org`; the proxy returns 403 (`probes/elm_probe.out`). Nothing about `exposing` or `exposed-modules` was observed here and I assert nothing about them. (An `exposing` list is *what* a module exposes, the same half F12 already ships, so the gap would not have changed the analysis.)

### 3.5 Two precedents that do fit a directory tree (extra probes, both installed)

- **Go `internal/`**, the direct precedent for a path convention with no syntax (`probes/go_internal.sh`, Go 1.24.7):
  ```
  --- orders/total (a descendant of orders/) imports orders/internal/pricing: expect OK        exit=0
  --- reports (a sibling subtree) imports it:
  	shop/reports/reports.go:3:8: use of internal package example.com/shop/shop/orders/internal/pricing not allowed
  exit=1
  ```
- **Rust `pub(in crate::shop)`**, a per-item marker carrying a subtree (`probes/rust_pub_in.sh`, rustc 1.97.0):
  ```
  error[E0603]: function `recompute_total` is private
   12 | ... crate::shop::orders::recompute_total(n)
  note: the function `recompute_total` is defined here
   4 | pub(in crate::shop) fn recompute_total(n: i32) -> i32 { n * 2 }
  ```
  (control, the same file without the outside caller: `exit=0`). Rust reports it as "private": the per-item form is easy to misreport.

The two shapes are the two options below.

---

## 4. Measurements

Prototype compilers are scratch copies of `compiler/src` (never edited in place), built by `probes/e_build.sh`; patches in `patches/`.

| Variant | What it is | Diff vs HEAD (lines added / removed) | Files |
|---|---|---|---|
| A | callee lists friends: `friend Shop.Reports` / `friend Shop.Reports.*` | 64 / 8 non-blank (71 / 9 with blanks; B 61 / 6, C 11 / 4) | `bs_check` 44, `bs_diag` 13, `bs_parser.yrl` 5, `bs_lexer.xrl` 1, `bsc.erl` 1 |
| B | path convention: an `Internal` segment | 57 / 6 | `bs_check` 44, `bs_diag` 13 |
| C | behaviour callbacks unnameable from other modules | 10 / 4 | `bs_check` only |

(A and B share the same ~50 lines of plumbing: the four doors, a `denied` table, one diagnostic. A adds the keyword, a grammar rule and a World field. `bs_parser.yrl` still reports `6 shift/reduce`, the same count as HEAD, so the new `friend` rule adds no conflict.)

**Compile-time cost** (`probes/e_cost.out`, 4-CPU shared box, so noisy). Warm: 8 interleaved rounds x 10 timed compiles of `examples/Shop/Reports` after 5 warm-ups, a fresh VM per build per round, n=80 per build, microseconds:

```
base  median=12727 min=10436 p10=10819 p90=20862 max=37763
A     median=15031 min=10379 p10=10664 p90=28675 max=48438
B     median=12919 min=10675 p10=11033 p90=28222 max=96904
C     median=14328 min=10292 p10=11187 p90=32134 max=83123
```
Cold (30 separate `bsc` launches each, ms): base 354, A 358, B 355, C 400 (medians; spreads overlap). **The differences are inside the machine's noise** (an earlier non-interleaved run had C at twice base and B below it); the floors (min, p10) are indistinguishable across all four. Direct measurement of the predicate alone (`probes/e_micro.out`, 21 x 10^6 calls): A with no friend list 11.5 ns/call (control empty fun 10.2); A with two friends 31 ns listed, 153 ns refused; B 450 ns with no `Internal` segment, about 1 us when there is one (it splits the module name). A module with ten `using` lines pays at most ~10 us against a ~12,700 us compile: under 0.1%. Neither is a reason to choose.

**Regression sweep** (`e_cost.out`): all 28 module directories under `compiler/examples` compile in all four builds (0 failures, same as HEAD). The sweep excludes `compiler/examples/exemplars/` (46 files, 4 of the 8 cross-module `using`s) and contains no `friend` or `Internal` module, so it shows no regression only where the rule is inactive. **Verifier corrections to the cost section:** an interleaved re-run had A and C about 10% *below* base where the author's had them 13-18% above; that sign flip means the whole-compile timings are noise and must not be quoted as an effect. Any 'ten usings cost at most ~10 us' reading scales wrongly: `type_gate` walks every module in `World` per file, so cost is O(World), about 12 ns per module for A and 370 ns per module for B, roughly 3% of a compile at 1000 modules. The eunit suite (`rebar3 eunit`) was **not run**: there is no rebar3 here.

**Emitted code** (`e_emit_unchanged.out`): unchanged for the caller; the callee's abstract code differs by one file attribute (the new source file). `.beam` bytes are not reproducible between two identical compiles (the control prints different md5s), so the comparison is on `.abstr`.

**Demand in the corpus** (grep): `compiler/examples` (exemplars included) has 75 `.bs` files with 8 `using <Module>` lines in total, 4 of them in the 46 exemplar files; `aoc` has 3 files and none. (The wider `find . -name '*.bs'` count of 3,495 is dominated by test fixtures and is not evidence of demand.) No program in the corpus has a public function whose callers should be a subset of its importers.

---

## 5. Options

Each is a realistic program, the compiler delta, the evidence, and the strongest counterargument. Q1 comes first, so the first option is "no construct".

### Option 0. No new construct. Close the two small leaks.

```csharp
// Shop/Orders/Orders.bs
module Shop.Orders
public int Apply(int n)
Apply(n) -> RecomputeTotal(n) + 1
private int RecomputeTotal(int n)       // already the default
RecomputeTotal(n) -> n * 2
```
```csharp
// ShopTests/Orders.bs  (a test module outside the directory)
using Shop.Orders
public int T(int n)
T(n) -> RecomputeTotal(n)               // REFUSED today
```
Probe f, verbatim: `CartTest/CartTest.bs:7:19: error: TestsHelper calls Recompute/1, which Cart declares `private``. The ticket-24 helper case is served by F12.

Compiler delta, both optional and small:
- **Callbacks unnameable** (variant C, 10 lines in `bs_check`): `qual_table/1` and `add_module_import/3` skip names for which `bs_otp:callback_name/3` is not `none`, and `private_table/1` lists them. Result: `CartTest2` (the callback-naming test) is refused; `Cart` still compiles and its client API runs (`Total 6` -> `6`); `--api` still lists the callbacks. **Gap:** it reuses the `private_function` message, which says "Mark it `public` in Cart", false for a callback that already is public and must stay so. It needs its own diagnostic (`bs_diag`, ~8 lines, not written).
- **Reword the F12 refusal** so "mark it `public`" is not the first offer. One string in `bs_diag.erl:1349-1353`. This is the cheapest guardrail in the brief and touches no checker logic. (Whether the wording is David's call: it is a diagnostic, not a decision.)

Strongest counterargument: C contradicts the carve-out in 24 sec.1, "a genuinely complex operation whose edge the client API cannot reach" may be unit-tested through the callback. A hard refusal removes that carve-out for callbacks with no escape. Also: Option 0 does nothing for a *public* helper a sibling module needs.

### Option A. The callee lists its friends (a module-level `friend`).

```csharp
// Shop/Orders/Friends.bs   (any file of the module; index.bs is the natural home)
module Shop.Orders
friend Shop.Reports           // exact module
friend Shop.Admin.*           // a subtree

public int RecomputeTotal(int n)
RecomputeTotal(n) -> n * 2
```
Compiles: `Shop.Reports`, `Shop.Orders` itself. Refused (variant A, `e_prototype.out`, verbatim):
```
Other/Other.bs:3:1: error: Shop.Orders may not be named from this module
  Shop.Orders lists who may name it: Shop.Reports
  add this module to its `friend` list, or move the call to one that is listed.
Ns/Ns.bs:6:18: ...  (the same, through `using Shop` and `Orders.RecomputeTotal`)
Ty/Ty.bs:5:12: error: Shop.Orders.Thing names Shop.Orders, and Shop.Orders lists who may name it: Shop.Reports
```
Under the unmodified compiler all of these compile clean (control in the same output).

Compiler delta (concrete):
- `bs_lexer.xrl`: `friend` token (1 line). `bs_parser.yrl`: `friend_decl -> 'friend' modpath | 'friend' modpath '.' '*'`, AST `{friend, Line, Mod, exact|subtree}` (5 lines; conflicts unchanged at 6).
- `bsc.erl`: World entry gains `friends => bs_check:friends_of(Decls)` (1 line).
- `bs_check.erl`: `allowed/3`, called at the four doors: `may_name/5` in `add_import/7`; `nameable/4` filtering children in `add_namespace_import/3` and recording a `denied` map; `require_imported/3` consulting it; `type_gate/3` in `imported_types/2` returning a `{denied, M, Why}` marker that `resolve` turns into an error. Applies only in `strict` mode, so `--api` still lists everything.
- `bs_diag.erl`: two tags (`not_a_friend`, `denied_type`), `built` + `message` each.

Evidence: the three negative controls above, the positive control (`Shop/Reports` clean), the regression sweep, the cost numbers, and that the caller's emitted code is unchanged.

**Known gap, measured, not fixed:** a type named through a *namespace* `using` is refused with the wrong remark:
```
TyNs/TyNs.bs:5:12: error: Shop.Orders declares no type named Thing
  a qualified type is spelled as the module that declares it spells
  it: a `record` or `type` line in Shop.Orders.
```
(`hinted/2`, `bs_check.erl:441-457`, sees only `World`, not the denied set.) This is F12's own finding repeated: filtering at table construction turns "refused" into "absent". The fix is the second table F12 built, about 10 more lines; the prototype leaves it out. Constructor and pattern positions for a denied record were not probed separately.

Strongest counterargument: it spends a keyword. Ticket 22 closed on "the sixteenth keyword is not spent", and the parser's `decl` alternation has no bracket-shaped escape (`22-how-opinionated.md:91-93`); there are no attributes to hang this on. And it is a second source of truth for the dependency graph: `using` on the caller, `friend` on the callee, which must agree (the drift `bs_emit`'s single `name/2` funnel exists to prevent, quoted in F12). A module that lists a friend which no longer exists is never flagged (not implemented here).

### Option B. A path rule: `Internal` is a wall (Go's `internal/`).

```
Shop/Orders/Orders.bs                          module Shop.Orders
Shop/Orders/Total/Total.bs                     module Shop.Orders.Total
Shop/Orders/Internal/Pricing/Pricing.bs        module Shop.Orders.Internal.Pricing
Shop/Reports/Reports.bs                        module Shop.Reports
```
```csharp
module Shop.Orders.Internal.Pricing
public int RecomputeTotal(int n)
RecomputeTotal(n) -> n * 2
```
Rule: a module with an `Internal` segment may be named only from the segment's parent and below. Variant B, verbatim:
```
Shop/Orders           (parent)                 clean
Shop/Orders/Total     (descendant)             clean
Shop/Reports/Reports.bs:3:1: error: Shop.Orders.Internal.Pricing may not be named from this module
  a module under an `Internal` directory may be named only from Shop.Orders and the modules beneath it
  move this module beneath that directory, or move the module out of `Internal`.
NsB/NsB.bs:6:19: error: Shop.Orders.Internal.Pricing may not be named from this module   (via `using Shop.Orders.Internal`)
```
The unmodified compiler compiles `Shop/Reports` clean.

Compiler delta: no lexer, parser, `bsc.erl` or World change; the same four-door plumbing and diagnostic as A (57 lines), with `allowed/3` computed from the module name (no data, nothing to keep in sync). Go ships exactly this (3.5).

Strongest counterargument: **it cannot say "Shop.Reports may, tests may not"**, which is the only case that is not already F12. A sibling that needs the helper must be moved under the parent or the helper pushed up to `Shop/Internal/...` where *every* `Shop.*` module (tests included, if they live under `Shop`) may name it. Whether it helps then depends on the unowned question of where tests live. Second: `Internal` is a magic directory name, a convention the language then enforces (the same objection to Gleam's default `internal_modules`, which at least is configurable).

### Why not the third visibility marker (Q4)

```csharp
internal int RecomputeTotal(int n)      // spelled how, and internal to what?
```
- Today `internal` is refused with `syntax error before: int` (claim 4). That is the diagnostic any new modifier needs written first.
- The subtree argument has nowhere to live. C# says "assembly", B# has none, so a bare `internal` borrows a glyph without its construct (the rule at `LANGUAGE.md:364-366`: "borrow the construct, or don't borrow the glyph"). The form that works is Rust's `pub(in path)`, which is a new grammar for every function.
- The visibility field is read in **seven places** (`bs_check.erl:299, 365, 376, 479`; `bs_emit.erl:141`; `bs_api.erl:152, 158`), all spelled `=:= public` or `=/= public` on purpose, so that `none` sorts as private (F12's amendment). A fourth value must be added to every one of them; missing one *exports too much* silently, "no test of a working program can see" (F12 text).
- An `internal` function must still be in the export list (the BEAM has one entry label per function, ticket 18 sec.5), so the emitter change is the same as `public`, and all enforcement is the caller-side check of A/B anyway.

---

## 6. Recommendation

**Answer Q1 "not yet", and ship Option 0's two small changes if David wants the consumer served now.**

1. The consumer ticket 24 named is served: F12 made a helper unnameable by default (probe f). What remains is (i) callbacks (variant C, 10 lines plus an honest diagnostic) and (ii) the F12 diagnostic inviting the one-edit bypass. Neither needs a language construct.
2. The corpus shows no demand for a *narrower-than-public* audience: 8 `using <Module>` lines across 75 example files, none for a function that should be limited. CLAUDE.md's rule for gates is a second occurrence of the failure; there has been none.
3. The hole that does matter, tests placed inside the module directory (probe f case 4: the test ships in the production `.beam`, reaches `private`, and defeats every option here), is owned by no ticket. **It is the real gate on this one.** I would raise "where tests live" first.

**If David answers Q1 "yes", build B, not A.** B spends no keyword and no grammar, adds no World field, has a toolchain precedent that is itself a probe-able fact (Go), and is the smaller thing to take back. A's explicit sibling list should come with the *second* occurrence of "a sibling, not a descendant, needs the helper", at which point `friend` can be added without changing B (it only widens `allowed/3`). Either way the four-door plumbing and the type-position diagnostic must come with it, or the rule has three exits.

**What would change this:**
- an agent-written test (or a corpus program) observed naming a helper that was flipped to `public` under the F12 advice -> do A or B now;
- a real program in which a sibling module, not a descendant, needs a helper -> A over B;
- a decision that tests live *inside* the module directory -> no option here helps; the answer has to be a test-only compilation mode (a different ticket);
- David wanting 24's carve-out preserved -> drop variant C and rely on the reworded F12 message alone.

---

## 7. Honest limitations

- **Elm** not observed (package server blocked). **Gleam LSP/docs rendering** not run; only `gleam build` and `gleam export package-interface`. **Elixir/Boundary** source unreadable (hex blocked), and Elixir's compiler source is not in the environment (`lib/elixir` has only `ebin`), so its claims are probe runs, not line citations.
- **C# `internal`** not probed (no toolchain); the "assembly-scoped" fact is carried from ticket 22.
- **eunit suite not run** (no rebar3). The prototypes are checked by the negative/positive controls in `e_prototype.sh` and the 28-directory example sweep only; the patches are not production quality (no `friend` of a nonexistent module check, no self-friend lint, namespace-type diagnostic wrong, variant C reuses the wrong message).
- **Timing** is on a shared 4-CPU machine and its differences are noise; the per-predicate micro-benchmark is the reliable figure. Not measured: a large `World`, where `type_gate/3` runs once per module.
- **Constructor and pattern positions** of a denied record (verifier: a qualified record constructor or qualified type in a pattern is a syntax error in base and in A, so these cannot be written and are not a gap), `implements`, and the REPL (`ibs`) `using` path were not probed.
- The corpus-demand count is a grep over `using <Module>` lines, not a call-graph; it undercounts qualified calls through a namespace `using`.


## Verification note

Independently verified: `verification.md` (VERIFIED WITH CORRECTIONS). All 11 probes reproduce; Gleam `@internal`/`internal_modules` not being enforced was re-tested with a from-scratch two-package project (compiles, returns 1044); the ticket-24 'helper lands unclassified' staleness and the four-doors claim were re-tested with the verifier's own programs, and no fifth door was found. One behaviour to read correctly: a module in the dependency closure can be named in type position (the `Ty` case). That is specified (LANGUAGE.md around line 162: the qualified spelling is "legal wherever the module is reachable"), not a checker bug. Still unprobed: `implements`, `behaviour <Module>`, and the `ibs` REPL.
