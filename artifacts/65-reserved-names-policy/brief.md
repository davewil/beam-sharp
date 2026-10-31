# Decision brief: ticket 65 (ENG-255), reserved names

Prepared 2026-10-30 for human review. Nothing here resolves the ticket. The ticket file, Linear and the
repo are untouched; everything lives under `artifacts/65-reserved-names-policy/`.

Environment: Erlang/OTP 25, Elixir 1.14.0 (compiled on OTP 24), rebar3. `bsc` could not be built here (it needs
OTP 27+ leex), so **nothing in this brief was run through the B# compiler**. Every B# compile/refuse outcome below
is read from compiler source and feature files, and says so.

---

## 0. The ticket's premises are stale. Read this first.

The ticket (raised 2026-08-25) says *"B# reserves no name today. 48 decided `Map` becomes the first."* Since then:

| Ticket text | Repo now | Where |
|---|---|---|
| "reserves no name today" | `bs_check:reserved_qualifiers() -> ['List','Map','Term','Float']`, plus the protocol name `Enumerable`; 5 bare names refused | `compiler/src/bs_check.erl:1699`, `:241-254`; `probes/p6_*.out` |
| "is the standard environment closed by intent?" is open | Asked and answered twice, in opposite directions. 67 (2026-09-03): "closed by construction". 96 Q6 (2026-09-25, David): breadth is in scope and **"every qualifier the standard environment adds is reserved ... this answers ticket 65's first question by rule"** | `67-...md` Decisions entry; `96-...md` lines 189-212 |
| "a user cannot declare `module Map`" is a decision | It is built and refuses the declaration. Bare name only; `Shop.Collections.List` stays legal (67 Q6) | `F32-reserved-qualifiers.md`, `bs_diag.erl:1385-1397` |
| `Map.Get` emits `'Map':'Get'(M,K)` | Superseded. Standard operations lower to the OTP function that already does it (`lists:reverse`, `maps:put`, `erlang:map_size`). **No `List.beam` or `Map.beam` exists** | F62 header; `bs_check.erl:1706-1770` |

So 65's first question is no longer "closed or not". The answer that stands (96 Q6) is: **the set accretes, at the
compiler team's pace, and every addition is reserved.** What is left for this ticket is smaller and sharper:

> Having reserved bare names that grow from 5 toward roughly 16, do we keep paying the price in user module
> names forever, or change the unit of reservation? And is the question about *module names* at all, given that
> the ticket's five-language evidence is about *unqualified* names?

---

## 1. Sub-decisions, and which of them the evidence settles

**1a. Closed vs accreting.** Settled by 96 Q6 toward accreting. The names tickets already plan to add, found by grep:
`Enum String Int Process GenServer Supervisor Logger System` (96 Q6), `Binary` (93), `Task` and `Agent` (98), `Stream`
(17, as an example only). That is 11 firm plus 1 candidate on top of today's 5. `probes/p7_*.out` has the grep
evidence.

**1b. Reserve vs shadow vs unreachable namespace.** Open. Section 2 gives the programs.

**1c. What "shadow" means on the BEAM when a module name is the atom.** Probed. This was the suspected decisive point
and **it is not decisive for B# as built**, for these reasons:

- A user `module List` would emit the atom `'List'` (F11: `module Shop.Orders` emits `'Shop.Orders'`). The standard
  `List.Reverse` emits `lists:reverse`, which is the atom `lists`. The two atoms are unrelated, so at the VM level
  **nothing the user can name collides with anything the standard environment calls.** `probes/p5_*.out` section B shows
  the contrast: a caller written in the rejected "shipped module" shape (`'List':'Reverse'(Xs)`) dies with `undef` as soon as
  a user `List.beam` is first on the path, while a caller in the F62 shape (`lists:reverse(Xs)`) is unaffected.
  **Caveat: p5's callers are hand-written Erlang in the shape F11/F62 describe. They are not bsc output.**
- The BEAM does have a hard, loud answer when the names *do* meet, and it is not "shadow". An Erlang module named
  `lists`, `maps` or `string` compiles (`erlc` exit 0) but can never be loaded beside OTP's: `code:load_file/1` and
  `code:load_binary/3` return `{error,sticky_directory}`, and a VM started with the user's dir via `-pa` does not boot
  (`Kernel pid terminated (logger)`, exit 1). With `-pz` the OTP module wins silently. `probes/p2_*.out` A-D, G.
- Where the BEAM does let two beams share a name, **path order decides silently** (`-pa` last-added wins; `-pz`
  first-added wins), a second `load_binary` replaces the first with no error, and the only diagnostics are the opt-in
  `code:clash/0` and a release build's `{duplicate_modules,...}`. `probes/p3_*.out`. This is the real BEAM-level hazard
  for B#, but it is **user package against user package** (two packages both declaring `module Json`). It is the same
  under every option below, so it is out of scope for this ticket and is worth its own ticket.

So "shadow" for B# is a *resolution* rule inside the checker, not a loader behaviour. That is good news mechanically.
The cost is elsewhere, in section 2, option B.

**1d. The object being reserved.** The ticket's five-language table (Haskell `+`, Rust trait methods, Scala root
context, Elm default imports, Erlang built-in types) is about **unqualified** names. 67 settled that nothing
unqualified in B# is a function. What B# reserves is a **qualifier prefix**, and only as a *whole module name*. The
table is evidence about a different object. The one row that is about names of this kind is Elixir's `defmodule Map`
(probe p1), and that is evidence about an *unprotected* namespace, which no option below proposes. Section 5 spells the
limit of this out.

---

## 2. The options, as programs

Common setup, the same in all three:

```csharp
// Billing/Invoice.bs
module Billing

using Shop.Text                // brings Shop.Text.String in as `String`

public string Clean(string s)
Clean(s) -> String.Trim(s)     // the author means the standard operation
```

### Option A. Reserve, accreting (what is built; 96 Q6 as answered)

```csharp
// String/String.bs
module String                  // refused at the declaration:
                               //   error: `String` is a reserved qualifier, so no module may be called it
                               //   ... `Shop.String` is still legal
// Shop/Text/String.bs
module Shop.Text.String        // compiles: only a WHOLE module name is reserved
```

Behaviour read from source, not run: `reserved_module_name/2` runs before `module_matches_path/3`, so
`Foo/String.bs` and `String/String.bs` get the same answer (F32 notes this). The diagnostic text is at
`bs_diag.erl:1385-1397`. The call-site collision for the dotted case, `using Shop` beside `String.Trim`, is the 67 Q6 (iii)
check at `bs_check.erl:3290`.

**Compiler must gain for each new qualifier:** one atom in `reserved_qualifiers/0` and the rows in `standard_table/0`. Gate
rows P3-P6 of `check-reserved-qualifiers.sh` extend by name (96 Q6). Nothing else.

**Measured:**

| | |
|---|---|
| reserved bare names today | 5 (`List Map Term Float Enumerable`), 30 table rows (List 16, Map 12, Term 1, Float 1) — p6 |
| beams/atoms shipped for them | 0 — nothing is loaded; the 30 rows target existing OTP functions (F62) |
| check cost | `lists:member` over N names, once per compile; 1000-module tree: 12 us at N=4, 192 us at N=100, 3.5 ms at N=1000. A map lookup is flat (8-10 us) at every N — p6 |
| repo corpus affected by today's set | 0 of 112 bare module declarations (p7) |
| repo corpus affected once the planned set lands | 1 of 112: `compiler/examples/Stream/stream.bs`, and only if `Stream` (an example in ticket 17, not a decision) is added — p7 |

Cost conclusion from p6: the lookup is not a reason to prefer any option. A linear list stays under 4 ms until the set
passes 1000 names, which is two orders of magnitude beyond anything planned.

### Option B. User names win (shadow)

```csharp
// String/String.bs
module String                  // compiles under B
public string Trim(string s)
Trim(s) -> ...

// Billing/Invoice.bs
module Billing
using String                   // or reached by its full path, which is just `String`
Clean(s) -> String.Trim(s)     // the user's, silently or by a call-site error
```

Under B the declaration is allowed and the 67 Q6 (iii) call-site check generalises. That check's escape is printed in the
existing diagnostic: *"write the module's full path to reach it"* (`bs_diag.erl:1405-1413`). The escape works for
`Shop.Text.String` only because its full path differs from the reserved word. For a bare `module String` the full path
**is** `String`, so **no spelling reaches the standard operation** and the user's module takes `String.*` for every
module that can see it. To make B coherent, the standard operations need a second spelling, which makes B depend on the
"namespace the user's syntax cannot reach" idea in the ticket's option 2.

**Compiler must gain:** the declaration check moves to the call site for bare names; the diagnostic loses its "write the
full path" fix for bare modules; and a second spelling for standard operations (a symbol-table entry for each
qualifier under a reserved prefix, plus a grammar production, since `bs_parser.yrl:626-667` accepts only `Uident(...)`,
`Path.Uident(...)` and `:atom.lident(...)`). Which modules "see" a bare user module (`using String` or by path) was
not probed, because bsc could not run.

**Measured:** at the BEAM level, nothing to fear (p5 B, F62 caller). Cost of the extra spelling: no number, since it is
unbuilt.

### Option C. Reserve, with a warning window before a new name takes effect

```csharp
// compiled with a bsc that has just added `Stream`
module Stream                  // warning: `Stream` becomes a reserved qualifier in the next language edition;
                               //          rename to e.g. Shop.Stream. Compiles now.
```

This keeps A's rule and removes the one real cost of accretion, a release that breaks a working program. Edition
mechanics are a known pattern from Rust (2021 and 2024 preludes, cited in the research file, INHERITED).

**Compiler must gain:** a `{Name, SinceEdition}` table beside `reserved_qualifiers/0`; a `--edition` setting or a
`bsc.config` key; one warning tier in `bs_diag`. `reserved_module_name/2` becomes a three-way result
(`reserved | reserved_soon | free`).

**Measured:** the only data point is p7, 1 of 112 corpus declarations. A one-in-a-hundred miss rate is the evidence
for *and* against C: low enough that rename is trivial in this repo, with no data about a user ecosystem that does
not exist yet.

---

## 3. Strongest counterargument, per option

- **Against A.** It is the only option where a *future compiler release* can turn a working program into an error. Rust
  needed editions for exactly that, and Haskell abolished `PreludeCore` after the same complaint. The reply that the
  compiler team controls the pace is true, but not a safeguard against a third-party library that already ships
  `module Logger`. A also has no answer if the set grows to the Elixir-sized `Kernel` namespace; the grep above shows
  11 more names are already on paper.
- **Against B.** The reserved word `String` is useful because every B# reader knows `String.Trim` means the standard
  operation. Under B, whether that is true depends on which modules a file can see, and the existing diagnostic's own fix
  ("write the full path") does not exist for a bare name. B also inherits the Elixir symptom p1 shows, in a milder form:
  the crash there came from library code that had no way to write a different spelling. B# standard operations are
  inlined at the *user's* site, so a clobber cannot take down the compiler, but the user loses the standard operation
  with no recourse.
- **Against C.** It pays a build (edition table, flag, warning tier) to protect an ecosystem of zero third-party modules,
  and the project's own rule is that a check needs a second occurrence of the failure it names. The first release that
  actually breaks someone is the second occurrence.

---

## 4. Recommendation

**Option A, as built, and close the ticket on the record that it is already answered.** Reasons, in order:

1. The gating question has an answer on record from the decider (96 Q6): the set accretes and every entry is reserved. The
   ticket's own premise ("closed by intent") would have favoured A anyway.
2. The BEAM-level hazard that would make A the only safe choice (module name = atom) does not apply to B# as built, so
   the choice is free to be made on language grounds, and on those grounds a reserved word that always means the standard
   operation reads best.
3. The only measured cost of A is 1 corpus module (and only for a name that is not yet decided). Option C's mechanism
   can be added later without changing any program that compiles today; B and A cannot be swapped later without
   breaking programs.
4. Option B requires option 2's unreachable spelling to be coherent, and that is a grammar change for a problem not yet
   observed.

What the ticket should record, if A is chosen: the premises in section 0 are stale, the reserved set is 5, and the
unit is the whole bare module name. Section 6 lists two adjacent questions this does not settle.

---

## 5. Limitations, stated plainly

- **Not run through bsc.** No B# program in this brief was compiled. Compile/refuse behaviour for B# is read from
  `bs_check.erl`, `bs_diag.erl` and feature files at HEAD `c07bb7f`.
- **The Elixir claim is confirmed in substance on 1.14, not on the ticket's version.** The ticket's 1.19.5 crash was in
  `lib/module/types.ex:291` calling `Map.update!/3`. On 1.14.0 the type checker (`Module.Types`) of that vintage does not
  exist in the same form; what crashed here was `Module.ParallelChecker` (`parallel_checker.ex:373`) calling
  `Map.new/1`, and `elixirc` died inside `Code.Formatter.state/2` calling `Map.new/2`. Same class of failure, different
  function, different file. Elixir sources are not installed on this machine (only `ebin`), so there is no file:line for
  Elixir's redefinition warning beyond the runtime text printed by p1.
- **Absolute timings** are from one run on one VM; read the shape, not the microseconds. `escript` was forced to
  compiled mode (`-mode(compile)`); an interpreted first attempt was ~100x slower and is not reported.
- **The set evidence is from this repo's corpus only** (163 `.bs` files, 112 bare module declarations), which is the
  project's own exemplars and fixtures, not an ecosystem.
- **The five-language table was not re-verified** (section 7).

## 6. Adjacent questions this brief did not settle

1. **Type names.** `option`, `result`, `foreign_error`, `int`, `string` and the rest are *unqualified*. Whether a user
   `type option<T> = ...` is refused, shadows, or collides was **not probed**. Reading `bs_diag` shows `type_redeclared`
   only; no "reserved type name" tag. This is the case the ticket's evidence table (OTP 26 type shadowing, Rust
   preludes) actually speaks to, and it is not the same question as the module one. It deserves its own look rather than
   riding on this ticket's answer.
2. **Package against package.** p3: two user packages with the same module name resolve by path order, silently.

---

## 7. Claims table

| # | Claim | Evidence |
|---|---|---|
| 1 | Elixir 1.14 `defmodule Map` warns ("redefining module Map") | `probes/p1_elixir_defmodule_map.out` |
| 2 | ...clobbers the standard module: `Map.update!/3` no longer exported; `:code.which(Map)` is `[]` | p1 section A |
| 3 | ...and the language's own tooling crashes: `Module.ParallelChecker` calls `Map.new/1`, `elixirc` crashes in `Code.Formatter.state/2` | p1 sections A, B. **Differs from ticket:** other function and file, same class |
| 4 | Ticket's "`types.ex:291` / `Map.update!/3` on 1.19.5" | INHERITED from ticket 48 `## DECIDED ... Q9`, not re-executed |
| 5 | `erlc` compiles a user module named `lists`/`maps`/`string` with exit 0 | p2 section A |
| 6 | Loading it into a running OTP 25 VM returns `{error,sticky_directory}` and logs "Can't load module ... that resides in sticky dir" | p2 B, C; source `kernel-8.5.4.2/src/code_server.erl:1118-1122` |
| 7 | `is_sticky/2` is `module_loaded` plus a `{sticky,M}` ets entry | `code_server.erl:1076-1077` |
| 8 | Boot-time marking of library dirs as sticky | `code.erl:732` (`maybe_stick_dirs`); the mechanism is read, only its effect is probed (p2) |
| 9 | VM started with the user dir via `-pa` fails to boot (logger crash, exit 1); `-pz` leaves OTP's module winning | p2 D, with control G proving `-pa` alone is fine |
| 10 | `-mode embedded` with the user dir also fails to boot | p2 E |
| 11 | `-compile({no_auto_import,[F/A]})` resolves the local-vs-auto-imported-BIF clash; without it erlc errors | p2 F; `stdlib-4.3.1.3/src/erl_lint.erl:272-286` |
| 12 | Two beams of the same name: `-pa` last-added wins, `-pz` first-added wins, `-pa` beats `-pz` | p3 A |
| 13 | `code:clash/0` reports "X hides Y" | p3 B; `kernel/src/code.erl:965-969` |
| 14 | A second `code:load_binary` of the same name replaces the first with no error | p3 C |
| 15 | A release build over two apps containing the same module fails with `{duplicate_modules,...}` | p3 D; `sasl-4.2/src/systools_make.erl:992` |
| 16 | Whether any common build tool (rebar3, mix) runs `code:clash` | **UNPROBED** |
| 17 | OTP 25 refuses a user type with a built-in's name ("type map() is a builtin type; it cannot be redefined") | p4 A; `erl_lint.erl:2985-2998` |
| 18 | OTP 25 has an opt-out, `-compile(no_auto_import_types)`, under which the definition compiles | p4 B; `erl_lint.erl:2984-2986` |
| 19 | Under that opt-out the user type is reported *unused* though `-spec` mentions `map()`, so uses still resolve to the built-in | p4 B. **An inference from the warning, not an independent test** |
| 20 | OTP 26 "permitted a user type to shadow a built-in type name" | **INHERITED** from the research file / ticket; OTP 26 not available, not tested |
| 21 | A hand-shaped `'List':'Reverse'` caller breaks (`undef`) when a user `List.beam` precedes the stdlib one; a `lists:reverse` caller does not | p5 B. **Hand-written Erlang simulating emitted shape, not bsc output** |
| 22 | bsc lowers `List.*`/`Map.*` to OTP calls and ships no `List.beam`/`Map.beam` | F62 header and `bs_check.erl:1706-1770` (source-read, not run) |
| 23 | Reserved qualifiers = `List Map Term Float`; protocol names (`Enumerable`) are also refused as whole module names | `bs_check.erl:1699`, `:241-254`; p6 extracts these by parsing the source |
| 24 | `standard_table` has 30 rows: List 16, Map 12, Term 1, Float 1 | p6 |
| 25 | A lookup over a 1000-module tree costs 12 us (list, N=4) to 3.5 ms (list, N=1000); a map is flat at 8-10 us | p6 (hit counts cross-checked against an independent comprehension; the script exits 2 on mismatch) |
| 26 | 0 of 112 bare module declarations in the repo's `.bs` files are refused today; 1 (`Stream`) would be under the planned-or-candidate set | p7 |
| 27 | The planned names (`Enum String Int Process GenServer Supervisor Logger System`, `Binary`, `Task`, `Agent`) | p7 greps tickets 96, 93, 98; `Stream` is an example in ticket 17 line 396 only |
| 28 | 96 Q6 answered "yes", reserving every added qualifier | `wayfinder/issues/96-standard-environment-breadth.md` lines 189-212 |
| 29 | The existing collision diagnostic's fix is "write the module's full path" | `compiler/src/bs_diag.erl:1405-1413` |
| 30 | A bare `module String`'s full path equals the reserved word, so that fix is unavailable for it | **Reasoned from claim 29 and F11; not run** |
| 31 | Which modules would "see" a user bare module, and whether `using String` is required to call it | **UNPROBED** (bsc unavailable) |
| 32 | A user `type option<T>` is / is not refused | **UNPROBED** |
| 33 | Haskell, Rust, Scala, Elm "landed on user names must win" and how | **INHERITED** from `wayfinder/research/prelude-the-word-across-languages.md`, not re-executed |
| 34 | Gleam, Elm, Scala, Haskell, Rust behaviour with a user module named like a standard one | **UNPROBED** (gleam and elm not installed; others not installed or not attempted) |

---

## Decision left open for human review

This brief recommends; it does not decide. What is yours to settle:

1. **Is ticket 65 already answered** by 96 Q6 plus built F32/F62, to be closed with an entry that corrects the stale
   premises, or does it stay open for option C (a warning window) or B (shadow plus a second spelling)?
2. **If A:** is "the whole bare module name only" the permanent unit, or may a later set reserve path segments
   (67 Q6 declined this; it is not re-argued here)?
3. **Type names** (section 6.1) get their own ticket or are folded into this one.

Probes: `probes/p1_elixir_defmodule_map` · `p2_erlang_user_module_named_stdlib` · `p3_same_module_two_paths` ·
`p4_otp25_builtin_type_shadow` · `p5_emitted_call_collision` · `p6_reserved_set_size_and_cost` ·
`p7_corpus_collision_with_planned_qualifiers` (each `.sh`/`.escript` with its `.out`).
