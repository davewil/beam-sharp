# Decision brief: ticket 60 (ENG-242), "Which modules may name this one?"

Nothing here resolves the ticket. Repo is untouched except `artifacts/60-…/`. Measured at HEAD `1429fdc`
on OTP 29 (the ticket says OTP 28; nothing below depended on the difference), gleam 1.19.1, elixir 1.20.4.
All probe paths are relative to `artifacts/60-which-modules-may-name-this-one/probes/`.

## 0. What the ticket gets wrong or has gone stale on (re-checked, not assumed)

| Ticket claim | Status at HEAD | Probe |
|---|---|---|
| `add_module_import/5` at `bs_check.erl:407-425` is the check site | Moved and renamed. `add_module_import/3` is `bs_check.erl:509`. It has **no caller identity and no line**. The function that has both is `add_import/7` (`:495`, takes `L`, `Self`, `Mode`), called from `import_env/4` (`:486`). The check belongs in `add_import`, not in `add_module_import`. | p0.out |
| No `internal`/`friend`/`sealed`/`visible_to` in the checker | Holds. | p0.out |
| Ticket 24 §2: `RecomputeTotal/1` "lands `unclassified`", "every function is exported today" | **Stale.** F12 (2026-08-17, four days after 24 resolved) made unmarked = private. An unmarked `RecomputeTotal` is refused to every other module and is absent from `--api`. The case that survives is a helper that is `public` because a *sibling* module needs it (`RecomputeTax` in p1). | p1.out |
| Per-function export control is not cheaply available (18 §5) | Holds for the reason stated, though 18's finding was about guard pairs, not caller-restricted exports. The export table has no caller column. | export.out |
| Namespace/module split: "`Shop` as a module and `Shop.Orders` as a separate module already could not coexist" (41, line 499) | Does not hold. `examples/Shop` has `shop.bs` (`module Shop`) beside `Shop/Billing`, and a child directory with its own `module` line builds its own beam. | p11.out |

New facts the ticket did not have:
* The message the checker gives for a private call says "Mark it `public` in Shop.Orders" (`bs_diag.erl:1358`). An agent following that hint turns a private helper into a global one. Whatever lands here gives that hint a middle rung.
* The corpus is tiny: 8 `using <module>` edges across 6 of 75 `.bs` files under `compiler/examples`. Enforcement cost is not a design input; legibility is.

## 1. Sub-decisions, in dependency order

1. **Direction. Does the callee say who may name it, or does the caller say what it may name?** This is the gating question. It decides where the declaration lives, and the other three follow from it (the unit is a different question in each direction, and the marker/construct question only exists on the callee side).
2. *(if callee)* **Unit.** Subtree of the dotted module path, named group, or explicit list.
3. *(if callee)* **Granularity: a module-level construct or a per-function marker** (ticket's item 3).
4. **Checker cost** (ticket's item 4). Measured below; it is not a differentiator.

Ask 1 alone. Everything below prices it, then shows the follow-ups under the likely answer.

## 2. How neighbours do it (all probed; the answer is "mostly they don't enforce")

**Gleam** (`gleam.toml` `internal_modules`, `@internal`). Probe `gleam.sh` / `gleam.out`:
* `internal_modules = ["shop/internal", "shop/internal/*"]`. A second package depending on `app` by path imports `shop/internal/tax` and **builds with exit 0, no warning**. A same-package intruder module also builds. `@internal` on a `pub fn` in a public module: client calls it, builds, exit 0.
* What it does do: hides the module and the `@internal` fn from generated docs (`gross: 1 file, helper: 0, recompute_tax: 0` after `gleam docs build`; `gross` is the control that must be non-zero), and the binary carries a publish-time rule, strings `CannotPublishLeakedInternalType` and "internal types in their public API and cannot be published". I could not run `gleam publish` (no hex.pm, and `--dry-run` is not an option in 1.19.1), so the publish rule is read from the binary's strings only, not exercised.
* Reading: Gleam's "internal" is documentation visibility plus a leak check on *types* at publish time. It is not an import refusal. Gleam's compiler source (Rust) is not installed, so there is no file:line to cite; the claim rests on the probe.

**Elixir** (`@moduledoc false`, `@doc false`). Probe `ex/hidden.exs` / `ex.out`: an outsider module calls a `@moduledoc false` module and a `@doc false` function; both succeed (`{10, 50}`), and `:erlang.function_exported(Shop.Public, :helper, 1)` is `true`. Documentation-only. (My first version tried `Code.fetch_docs` on in-memory modules and crashed on `:module_not_found`; kept as `ex.v1-docs-in-memory.out`, dropped from the probe because the claim needs only the first and last lines.) Elixir lib sources are not installed (beams only), so no file:line; `Boundary` is a hex package and hex.pm is blocked: "source unavailable: hex.pm; grepped installed elixir lib, found 0 hits for 'boundary'".

**Erlang/OTP.** `-moduledoc false` marks 91 modules in kernel+stdlib as internal (`kernel-11.0.4/src/code_server.erl:23`, `application_controller.erl:23`); like Elixir's it is documentation-only. The one tool that does enforce a who-calls-whom rule is **xref**, which is post-hoc and whole-program (`tools-4.2.3/src/xref.erl:106-121` documents `-ignore_xref` to silence it). Probe `xref.escript` / `xref.out` ran xref over the beams `bsc` emitted for p1: it found the cross-module edge `'Shop.OrdersTest':'Probe'/1 -> 'Shop.Orders':'RecomputeTax'/1` with no compiler change, and a prefix filter reported exactly that caller as outside `Shop.Reports` (control: prefix `Shop` reports none). Caveat the script exposes: my first filter, `lists:prefix("Shop.Reports", atom)`, would also pass `Shop.ReportsX`; any subtree test on module atoms must compare on a `.` boundary (the prototype does).

**Elm** (`exposed-modules` vs other modules in a package). Probe `elm.sh` / `elm.out`: **failed**, `elm make` cannot fetch `elm/core` (package.elm-lang.org returned 403 through the proxy). Source unavailable: elm registry; no cached `~/.elm`. Not cited.

Takeaway for the design: no BEAM-family neighbour refuses the import. The only enforcing mechanisms are a separate post-hoc tool (xref) and, in typed non-BEAM languages, a module-level export list. A B# refusal at `using` would be the first one on the BEAM that fails the build.

## 3. What the BEAM can and cannot do (ticket's second constraint)

Probe `export.sh` / `export.out`: three modules differing only in what `-export` lists.

```
m_all     beam=840 bytes exports=[f,g,h] ExpT=64 LocT=4
m_friend  beam=848 bytes exports=[f,g]   ExpT=52 LocT=16
m_one     beam=840 bytes exports=[f]     ExpT=40 LocT=28
m_friend:g(1) from the shell (an arbitrary caller): 8        % exported means anyone
m_one:g(1) (local): {'EXIT',{undef,...}}                      % local means no one
```

An export table is a list of `{F,A}` with no caller column, so "some callers" can only be a compile-time check on the caller. Size differs by ±8 bytes (noise-level; `m_one` and `m_all` are both 840). Confirmed, with the caveat that the thing 18 §5 measured was guard elision. A runtime alternative (probe `runtime_guard.escript` / `.out`, a `process_info(current_stacktrace)` check inside the callee) costs about 440-680 ns/call against 22-54 ns plain, 10x or worse, and a tail call erases the caller frame, so it is neither cheap nor reliable. It is rejected.

Consequence for every option below: the restricted function is `public`, hence exported, hence (F24) gets its boundary guards even for in-subtree callers. 18a measured those at +3-5 bytes per `is_integer` and under noise per call; I did not re-measure.

And the other direction of the same fact: the rule is **B#-source-only**. Anything that can write `'Shop.Support.Math':'RecomputeTax'(1)` in Erlang walks past it (ticket 06 already accepts this for `private`).

## 4. The consumer: ticket 24's "unclassified" helper, concretely

After F12, p1 shows the three states of a helper today (`p1.out`, the fixture is a small `Shop` tree):

```
Shop.Reports  calls public RecomputeTax    -> compiles, runs   (36)
Shop.OrdersTest calls public RecomputeTax  -> compiles, runs   (10)     <- the leak
Shop.OrdersTest2 calls unmarked RecomputeTotal -> refused:
    "…which Shop.Orders declares `private`  … Mark it `public` in Shop.Orders, or move the call inside it."
bsc --api src/Shop/Orders   ->  int RecomputeTax(int) / int Total(list<int>)
```

(The first run of p1 failed on a typo in my fixture, `List.Sum(lines, 0)`, kept as `p1.v1-typo.out`.) So a test loop cannot target a *private* helper any more; it can still target a helper that is public only to serve siblings, and the compiler will gladly tell it to make things public. That is the remaining job for ticket 60.

## 5. The options, as B# programs

The word `within` below is a placeholder spelling, chosen only to avoid `internal` (the ticket forbids borrowing it). The prototype is a **patched copy** of the compiler at `scratchpad/60/proto` (diff in `proto/within-only.patch`, 49 changed lines across `bs_lexer.xrl`, `bs_parser.yrl`, `bsc.erl`, `bs_check.erl`, `bs_diag.erl`); the repo's `compiler/src` was not modified.

### Option A. The callee names who may name it: a module-level, subtree-scoped construct

```csharp
// src/Shop/Support/Math/Math.bs
module Shop.Support.Math
within Shop                                   // only Shop and Shop.* may name this module

public int RecomputeTax(int net)
RecomputeTax(net) -> net / 5

// src/Test/Shop/Orders2/Check.bs  (tests live under a different top segment)
module Test.Shop.Orders2
using Shop.Orders
using Shop.Support.Math                       // refused
public int Check(int n)
Check(n) -> RecomputeTax(n)
```

Observed under the prototype (`p9.sh` / `p9.out`):

```
Shop/Reports        (inside Shop)                         exit=0   ; Gross 50 -> 70
Test/Shop/Orders    (uses only the public Total)          exit=0
Test/Shop/Orders2   using Shop.Support.Math  ->
  src/Test/Shop/Orders2/Check.bs:4:1: error: Test.Shop.Orders2 may not name Shop.Support.Math
    Shop.Support.Math declares `within Shop`: only that subtree may name it
Test/Shop/Via       using Shop.Support (a namespace) then Math.RecomputeTax(n) ->
  error: Math is called but never imported / add `using Math` …        exit=1
Test/Shop/Via2      using Shop.Support, Format.Label(n) (unrestricted sibling) exit=0
```

Control (must be able to fail): the same tree with the `within Shop` line deleted, compiled by the HEAD compiler, **accepts** both `Test/Shop/Orders2` and `Test/Shop/Via` (`exit=0`, `exit=0`), so the line is what refuses them. A second control: the HEAD compiler cannot parse the `within` line at all (`syntax error before: public`).

Narrow subtree variant (`p11.sh` / `p11.out`): `within Shop.Orders` on `Shop.Orders.Internal` lets the parent `Shop.Orders` call it (`Total 50 -> 60`) and refuses the sibling `Shop.Reports`. Parent and child directory build as two beams (`Shop.Orders.beam`, `Shop.Orders.Internal.beam`).

**What it lowers to:** nothing. No emitted function, no attribute, same beam. The function stays exported.

**Compiler delta (the prototype is exactly this):**
1. Lexer: one keyword. Parser: one `decl` arm, `within_decl -> 'within' modpath`, node `{within, L, Mod}` (`bs_parser.yrl`; the six shift/reduce conflicts are the same six as before the patch).
2. `bsc.erl:227` `build/4`: add `within => [P || {within,_,P} <- Decls]` to the World entry (sits beside `private`, `behaviours`, `types`). `types_world/2` (`bsc.erl:293`) needs the same key or the `--api`/type-query path will not see it.
3. `bs_check.erl:495` `add_import/7`: before `add_module_import`, call a `namable(Self, M, World)`; on refusal `erlang:error({not_nameable, M, Self, Within, L})`, the same shape as the existing `unknown_module` raise on `:502`. Segment-aware prefix: `Self =:= P orelse lists:prefix(P ++ ".", Self)`.
4. `add_namespace_import` (`:524`): **filter** restricted children instead of refusing the whole `using`. Refusing would break `using Shop.Support` for an outsider who only wants `Format`. The prototype filters; the cost is the misleading diagnostic in the `Via` row above ("add `using Math`" is wrong advice: that string names no module). Real work: when a name is reachable-but-restricted, say so. `reachable/2` (`bs_check.erl:~466`) already finds such modules for the type-hint path and is the natural reuse.
5. `bs_diag.erl`: `built/2` + `message/1` clauses (the prototype added both; ~12 lines), and JSON via F47's channel.
6. `bs_api.erl`: **`--api` is silent about the restriction** (`p9.out`, last block: it prints `int RecomputeTax(int)` only). If ticket 24's boundary manifest is to classify, `--api` must print the `within` line. Not in the prototype.
7. Strict mode only. `import_env` also runs `lenient` for `--api` and `type_world`; those must skip the check (the prototype does).

Foreign bypass, checked and mostly closed (`p8.sh` / `p8.out`): a `using :'Shop.Orders' { int RecomputeTax(int net) }` is a **syntax error** because a foreign signature takes an `lident` and B# function names are `uident`. It is the grammar, not the checker, doing that. But a lowercase callback is reachable: `using :'Counter' { (:ok, int) init(int seed) }` plus `:'Counter'.init(n)` compiled and ran (`{ok,50}`) with no `using Counter`. For restricted modules that implement a behaviour, the callbacks are not covered by a check at `using`. (An earlier version of that probe called `init(n)` unqualified and got "nothing binds"; kept as `p8.v1.out`.)

**Ticket-24 consumer:** put the shared helper in its own module marked `within Shop` and keep tests in a separate top-level segment (`Test.*`). The test can name `Shop.Orders` (the client API) and is refused `Shop.Support.Math`. Cost to the author: a helper that serves siblings moves out of the aggregate's module. Condition: a test module named `Shop.Orders.Tests` sits *inside* `Shop` and is not excluded; the test tree's root segment is load-bearing and nothing enforces that it is separate.

**Evidence of cost:** `cost.sh` / `cost.out` (150 generated modules, 1164 `using` edges, 7 runs after a discarded warm-up):

```
HEAD compiler, no within             median=822 ms  min=753 max=959
patched, check runs, no rules        median=838 ms  min=699 max=896
patched, every module 'within Gen'   median=760 ms  min=727 max=815
HEAD compiler again (drift check)    median=838 ms  min=764 max=933
```

The spread (±100 ms) is larger than any difference; the check is below measurement. In isolation (`micro.escript` / `micro.out`) the lookup is about 95-100 ns per `using` edge: ~0.11 ms for the whole 1164-edge tree, ~0.014% of a compile. (The first driver used `bsc:main`, which calls `halt` and printed nothing; first micro run had a format bug. Both kept as `cost.v1-shell-quoting-bug.out` and `micro.v1-fmt-bug.out`; the fixes did not touch what is measured.) The real corpus has 8 edges.

**Strongest counterargument.** The unit is the wrong shape for what 24 actually needs. 24's problem is *functions inside one module* (client API vs helper), and a module-level rule can only separate them by forcing the helper into another module. For an agent that is a heavier move than writing `private`, and the temptation the compiler's own hint creates ("Mark it `public`") will still win unless the hint changes. A second weakness: the test-exclusion works only by naming convention (`Test.*` vs `Shop.*`); a subtree rule cannot say "everyone except tests", only "this prefix and below", so it protects against tests only if tests are placed outside the prefix.

### Option B. The caller declares what it may name

```csharp
// src/Test/Shop/B1/Check.bs
module Test.Shop.B1
only Shop.Orders                              // this module may name only Shop.Orders (and below)
using Shop.Orders
using Shop.Support.Math                       // refused by B1's own list
public int Check(int n)
Check(n) -> RecomputeTax(n)

// src/Test/Shop/B2/Check.bs  — the same module, `only` omitted
```

`p9b.sh` / `p9b.out`:

```
Test/Shop/B1: error: Test.Shop.B1 may not name Shop.Support.Math
              Test.Shop.B1's own `only` list excludes it: ['Shop.Orders']      exit=1
Test/Shop/B2: (no declaration)                                                  exit=0   <- control
```

**What it lowers to:** nothing. **Compiler delta:** the same `add_import` hook, reading the caller's own decls instead of the callee's World entry (the prototype's `only` decl is a second arm in the same `namable/4`); no World key, no `types_world` change. So it is *cheaper to build than A*, by one World field.

**Why it is closer to what `using` already does** (ticket's own observation): `using` is already the caller's dependency list. B makes it a closed list.

**Strongest counterargument, and it decides it against B for this ticket.** The rule is binding only on a module that wrote it. There is no declaration site for a *subtree*: a namespace (`Shop`, `Test`) is erased and holds no `.bs` file (F15), so "all tests may name only X" has to be repeated in every test module, and the module that drifts is exactly the one that omits it (B2 above, exit 0). The fence lives in the file the agent is editing. Option A's declaration lives in the *callee*, which a test-writing agent has no reason to touch. (An agent can edit the callee too, but that is a visible diff in a file the tests do not own, which a reviewer sees.) B is the better fit for a team enforcing layering on its own modules; it does not serve the 24 consumer.

### Option C. Callee-declared, per-function marker (granularity follow-up to A)

```csharp
module Shop.Orders
public int Total(list<int> lines)
Total(lines) -> RecomputeTotal(lines)

public(within Shop) int RecomputeTotal(list<int> lines)     // placeholder spelling
RecomputeTotal(lines) -> List.Sum(lines)
```

This was **not prototyped**; I counted the sites instead. The signature node is a 7-tuple `{signature, L, N, R, Ps, Vis, TVars}` and `Vis` is read by `=:= public` / `=/= public` at `bs_check.erl:296, 362, 373, 476`, `bs_emit.erl:140`, `bs_api.erl:152, 158` (the same sites F12's amendment said were converted to `=:= public` so that an unknown value sorts as *private*). A new `Vis` value such as `{public_within, P}` would therefore be treated as **private by every one of those readers** until each is edited, the opposite failure to the one F12 guarded against, and no test of a working program can see it. Also `vis_source/1` (`bs_check.erl:2463`) that F25 uses to print a corrected signature, and `private_of/1` (`:474`), which is where the callee's restricted table would be built to mirror the `private` table. The check itself sits at the call site (`bs_check.erl:3850`, `:4391`, the `private_callee` pattern), on the *success* path, so it costs a lookup per resolved import call (same ~100 ns scale as A; extrapolated from `micro.out`, not separately measured), versus once per `using` for A. `grep -c '{signature,'` finds 21 matches in `bs_check.erl`, 2 in `bs_api.erl`, 5 in `bs_parser.yrl`.

**Ticket-24 consumer:** `RecomputeTotal` stays in `Shop.Orders`, with no restructuring; a test in `Test.*` is refused at the call. This is the only option that places the helper where the author wants it.

**Strongest counterargument:** it is a third visibility marker on the signature, in the one position where F12 just paid for a corpus-wide rewrite and a same-day amendment. It enlarges the surface of every signature to answer a question that, per 22, "probably is [worth having independently]" but that has no second consumer yet. And `--api`/the boundary manifest must now carry three states per function.

## 6. Unit (sub-decision 2), only if the answer to 1 is "callee"

The subtree is the cheap answer and the p9/p11 programs show it is expressive enough for two cases: "the whole project" (`within Shop`) and "this aggregate" (`within Shop.Orders`). The prefix test is segment-aware (a `Shop.Reports` rule must not admit `Shop.ReportsX`; xref.escript's string prefix would). A *named group* needs a declaration site for the group, and namespaces have none (F15), so a group is a new kind of file; an *explicit list* repeats the module names in every restricted module and silently rots when a module is renamed (the checker must also validate that listed modules exist, which `unknown_module` already does for `using`). I did not prototype either; they are not the cheap path and no program in the corpus needs them.

## 7. Recommendation

1. **Ask the gating question alone: callee-declared, or caller-declared?** Recommend **callee** (Option A's direction). It is the only direction whose declaration the restricted *consumer* (the agent writing tests) does not author, and p9b shows the caller-side form unfenced when omitted.
2. Under "callee", **the unit is a subtree of the dotted path, and the construct is module-level** (Option A), checked at `add_import/7`. It is a few hours of checker work (49 patched lines for a working prototype, below measurement noise), builds on `private`'s existing World-entry pattern, and lowers to nothing.
3. **Defer Option C.** It is the right answer for the exact `RecomputeTotal` shape in 24, but it touches the F12 visibility readers and the `--api` classification, and ticket 24's shape is already half-dissolved by F12. Raise it as a ticket if a second consumer appears, per the "a check needs a second occurrence" rule.
4. Whichever is chosen, three small obligations come with it that the ticket does not list: the "Mark it `public`" hint in `bs_diag.erl:1358` should mention the restricted rung; `--api` must print the restriction for the 24 manifest; and namespace imports must filter, not refuse (with a reachable-but-restricted hint).
5. Do not borrow `internal` (22's constraint). Gleam's use of the word is a documentation flag (§2), a second reason not to: it would promise a refusal that Gleam's does not give either.

What I did not settle: the keyword. `within` is a placeholder; I did not survey spellings.

## Probe index

All re-runnable from `probes/` (scripts resolve their own paths; the `bsc`, `erl`, `gleam` paths are those in the task preamble).

| File | Command | Claim supported |
|---|---|---|
| `p0.out` | grep in `p0.out` header | No `friend`/`sealed`/`visible_to`; check site is `add_import/7` `:495` / `add_module_import/3` `:509` |
| `p1.sh`, `p1.out` (`p1.v1-typo.out`) | `./p1.sh` | Private helper refused; public helper open to a test module; `--api` lists public only |
| `gleam.sh`, `gleam.out` | `./gleam.sh` | Gleam `internal_modules`/`@internal` do not refuse an import; docs-hiding and publish-time rule only |
| `ex/hidden.exs`, `ex.out` (`ex.v1-docs-in-memory.out`) | `elixir ex/hidden.exs` | `@moduledoc false` / `@doc false` are documentation-only |
| `elm.sh`, `elm.out` | `./elm.sh` | FAILED: registry unreachable; Elm not cited |
| `xref.escript`, `xref.out` | `./xref.escript <beamdir> Shop.Orders Shop.Reports` (beams from `bsc -o`) | OTP xref sees the cross-module edge post hoc; subtree test must be segment-aware |
| `export.sh`, `export.out` | `./export.sh` | Export table is per-function, no caller column; size cost is noise |
| `runtime_guard.escript`, `.out` | `./runtime_guard.escript` | A runtime caller guard is 10x+ a plain call |
| `p8.sh`, `p8.out` (`p8.v1.out`) | `./p8.sh` | Foreign block cannot name uident B# functions (grammar); a lowercase callback is reachable without `using` |
| `p9.sh`, `p9.out` (`p9.v1-…`, `p9.v2-…`, `p9.control-head-unparseable.out`) | `./p9.sh` | Option A refuses the intruder, admits the sibling and the namespace-import case, control accepts when the line is removed; `--api` is silent |
| `p9b.sh`, `p9b.out` | `./p9b.sh` | Option B refuses only when the caller opted in |
| `p11.sh`, `p11.out` | `./p11.sh` | Narrow subtree (`within Shop.Orders`); parent and child directory are two beams |
| `cost.sh`, `cost_driver.erl`, `gen_tree.py`, `cost.out` | `./cost.sh` (needs `scratchpad/60/proto/ebin`) | 1164-edge tree: no measurable compile-time difference |
| `micro.escript`, `micro.out` | `./micro.escript` | ~100 ns per `using` edge for the rule itself |
| `proto/within-only.patch`, `proto/BUILD.txt` | see BUILD.txt | The exact prototype diff against repo `compiler/src` at `1429fdc` |

Probes that failed or misled me, kept: `p1.v1-typo.out` (my fixture), `elm.out` (network), `ex.v1-docs-in-memory.out`, `p8.v1.out`, `p9.control-head-unparseable.out` (an unclean control, replaced by the within-line-deleted control), `p9.v1-api-ran-in-control-tree.out` and `p9.v2-api-ran-under-HEAD-ebin.out` (my script left `cwd`/`EB` pointing at the control, so `--api` ran in the wrong place; fixed, and the HEAD result kept as an explicit second control), `cost.v1-shell-quoting-bug.out`, `micro.v1-fmt-bug.out`.

## Errata from independent verification (verification.md)

The verifier rebuilt the `within` prototype from a fresh copy and re-ran every probe. No probe is circular. Controls it ran: with the `within` line deleted the patched compiler accepts; `Shop.Zed` is admitted; `Zed.Q`, `Shopx.Q` and `Shop2` are refused; with `within Shop.Reports`, `Shop.ReportsX` and `Shop.Report` are refused and `Shop.Reports` and `Shop.Reports.Sub` are admitted. Corrections:

- **"No measurable compile-time difference" is true but weak.** `cost.sh` had no positive control. The verifier added one: a deliberate slow check costing about +23 ms per tree was not detected, and one costing about +115 ms was. The harness resolves only about 100 ms. The real support for "negligible" is `micro.escript`, which times a replica of `namable/4`, not the compiler's code. "0.014% of a compile" is arithmetic from that replica.
- **p9b's `B2 exit 0` control is tautological.** A caller-declared rule is unfenced when omitted, by definition. It illustrates the argument and measures nothing.
- **Gleam:** the exit-0 claims are sound, but the control shows the `internal_modules` pattern is live for docs only. "No import refusal" rests on exit 0 alone.
- **Wrong citation:** "ticket 06 already accepts this for `private`" is unsupported. Ticket 06 says nothing about `private`, and `private` is unexported, so Erlang cannot bypass it, unlike `within`.
- **Minor:** the `private_callee` sites at `bs_check.erl` 3850 and 4391 are on the callee-not-found path; `types_world` starts at `bsc.erl:286`, not 293.
- **No probe behind:** the "two beams" claim has no script line (the verifier reproduced it by hand); the tail-call-erases-the-frame claim was confirmed only in a 5-line test.
- **Not run:** the prototype was not run against the repo test suite or a corpus compile. `within` and `only` become reserved words; grep finds them only in comments in `examples/` and `test/`.
- Repo HEAD moved to `ad33427` during the run; the cited lines are unchanged.
