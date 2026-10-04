# Decision brief: ticket 60 (ENG-242), which modules may name this one?

Prepared 2026-10-04 against HEAD `98d9835`. Nothing under `wayfinder/` or `compiler/` was edited; the
ticket is not resolved, nothing is committed, Linear is untouched. Every prototype ran on a **copy** of
the compiler in `/tmp` (built from HEAD sources, OTP 28, `/tmp/tc/rebar3`); the patches are saved beside
the probes. Everything cited as "probe NN" is in `probes/NN_*.sh` with its captured `NN_*.out`.

## 0. The ticket's citations, checked at HEAD

They do **not** hold (probe 09). `0b761f6` is not in this clone (50 commits, shallow), and the code moved.

| ticket says | at HEAD |
|---|---|
| `add_module_import/5`, `bs_check.erl:407-425` | `add_module_import/3` at `bs_check.erl:511-525`, called from `add_import/7` at `:499`. Lines 407-425 are now `qualify_refs` (type crossing). |
| 22: `bs_parser.yrl:262-268` (public/private) | those lines are the type grammar; `visibility -> 'public'`/`'private'` is `:323-324`. |
| 22: `bs_check.erl:43` | `vis = private` default is in the `#fn` record at `:41`. |
| "reads only the callee's export set" | still true of **functions**, but it also reads the callee's `types` entry (F44 landed after the ticket): `exports` and `types` are the two things a `using` brings in. No `internal`/`friend`/`sealed`/`visible_to` anywhere in `src/` (probe 01, 09). |

I grepped `wayfinder/issues/` for `who may name`, `visible_to`, `friend`, `subtree`: the only decided-adjacent
hit is ticket 41 §5's diagram labelling a directory `Internal/` inside `Shop/Orders/` as "SUB-MODULE,
source-only (ticket 13)". F15.11 later made every directory holding `.bs` files its own module with its own
`.beam`, so that label names a notion F15 superseded. It is a spelling hazard (section 1.5), not a decision.

## 1. Sub-decisions

**1.0 The gating one: direction.** Everything else follows from it, so it is the only thing to ask David
first. The realistic program is one file, `Acme/Billing/Billing.bs`, which says `using Acme.Orders.Rules`.

- If the *callee* names who may call it, that file is refused at its `using` line, whatever its author wrote
  (probe 03 step 1b).
- If the *caller* declares its dependencies, that file compiles unless its own author wrote a list that
  excludes `Rules`; the agent that wrote the file can delete the list (probe 08 steps 1 and 4).

Ticket 24's consumer is an agent writing the *caller*, so the question reduces to "who is allowed to
loosen it", and a caller-side declaration lets the caller.

**1.1 Unit.** A directory subtree, which here is a dotted-atom prefix. F15 makes the module atom equal the
directory path under `--src-root` (`module_matches_path`), so "subtree" is `lists:prefix(P ++ ".", S)` on two
atoms and no filesystem is consulted (probe 02: the checker has `Self`, `M`, the `using` line's `{Line,Col}`,
and the `World` map; at `add_import` it does not have file paths, and it does not need them). A named group
or an explicit list of modules names modules by atom, and the atom is the path, so a rename leaves the list
pointing at nothing; F12's own argument against Erlang's `-export` list (a second site that must agree with
the definition) applies unchanged. That is reasoning from F12/40 §3, not a probe.

**1.2 Where the check lives.** At the `using` line, not at the call. `using` is already mandatory for every
named call (probe 01: a qualified call with no `using` is refused as `module_not_imported`), so one check at
`add_import` covers unqualified calls, qualified calls and F44 type names together. It must be strict-mode
only: `add_import` runs **five times per module** (9,900 calls for 1,980 `using` lines, probe 16), once strict and four times lenient
(`exports_of`, `polys_of`, `types_of`, `--api`), and a refusal in a lenient pass would break `--api`/the REPL query.
The namespace tier (`using Acme` over a directory with no `.bs`) bypasses `add_module_import` entirely and
sweeps every descendant through `add_namespace_import`, so it needs its own handling (section 2, probes 04 and 05).

**1.3 Marker or construct.** A rule about modules belongs on the module. A per-function marker (option C,
`public within Acme.Orders int Recompute(...)`) was **not prototyped**; probe 09 enumerates what it touches:
the grammar's two `signature` productions, six readers of the visibility value (`bs_check.erl:299, 364, 375,
478, 602, 2350`) plus `bs_emit.erl:141`, a per-function table in `World`, and the two `private_function` call-site
refusals (`:3656`, `:4200`) whose `#ctx` does not carry the calling module today. It also cannot restrict a
type name (F44), so a restricted function's record type would still cross. Its one advantage is granularity: one
function in a module. In this language that granularity is already available by directory, because F15 makes a
helper module cheap (probe 07's `Shop/Orders/Totals/Totals.bs`). I did not measure how often an author would
want a restricted function inside a module that has other public ones.

**1.4 Checker cost.** Measured in section 4: not distinguishable from noise end to end; the check's own work
is bounded at under 50 ms for a 321-module, 1,980-`using` tree.

**1.5 Spelling.** Survey (section 3, all run except C# and Elm):

| word | what it means where it lives |
|---|---|
| C# `internal` | assembly. B# has none. Reference only, not run. |
| Gleam `internal_modules` / `@internal` | **docs-hiding only at 1.12.0**: an outside package imported and ran the internal module with no diagnostic (probe 10). The false friend runs the other way: it looks like enforcement and is not. |
| Go `internal/` directory | enforced, and means exactly "the subtree rooted at the parent of `internal`", last `internal` element wins (probe 19). This is the unit above. |
| Rust private `mod` / `pub(in path)` | enforced, subtree of the declaring module (probe 14). |
| Elixir `@moduledoc false` | docs only; a private call from outside is a **warning** and compiles (probe 11). |
| Erlang | no attribute exists (probe 12). `-moduledoc false` is docs only; `xref` is a post-hoc query. |

So ticket 22's "do not borrow `internal` without its semantics" has a concrete answer: the only enforced
precedent whose semantics match is **Go's directory rule**, and the word is a directory name there, not a
keyword. Borrowing it as a path segment would carry Go's semantics. Borrowing it as a keyword, or taking Gleam's
`internal`, would carry a meaning B# is not offering. Ticket 41's stale `Internal/` diagram label means
something else (sub-module, source-only).

## 2. Options, each a program plus compiler work

All three were built on copies and run. All three are **compile-time only**: see section 5.

### Option A: callee declares, module-level keyword

```csharp
// Acme/Orders/Rules/Rules.bs
module Acme.Orders.Rules
within Acme.Orders              // only modules at or under Acme.Orders may name this one

public int Recompute(list<int> lines)
Recompute([]) -> 0
Recompute([x, ..rest]) -> x + Recompute(rest)
```

```
$ bsc --src-root . Acme/Orders   Total "[1,2]"   -> 3            (parent, inside the subtree)
$ bsc --src-root . Acme/Orders/Tests Check        -> 6            (descendant, inside)
$ bsc --src-root . Acme/Billing  Invoice "[1,2,3]"
Acme/Billing/Billing.bs:4:1: error: `using Acme.Orders.Rules` -- Acme.Orders.Rules is declared `within Acme.Orders`, and Acme.Billing is outside it
  only modules at or under Acme.Orders may name Acme.Orders.Rules. Move this module under Acme.Orders,
  or call a public function of a module that is not restricted.
```
(probe 03; `Acme.OrdersExtra` is refused too, so it is a segment prefix and not a string prefix.)

Compiler delta, as built in the copy (`03_prototype_within.patch`, 170 lines including the diagnostic):
- `bs_lexer.xrl`: one keyword rule. `bs_parser.yrl`: `within_decl -> 'within' modpath`, one `decl` line.
- `bsc.erl build/4`: `World` entry gains `within => bs_check:within_of(Decls)` (a missing key means unrestricted, so the other builders of `World` entries, the query path and `bs_api`, need no change).
- `bs_check.erl`: `visible_to/2` over dotted atoms; called from `add_import` in strict mode only; a second check that the `within` prefix encloses the module itself (probe 03 step 5: `within Acme.Orders` in `Acme.Odd` is refused, otherwise a module could make itself unnameable by its own subtree).
- `bs_diag.erl`: two tags and their messages, text and JSON (probe 03 step 1c shows the JSON form).
- Namespace tier, v2 (probes 04, 05): see below.

Evidence: probe 03 (compiles under it / refused under it, five scenarios), probe 05, probe 07; eunit on the
copy: 1,305 passed and 4 failed over the whole suite, and the same 4 fail identically on **unpatched HEAD**
(three are a non-UTF-8 locale, one needs `../aoc` next to the copy; with `LANG=C.UTF-8` and `aoc` linked all
four modules pass, 119 tests with five new `within_tests`). Probe 17.

**A hole I found and a choice it forces.** A namespace import sweeps every descendant. My first version
refused if *any* swept child was restricted-and-invisible, and that rejected a module that said only
`using Acme` and never named `Rules` (probe 04: the false positive, kept). Version 2 drops invisible children
from the sweep instead (probe 05: `Out.Dash` compiles). The price is a worse message when the caller then
*does* try to name the dropped module through the namespace: it says `Orders.Rules is called but never
imported, add using Orders.Rules`, and only when the author writes the full `using` does it say why (probe 05,
last two steps). The compiler work for that is one more hint in the `module_not_imported` builder: look the
module up in `World` and say it is restricted. Not built.

**Strongest counterargument.** It adds a reserved word (`within`) and a grammar production for a rule that Go
and Rust express with no syntax at all, and it only constrains modules that someone remembers to mark: an
unmarked `Recompute` is exactly as reachable as today. Marking is also *per module*, so the unit of
restriction is a directory; a single helper function inside the client-API module cannot be restricted
without moving it to its own directory first.

### Option A': callee restricted by its path, no new syntax

```csharp
// Acme/Orders/Internal/Rules/Rules.bs      module Acme.Orders.Internal.Rules
```
A module whose dotted name contains an `Internal` segment may be named only from under the segments before the
last `Internal` (Go's rule, probe 19, down to "last element wins").
Probe 20: parent compiles and runs, `Acme.Orders.Tests` compiles and runs, `Acme.Billing` is refused:
```
Acme/Billing/Billing.bs:3:1: error: `using Acme.Orders.Internal.Rules` -- an `Internal` module may be named only from under Acme.Orders, and Acme.Billing is outside it
```
(the unmodified HEAD compiler compiles the same tree and prints `1`).

Compiler delta (`20_path_derived.patch`, 76 lines): `internal_root/1` and `visible_to/2` in `bs_check.erl`,
the same two `add_import` call sites, the same diagnostic pair. **No lexer, parser, `bsc.erl` or `World` change.**
It reuses the existing atom-equals-path guarantee entirely.

Whole suite on the A' copy: **1,309 tests, all passed** (`LANG=C.UTF-8`, `aoc` linked; probe 17 run 4). It has no tests of its own beyond probe 20's scenarios.

**Strongest counterargument.** Visibility is carried by a directory name, so changing who may call a module
means *renaming* it, and a rename changes the module atom, and with it every record tag minted from the
qualified name (the tag is in the term: `Billing.bs` documents `:'Shop.Order'`; F3/ticket 26). Making
`Rules` reachable from one more place means a rename that serialised data can see. Option A changes one line and
no atom. I did not run this rename; the tag-minting claim is from F3/F44's text and the example comments.
It also makes a bare word in a path semantically loaded, which is what ticket 41 §5's "deliberately an error
rather than a convention" was written against, though here it is an enforced convention.

### Option B: caller declares what it may depend on

```csharp
module Shop.OrdersTests
allow Shop.Orders.Api          // this module's `using` lines may name only these subtrees
using Shop.Orders
```
`Shop.OrdersTests allows only Shop.Orders.Api` is the error (probe 08 step 3). Compiler delta
(`08_caller_declares.patch`, 96 lines): same lexer/parser additions, no `World` change, check at `import_env`
over the caller's own decls. It is a legitimate tool for layering inside an application ("billing may depend on
orders and money, nothing else").

Evidence for why it does not serve ticket 24: probe 08. The agent's test as first written has no `allow` line and
names `Totals` freely (step 1); the author's `allow` line refuses it (step 3); deleting the line makes it
compile again (step 4). The party being constrained writes the constraint.

**Strongest counterargument** (against my own dismissal of it). It is the direction ticket 60 itself calls
"closer to what `using` already does", it needs no change to a callee that lives in a *dependency* the caller
cannot edit, and it expresses an architecture rule ("the domain layer may not depend on the web layer") that a
callee-side subtree cannot, because the callee would have to enumerate every forbidden caller. If the question
David actually cares about is layering and not hiding helpers, B is the right answer and A is not.

### Option C (per-function marker): not prototyped, see 1.3.

## 3. Neighbour surveys (what I actually opened)

- **Gleam 1.12.0**, probe 10: two path-linked packages; `lib` sets `internal_modules = ["lib/internal",
  "lib/internal/*"]` and has a `@internal` function; `app` imports both. **It compiled and ran, no error, no
  warning.** The only effect was that `gleam docs build`'s `package-interface.json` listed `lib` and `lib/helpers`
  (`visible` only) and left the internal ones out; the compiled `.beam` exports `recompute/1` and it runs. The
  ticket asked me to show the error an outside package gets; **at 1.12.0 there is none**. The tickets measured
  1.18.1; I cannot say whether that version adds one.
- **Elixir 1.14.0 on OTP 24** (OTP 28 crashes at boot, `Kernel.CLI` undef; only `ebin` is installed, **no `.ex`
  sources were read**), probe 11: `@moduledoc false` made `Code.fetch_docs` return `:hidden` and nothing else
  changed; 36 of 253 modules in the installed `elixir` app are hidden this way and still callable. A call to a `defp` from
  another module compiled, with `warning: Acme.Orders.secret/0 is undefined or private`. The `boundary` library is not installed and is not cited.
- **Erlang/OTP 28**, probe 12: no `friend`/`internal`/`visible_to`/`restrict` attribute in any `-attribute` under
  `lib/*/src`; `-moduledoc false` is on 24 of 95 stdlib modules and is documentation only
  (`dets_utils` is hidden and callable). `xref` is a *query* over beams: run over the beams `bsc` emitted, it
  returns the unwanted edge `{'Acme.Billing','Acme.Orders.Rules'}` with **zero compiler change**. That is a fourth
  way to answer the ticket, as a build-tool lint rather than a language rule; I did not weigh it as an option
  because CLAUDE.md puts gates on the language and the handoff and because an xref run is not in the oracle
  (`bsc`) that the clean-room handoff is judged against.
- **Elm 0.19.2**, probe 13: **not reproduced.** `elm init` and any build need `package.elm-lang.org`, which the
  egress proxy refuses. The binary mentions `exposed-modules` 8 times and `other-modules` 0 times, so the
  `other-modules` the assignment named is not a key this Elm knows; I cannot show the dependent-package
  behaviour of `exposed-modules`.
- **Go 1.24.7**, probe 19 (not in the request, and the most relevant): see 1.5.
- **Rust 1.97.0**, probe 14 (not requested): `E0603 module rules is private` and `function helper is private`
  for a sibling; parent and descendant compile.
- **C# `internal`**: not run.

## 4. Measured cost

- **Whole process** (probe 16): 321 modules, 1,980 `using` lines, 7 timed runs per configuration, full `bsc`
  including VM start. HEAD median 4.2 s then 3.4 s on repeat; prototype without any `within` 3.2 s and 3.6 s; prototype with 20 `within`
  lines 3.9 s. The spread inside one configuration (2.7 to 5.9 s) is larger than any difference between
  configurations, so **the end-to-end result is: not measurable here.**
- **The check itself** (probe 16b): the predicate copied verbatim, 9,900 evaluations (5 passes x 1,980) took
  48 ms *interpreted in the Erlang shell*, so under 50 ms as an upper bound. Evaluations only happen when the
  callee carries a restriction; otherwise it is one `maps:get(within, Entry, none)`.
- A namespace import costs one `visible_to` per swept child; not measured separately.
- Machine: 4 vCPU container, not Apple Silicon; only ratios mean anything.
- Full eunit suite: 8 m 8 s wall on the A copy (run alongside my other probes), 6 m 19 s on the A' copy (probe 17).

## 5. What survives into the `.beam`

Nothing (probe 06). Compiled with and without the `within` line (the baseline's `within` line is a comment so line
numbers match, and both go to one output directory name) the two `.beam` files are **byte-identical** (`cmp`),
and the restricted module's exports and attributes are the ordinary ones. Two earlier runs differed by 4 bytes and
I kept both outputs: the first because the extra line shifted every line number (`06_first_run_lines_shifted.out`),
the second because the `CInf` chunk records the output *directory name* (`06_second_run_outdir_differs.out`);
every other chunk was equal. A plain Erlang module outside the subtree called `'Acme.Orders.Rules':'Recompute'/1`
and got `60`, and so does `apply/3` with no source at all.
**This is not a security boundary.** It is a compile-time check over B# source, as ticket 22 already said of
"visibility over beam-sharp source only". Gleam (probe 10: `exported=true call=6`) and Go behave the same.

Also: the check trusts `Self`, the file's *declared* module name. Under `bsc` that is a directory subtree because
F15's `module_matches_path` refuses a mismatch (probe 18: a file in `Acme/Evil/` declaring `Acme.Orders.Evil` is
refused with the path error). Through the pathless API (`bs_check:check/2`, which tests and the REPL use) the declared name is trusted
and the same module is accepted. Whether `ibs`/the LSP route through a path-checked entry I did not check.

## 6. How it serves ticket 24's `unclassified`

Probe 07 is the program. Under F12 **as built**, ticket 24's literal example is already closed: a
`Discount/1` helper in the `Shop.Orders` aggregate is private by default, and a test module that calls it is
refused with `error: T2 calls Discount/1, which Shop.Orders declares private` (step 2). So `RecomputeTotal`
only becomes `unclassified` if it is `public`, and it is `public` only when **another module** needs it, as
`Shop.Orders` needs `Shop.Orders.Totals.Recompute` (step 3: a sibling test module compiles and runs). That is
the remainder this ticket can close: with `within Shop.Orders` on `Totals` the sibling test is refused (step 4).

Three limits, all observed or stated:
1. **Placement is the escape hatch.** A test module placed *inside* the subtree (`Shop.Orders.Tests`) may name it
   (step 5), and so may anything an agent edits the callee to allow (step 7: delete the `within` line). What the
   feature changes is that the way round is a diff in a different file or a deliberate directory, not the default.
2. **The manifest does not know yet.** `bsc --api` (the nearest thing to 24 §2's published boundary, and the
   boundary manifest itself is not built, since `unclassified` exists in the compiler only as an unrelated
   diagnostic tag) lists `Recompute` as a normal public operation of the restricted module (step 6). Teaching it
   to omit or mark restricted modules is further compiler work.
3. F12's own refusal text says `Mark it public in Shop.Orders`, which is the move that creates the
   `unclassified` function. Not a recommendation to change it, only an observation that the message steers.

The premise that an agent "targets `unclassified` functions because they are the easiest thing in the
directory to test" is ticket 24's claim. I ran no agent; it is **not reproduced**.

## 7. Recommendation

1. **Ask David one question, alone: does the callee say who may name it, or does the caller declare what it
   names?** Show him `Billing.bs` above, compiled under one and refused under the other. Recommended answer: the callee.
   It is the only direction in which the party being kept out cannot lift the restriction by editing its own file,
   and ticket 22 and ticket 24 both stated the need that way.
2. Unit: **directory subtree** (dotted-atom prefix; F15 already guarantees atom = path under `bsc`). A group
   or list adds a second site that must agree with the directory tree.
3. Marker versus construct: **module-level**, enforced at the `using` line, strict mode only. Do not put it on the signature.
4. Spelling, which follows once 1 is answered: lean **A (`within <Prefix>`)** on the evidence that it changes one
   line and no atom to widen or narrow access, over **A'** (an `Internal` path segment), which is 76 lines to A's
   170 and needs no keyword but ties a visibility change to a rename. If David reads both programs and prefers the
   zero-syntax one, A' is a sound choice and the rename cost above is the thing to weigh. I did not run the rename.
5. Whichever is chosen, the feature's first scenario list should include the five in probe 17 plus the namespace
   sweep case (probes 04/05), because the namespace tier is where my first version was wrong.

Build order if chosen, per CLAUDE.md: failing test and gate first, from `17_within_tests.erl` and the probe trees.

## 8. Claims not reproduced / caveats

- **Gleam**: no error at 1.12.0; the tickets' 1.18.1 not available. **Elm**: not run (network). **Elixir**: ran on 1.14 / OTP 24, sources absent, `boundary` not read. **C#**: reference only.
- **Option C** was read, not built. The claim that a per-function marker costs more than a module-level one is an enumeration of sites (probe 09), not a timing or a patch.
- **The rename cost of A'** (atom, then tags) is from documents, not run.
- **"Group or list drifts"** (1.1) is reasoning from F12, not a probe.
- **Ticket 24's agent behaviour** is unreproduced; I ran no agent loop.
- **Wall-clock cost is inconclusive**; only the bound in 16b is firm, and it was measured interpreted in the shell.
- **Prototype scope**: `ibs`, the LSP, `--api` and `bs_repl` were not changed or exercised; strict-only enforcement means a lenient pass will accept a violation that a compile refuses.
- **Diagnostics** in the prototypes: the wording was revised once (`reach the behaviour through` to `call a public function of`), and the namespace tier changed from refuse (v1) to drop (v2). `probes/03_v1_first_run.out` is the v1 run (step 4 there printed `using Zed.Inner.Hidden` for a source line `using Zed.Inner`, naming the swept child rather than the line); `03_prototype_within.out` is the same script re-run on v2, where step 4 instead ends in `Hidden is called but never imported`. The text quoted in Option A is v2's.
- Existing quirk, not mine: bsc's `--src-root` diagnostics print `\x{2014}` and a mojibake byte under a non-UTF-8 locale.
- The container's HEAD advanced while I worked (`662e92f` to `98d9835`, another session's artifacts commit); the compiler sources were unchanged between them.

## 9. Probe index

| probe | what it settles |
|---|---|
| `01_any_module_can_name_any_public` | (a) today a sibling names any public function; `using` is mandatory; `add_module_import` reads `exports` and `types` only |
| `02_directory_is_module_maps_to_subtree` | (b) what the checker holds at `add_import`; five passes per module |
| `03_prototype_within` (+ `.patch`, `.v1.patch`, `03_v1_first_run.out`) | (c) option A: compiles / refused, five scenarios |
| `04_namespace_sweep_false_positive` | v1 refused a module that never named the restricted one |
| `05_namespace_sweep_v2` (+ `05_first_attempt_import_cycle.out`) | v2 drops swept children; the diagnostic it costs |
| `06_compile_time_only` (+ two earlier outputs) | (e) `.beam` identical; outside Erlang caller still works |
| `07_unclassified_under_f12` | ticket 24 consumer: F12 alone, then `within`, escape hatches, `--api` |
| `08_caller_declares_prototype` (+ `.patch`) | option B: caller-side list does not bind its own author |
| `09_citations_and_option_c_sites` | stale citations; sites option C would touch |
| `10_gleam_internal` | Gleam 1.12.0: no error; docs hidden only |
| `11_elixir_moduledoc_false` | Elixir: docs only; private call is a warning |
| `12_erlang_xref_and_moduledoc` | Erlang: no attribute; xref finds the edge post hoc |
| `13_elm_exposed_modules` | Elm: not reproducible; only `exposed-modules` exists |
| `14_rust_pub_in_path` | Rust: private mod / `pub(in path)` |
| `15_gen_big_tree.py`, `16_checker_cost`, `16b_check_microcost` | (d) cost |
| `17_eunit_on_the_copy` (+ `17_within_tests.erl`) | suite on option A copy; failures also on HEAD |
| `18_spoofed_module_name` | the check trusts the declared name; path check carries it |
| `19_go_internal_directory` | Go's `internal` semantics, run |
| `20_path_derived_internal` (+ `.patch`) | option A': no new syntax |

Trees: `probes/tree/` (Acme), `probes/tree24/` (ticket 24's Shop.Orders), `probes/exs/`, `probes/rs/`.
