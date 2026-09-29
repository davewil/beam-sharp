# Ticket 60 — Which modules may name this one? Decision brief

Ticket: [60](../wayfinder/issues/60-which-modules-may-name-this-one.md) · Linear ENG-242 · 2026-09-29
Status: decision open — for human review
Measured at `41b47c2`. Probes: `artifacts/probes/60/` (`./run.sh` prints PASS/FAIL per probe; captured in `results.txt`).

## 1. Sub-decisions the ticket implies, gating first

**(a) Is *who may name me* wanted now at all? This gates everything else and is asked alone.**
The ticket's own note says "not owed soon". Its stated consumer is ticket 24 §2's `unclassified`
helper (`RecomputeTotal/1`), which an agent writing tests will target because it is the easiest
thing in the directory to test. **Two facts move that consumer since 24 was written.**
24 §2 (line 219) says *"every function in an aggregate is exported today"*; F12 has since made
private the default, so that sentence is stale. Measured, P1b/P1c/P1e: a `private` helper is refused
from any other module and is fine from a sibling file of the same directory-module. So an
`unclassified` helper that is *private* cannot be named by a test module today. What is left of the
consumer is the helper made `public` so a **sibling module** can call it, which every module (tests
and vendors included) can then name (P2). The corpus pressure is thin: 8 native `using` lines in
the 77 `.bs` files of `compiler/examples` + `aoc`, no module with an `Internal` path segment.

Sub-decisions that follow only if (a) is yes:
**(b)** the unit: directory subtree, named group, or explicit list.
**(c)** the direction: callee says who may call it, or caller declares dependencies.
**(d)** a third visibility marker on the signature, or a module-level construct.
**(e)** the checker cost, which is answered by measurement in §4 and is not a decision.

Two answers are forced by probes, not by taste. **(d):** `public`/`private` are per signature and a
module-to-module rule cannot be per signature: 18 (lines 613-614) already found one entry label per
BEAM function, so the rule is a caller-side check either way. A word like `internal` after
`public`/`private` is a syntax error today (P1d, "nothing in between"). **(e):** the one site is
`add_import` (`bs_check.erl:490`; ticket 60's `bs_check.erl:407-425` is `add_module_import` at `:504`
now), because `using` is the only way to name another module (P2-Bypass: a qualified call with no
`using` is refused "called but never imported").

## 2. Probes

Every probe's expectation is written in `run.sh` above the probe, before its first run.
"Toolchain" is the real compiler or a patched copy of it unless stated.

| id | claim tested | expected before run | observed | file |
|---|---|---|---|---|
| P1a-e | private refused from B, public accepted, no third state; siblings in one directory see private | Pub accepted (7); `Lib.Priv` and unqualified `Priv` exit 1 naming `private`; `internal int F` a syntax error; sibling-file private call OK | as expected. `Go calls Lib.Priv/1, which Lib declares `private``; `syntax error before: int` | `p1/src/*` |
| P2 | under F15 layout any module may `using` any other | `Shop.Orders`, `Shop.Reports`, `Vendor.Tool`, `Tests.LedgerTest`, plus both namespace forms all print 101 though `Ledger` is under `Shop/Internal/` | all 6 exit 0, 101 | `p2/src/*` |
| P2-Bypass | `using` is the only gate | a call with no `using` (even transitively reachable) is refused | `Shop.Internal.Ledger is called but never imported`, exit 1 | `p2/src/Vendor/Bypass*` |
| P3 | `Owner.Internal.X` nameable only from `Owner`, `Owner.*` (patched copy) | Orders/Reports OK; Vendor.Tool, Tests.LedgerTest, `using Shop.Internal` refused; moving out of `Internal` flips it | as expected, `Shop.Internal.Ledger is internal to Shop`. One wart: `using Shop` then `Internal.Ledger.Post` gives "never imported, add `using Internal.Ledger`", which is not a fix | `p3/internal.patch`, `p2m/` |
| P3b | delta size | under 40 lines added | +28 -2, two files (`bs_check.erl` 21, `bs_diag.erl` 7) | `p3/internal.patch` |
| P3c | checker cost | guard under 10 us; tree compile median within 20% | guard 2.7 us; medians in §4 | `p3/time.erl`, `p3/gen50.py` |
| P4 | runtime emission unchanged | 51 beams, 0 differ except `CInf`; two controls | `files=51 differing_excluding_CInf=0`; same-compiler control 0; edited-body control **1** (only `M03`) | `p3/cmp_beams.escript` |
| P5 | rule is compile-time only | Erlang calls `'Shop.Internal.Ledger':'Post'(1)` = 101 | 101 | `run.sh` |
| N1-N3 | Erlang: unexported remote call unchecked at compile time, `undef` at run time, xref sees it | as stated in `n_erlang/probe.escript` | as expected (OTP 25) | `n_erlang/` |
| N4 | Elixir: `@moduledoc false` and `defp` across two mix apps | compile exit 0, only a warning for the `defp`, `mix run` prints 84 | as expected | `n_elixir/` |
| N5 | Elixir docs describe `@moduledoc false` as doc-hiding; `mix xref` reports, does not forbid | modes callers, trace, graph; no forbid wording | as expected | `n_elixir/docs.exs` |
| N6 | Gleam 1.12: cross-package use of an `internal` module and `@internal` fn is refused | **refused** (my prior belief) | **falsified.** `gleam build` exit 0, no warning; only the docs interface drops them | `n_gleam/` |
| N7 | Elm | not runnable offline | `PROBLEM LOADING PACKAGE LIST` | `n_elm/` |

The P4 first attempt of the edited-body control differed in all 51 beams because the `Line`/`Attr`
chunks embed the source path; the control now compiles from the same relative layout. That was a
bug in my control, not a change to an expectation.

## 3. Neighbouring languages

None of the neighbouring sources is installed (Erlang, Elixir: beams only; Gleam: binary only; Elm:
cannot fetch packages), so nothing below cites a source line. Each row is a probe.

- **Erlang.** Visibility is `-export`. N1: `erlc` accepts `shop_b`'s call to the unexported
  `lib_a:priv/0` and to the unexported remote type `lib_a:privt()` with no warning; N2: it dies with
  `undef` at run time. N3: xref, with `+debug_info` beams, reports exactly that edge under
  `undefined_function_calls`, and `xref:q(s, "XC | (Mod)vendor_c || (Mod)lib_a")` lists the edges
  from one module into another. A who-calls-whom policy is a query someone runs after the build;
  xref has no declaration that forbids an edge. (Gotcha: without `debug_info` xref silently analyses
  zero functions.) `-compile({no_auto_import,...})` concerns BIF name clashes, not caller policy, and
  was not probed.
- **Elixir 1.14.** N4: `@moduledoc false` and `@doc false` change nothing at compile time. A call
  from another app compiles and runs. The only refusal-shaped thing is a **warning** for a `defp`
  (`AppA.Hidden.really_private/1 is undefined or private`), exit 0. N5: `Module`'s own docs say
  `@moduledoc false` "will make the module invisible to documentation extraction tools". `mix xref`
  has three modes (callers, trace, graph), all reporting.
- **Gleam 1.12.** N6, path dependency: the compiler accepts `import lib/internal/secret` and a call
  to an `@internal pub fn` from another package, silently. What `internal` does is remove them from
  `gleam docs` / `package-interface.json`. The rule is *package*-scoped (hidden from other
  packages' view), with no compile error. Not measured: a hex dependency, or a same-package
  importer of an internal module beyond the trivial one that compiled in `lib` itself. The
  `internal_modules` key was tried once in a scratch run, where it *replaced* the default
  `<pkg>/internal` pattern; that run is not among the probes.
- **Elm 0.19.2.** N7: cannot run (package list unreachable). Not measured: exposing lists, and any
  who-may-import rule.
- **C#.** Not installed; no C# behaviour is asserted. The repo says: ticket 60 (line 32) that C#'s
  `internal` is assembly-scoped and B# has no assembly; ticket 22 (lines 433-435) that the useful
  boundary "is a different feature from C#'s `internal` and should not borrow its spelling without
  borrowing its semantics"; ticket 40 (line 295) that C# members default private.

**What the neighbours add up to, as measured.** Only one of the three toolchains that ran (Gleam) has
a who-may-see-me notion at all, and there it is package-scoped and hidden from the docs tool, not refused by
the compiler at build (a publish-time check exists in the binary, unprobed). Erlang and Elixir leave the policy to an after-the-fact query or a third-party tool.
So B# enforcing it in the compiler would be a first among the languages measured, not a copy.

## 4. Measurements

Units: wall milliseconds of `bsc:status/2` inside one VM (`timer:tc`), N=15 per cell after one
discarded warm-up, two rounds alternating unpatched (base) and patched (int). OTP 25. Tree:
`p3/gen50.py`, 51 modules (10 under `Shop.Internal.`, 40 chained, one aggregator), 209 `using` lines.

| round | compiler | min | median | max |
|---|---|---|---|---|
| 1 | base | 190.8 | 229.1 | 291.8 |
| 1 | patched | 204.0 | 256.3 | 287.4 |
| 2 | base | 218.8 | 237.2 | 305.2 |
| 2 | patched | 210.3 | 283.0 | 395.1 |

The difference is inside the run-to-run noise (**correction from the verifier:** an earlier version of this table came from an uncaptured run and said patched was not slower; both captured runs in `results.txt` show patched 12-19% slower in the median, while 12 interleaved blocks of N=20 in `probes/60/verify/compile_time_runs.txt` show medians indistinguishable, so the honest reading is *no consistent difference*, and the P3c 20% gate can flake). The guard
itself, `internal_ok/2` timed with `+export_all` over 1,000,000 calls net of loop overhead: **2.7 us
per import**, so 209 imports cost about 0.6 ms, roughly 0.2% of the ~250 ms compile.
Delta: **+28 -2 lines in two files** (guard and its two call sites in `bs_check.erl`; one
`built/2` clause and one `message/1` clause in `bs_diag.erl`). Emitted code: identical, P4.

## 5. Options

The gating question (a) is presented as its own option, because "no" is a real answer. Options B
and C both assume (a) is yes.

### Option 0. Not now (a = no)

Nothing is built. The `unclassified` helper is already handled by F12 in the private case (P1b,
P1e). An agent that needs a sibling *module* to call a helper must make it `public`; the corpus has
one such shared module (`Support.Triage`, used by 2 modules).

Compiler delta: none. Counterargument, strongest: the case that matters is precisely the one
private cannot express, a helper public to a sibling and not to the test directory or to Erlang,
and the drift an agent produces there (tests naming `public` helpers) is silent. It also becomes
more expensive to add after the corpus grows: a rule added later can be refused by existing code
(P3 shows `Tests.LedgerTest` and `Vendor.Tool` both compile today and would be refused).

### Option A. The path is the declaration: a `.Internal.` segment (callee side, unit = subtree)

The unit is the directory subtree of the module named before the `Internal` segment. No new
syntax, no marker, no construct: (b) is "subtree", (c) is "callee", (d) is "neither".

```
Shop/Internal/Ledger/Ledger.bs     module Shop.Internal.Ledger    public int Post(int)
Shop/Orders/Orders.bs              module Shop.Orders             using Shop.Internal.Ledger   // accepted
Shop/Reports/Reports.bs            module Shop.Reports            using Shop.Internal          // accepted
Vendor/Tool/Tool.bs                module Vendor.Tool             using Shop.Internal.Ledger   // refused
Tests/LedgerTest/LedgerTest.bs     module Tests.LedgerTest        using Shop.Internal.Ledger   // refused
```
```
Vendor/Tool/Tool.bs:3:1: error: Shop.Internal.Ledger is internal to Shop
  a module under `.Internal.` may be named only by Shop and the modules under it.
```

Compiler delta (all prototyped, `p3/internal.patch`):
1. `bs_check:add_import/7` calls `guard_internal(M, Self, L)` before `add_module_import/3`, and
   filters namespace-import children with `internal_ok/2` (the namespace `using Shop.Internal` is
   refused when nothing is visible).
2. `internal_owner/1`: split the module atom on `.Internal.`; the part before it is the owner.
3. `internal_ok/2`: `Self` equals the owner or starts with `Owner.`.
4. One error term `{internal_module, Mod, Owner, Line}`, one `built/2` and one `message/1` clause in
   `bs_diag.erl`. If this is built for real it also needs a term-diagnostic scenario (F16) and a
   corpus gate; those are not in the 28 lines.
5. Nothing in `bs_emit`, no atom, no attribute (P4).

Evidence: P3, P3b, P3c, P4 above. Moving the same module out of `Internal` (P3-moved) makes the
refused `Vendor.Tool` compile: the rule really is the path.

Strongest counterarguments:
- **A rename changes who may call it.** F15 already ties the `module` line to the directory
  (F15.5), so moving `Shop/Internal/Ledger` to `Shop/Ledger` is a policy change made by an
  ordinary refactor, and P3-moved shows it silently widens access. There is no marker to grep for.
- **The tests the ticket wants to steer are refused too.** `Tests.LedgerTest` above is refused. A
  test living outside `Shop.` cannot name an `Internal` helper, so the rule pushes tests into the
  `Shop.` subtree; that is good for the drift and bad for anyone who wants a separate test tree,
  and where a test lives is still an open patch (24, line 402).
- **Enforced only at compile time.** P5: an Erlang caller names the internal module freely, and
  ticket 62's outbound ABI makes every B# export an ordinary `.beam` export.
- Diagnostic wart from P3: filtering namespace children yields a misleading "add `using`" message
  for `using Shop` then `Internal.Ledger`; raising the error instead of filtering fixes it for a few
  more lines (not built).
- `Internal` becomes a reserved-in-effect path segment. Measured: zero `.bs` files in the repo use it.

### Option B. An explicit list on the callee (unit = named modules, module-level construct)

The callee names its callers in its own `index.bs`, next to `using`, `type`, `record`,
`behaviour` (F15 lets `index.bs` hold no functions, so it is where module-level facts already go).
`friends` is a placeholder spelling. Not prototyped; the delta below is estimated from the
existing shape, not measured.

```
Shop/Ledger/index.bs     module Shop.Ledger
                         friends Shop.Orders, Shop.Reports
Shop/Ledger/Post.bs      module Shop.Ledger      public int Post(int)
Vendor/Tool/Tool.bs      module Vendor.Tool      using Shop.Ledger      // refused: not in friends
```

Compiler delta (estimated): a `friends_decl` production in `bs_parser.yrl` and a lexer word (a keyword cost; ticket 22's 'sixteenth keyword' sentence concerns `incomplete`, not a marker, so it is not a precedent either way); one key `friends` in the World entry
beside `exports`/`private` (the F12 `private` table is the precedent); the check in `add_import`
reading `maps:get(friends, maps:get(M, World))`; the same error term as A; all three editor grammars
(F12 had to land lexer and grammars together). Directory moves do not change policy.

Strongest counterarguments:
- It is an explicit list that must be edited every time a module legitimately starts to use the
  callee: the file an agent edits to "get it compiling" is the file that guards the rule. A refusal
  the author can clear by editing the guard is closer to a lint than to F12's `private`.
- It is a new keyword and a grammar rule where A adds nothing; the repo has declined keywords for
  much less (cf. ticket 22, which declined a keyword for `incomplete`).
- Same bypass as A (P5).

### The direction question (c), folded in

The caller-declares direction is `using`'s own job (41 §1: "a file's `using` lines are its
dependency list"), so a rule there is an **allowlist on the caller** (`Shop.Reports` may use only
these). It answers *"what may this layer depend on"*, not the ticket's consumer, which is a
*callee* that wants to be unreachable by whichever module an agent adds next: an allowlist does
nothing about a new module the author of the callee never heard of. That is the reason the options
above are callee-side. It is a judgement from the probes (P2: today a new module can name anything),
not a measured result.

## 6. Recommendation

Answer (a) first, alone. **My recommendation is no, not now (Option 0)**, and to record in the
ticket that private-by-default already covers the `unclassified` case of ticket 24: P1 shows a test
module cannot name a private helper, and 24 §2's "every function is exported today" was overtaken
by F12. That satisfies CLAUDE.md's reading of progress: no exemplar, audition ticket or editor
capability depends on this today. If David answers yes to (a), **Option A** is the cheap answer:
28 added lines, no grammar, no runtime, and no measurable compile-time cost, and its worst
counterargument (a rename widens access) is a diagnostic-and-gate problem, not a design flaw. B is
the answer only if David wants a visible marker and accepts a keyword.

## 7. Not measured / limits

- All probes ran on **OTP 25**; the tickets cite OTP 28. Nothing here depends on OTP version, but
  it is unverified on 28. Elixir 1.14 and Gleam 1.12 (tickets used Gleam 1.18.1 for 62a).
- **Verifier notes:** the foreign route `using :'Shop.Internal.Ledger' {..}` to a B# module and a top-level `Internal.X` module with no owner were not probed; N7 'PASS' means only that Elm cannot run offline (NOT MEASURED); P1d shows any unknown word in the marker slot gives the same syntax error.
- **Elm not measured** (no package list offline). **C# not measured** (not installed); only quoted
  from repo documents with line numbers.
- **Gleam:** only a *path* dependency was tried. A hex dependency (where `internal` may be treated
  differently) and a same-package importer were not measured beyond the compile of `lib` itself.
- Option B, the caller-allowlist direction, and the misleading-diagnostic fix were not built; their
  costs are reasoned from the existing shape.
- The 51-module tree is synthetic (chained `using`, 3 internal imports per module); real trees may
  have wider fan-in. The compile-time result is "no measurable difference at 209 imports", not a
  bound for larger trees.
- The prototype was applied to a copy; `compiler/` was never edited. It was not run through
  `bin/verify.sh`, and no `--self-test` gate was written (CLAUDE.md requires one before any real
  implementation).
- Citation note: ticket 60 attributes the elision finding to 18 §5; the finding is at
  `18-boundary-defence.md` lines 439-440 and 613-614, and §5 (line 852) is "No opt-out". Ticket 22
  cites `bs_check.erl:407-425`, now `add_module_import/3` at `:504`.
- `P3c`'s compile-time pass criterion (within 20%) is loose by design; the numbers are in §4.

## 8. Reproduce

```
cd /home/user/beam-sharp/artifacts/probes/60 && ./run.sh        # all probes; ends "ALL PROBES PASS"
```
Environment: defaults point at the session scratchpad (`SP`, with `bsc.sh` and `bsc/gen`),
`/tmp/claude-0/tools/gleam`, and `/tmp/claude-0/tools/node_modules/.bin/elm`; override via `SP`,
`GLEAM`, `ELM`. The script builds the base and patched compilers from `$REPO/compiler/src` plus
`p3/internal.patch` into `/tmp/claude-0/p60run`. Individual probes:
`p1/src`, `p2/src`, `p2m/src` (with `bsc.sh --src-root src -o OUT src/<Mod> <Fn> <arg>`);
`p3/gen50.py DIR` builds the 51-module tree; `p3/cmp_beams.escript A B` compares beams;
`n_erlang/probe.escript`; `n_elixir/docs.exs`.
Captured output of the last run: `artifacts/probes/60/results.txt`.
