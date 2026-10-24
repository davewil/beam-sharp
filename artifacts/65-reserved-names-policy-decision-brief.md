# Decision brief — ticket 65: reserved names, the policy

**Ticket** [65](../wayfinder/issues/65-reserved-names-policy.md) · **Linear** [ENG-255](https://linear.app/davewil/issue/ENG-255) · **Brief date** 2026-10-23 · **Revised** the same day after an independent re-run
**Status: DECISION OPEN — for David's review; nothing resolved.** No ticket, feature, glossary or Linear state was changed.

Toolchain: Erlang/OTP 28.5 (erts 16.4, built from `otp_src_28.5`), Elixir 1.19.5, Gleam 1.18.1, `bsc` built from this repo's
`compiler/` at `c01d51f7`. Elm 0.19.3 is installed but could not compile anything (see the last section). Probes are in
[`probes/65/`](probes/65/); each prints its evidence, **asserts its expectation and exits non-zero on a mismatch** (65a, 65d, 65e,
65f — *what* each asserts is in the ledger; 65b, 65c, 65g, 65h and 65i report figures), and has a captured `65x_output.txt` beside it. Every figure below is from those files.

## The answer first

**Ticket 65 has been half-answered, and the other half has no other owner. Do not close it as answered.**

*Answered.* The ticket's two questions about the qualifier names: [ticket 67](../wayfinder/issues/67-stdlib-shape-as-a-principle.md) Q1
answers *closedness* (*"closed by construction"*), and [ticket 96](../wayfinder/issues/96-standard-environment-breadth.md) Q6 (lines
206-209, 253) answers *the reservation rule* — *"what the standard environment qualifies is reserved, and nothing else"*, on 67 Q6's
terms (whole name only). **It takes both: 67 says three times that the policy stays 65's own (67:229, 388, 465); only 96 Q6 closes
it.** [F32](../compiler/features/F32-reserved-qualifiers.md) built it. Reserved today: **`List Map Term Float`** as whole module
names, the protocol **`Enumerable`**, and **30 operation rows** (65a, 65h).

*Not answered, and other documents point at 65 for it:*

| Still 65's | Who handed it over | What the probes show |
|---|---|---|
| **`not` as an identifier** | F27:40-46, LANGUAGE.md:334, ticket 63:406 — *"`not` stays an identifier until 65 says otherwise"* | `Go(int not) when not > 100` compiles and runs (65a §G) |
| **the `bs@` export prefix** | ticket 87:166-170, F55:172-174 | `public int bs@x(int n)` is already refused, as `illegal characters "@"` (65a §H); nothing to build, something to *record* |
| **module names that shadow OTP modules** | F54:171, F55:172-174 | `module Lists / Maps / Erlang / Peer / Json` all compile (65a §F). **Two of this repo's own examples are the live instance:** `module Queue` and `module Math` differ from OTP's `queue` and `math` only by case (65h compares lowercased names; the atoms stay `Queue` and `Math`). **On this case-sensitive disk there is no clash** — `code:which(queue)` is the stdlib's. The hazard (ENG-391, F54:171) needs a case-insensitive filesystem, or `Queue.beam` copied ahead of stdlib on the path; a verifier simulated the second and the VM died at boot with *module name in object code is Queue*. I did not reproduce either |
| **when a planned name becomes reserved** | 96 Q6 says *"every qualifier the standard environment adds"* and is silent on timing | the gating question below |

**Closing 65 would strand the first three**, and F27, F54 and F55 would keep saying *"ticket 65, which is open"* with nobody to
answer them. The recommendation (end of brief) is therefore a *decision to take*, not a closure.

## The gating question — alone

> **Is a qualifier's name reserved when it is *decided*, or only when it is *built*?**

Both readings of 96 Q6 are available, and the repo already did the first once. `LANGUAGE.md:2160-2162`: *"`Map` was reserved before it
had an operation — reserving it later would have meant taking it away from a program that had already used it."* F32 reserved
the name `Map` with its operations unbuilt (F32 header, *Leaves*). The other eleven planned names are not reserved:

```csharp
module Shop.Text.String                      // legal today: the path is not the reserved word
public int Length(int s)  ...

module A
using Shop.Text
Go(n) -> String.Length(n)                    // today: calls Shop.Text.String.Length   -> 98
                                             // after `String` is reserved: refused —
                                             //   "Go calls String.Length, and `String` means two things here …
                                             //    Shop.Text.String.Length"
```

Probe 65c, scratch compiler with the roster added. Two other spellings survive unchanged (`using Shop.Text.String` then
`Shop.Text.String.Length(n)`, and `using Shop.Text.String` then bare `Length(n)`: `98` before and after). A module *declared*
`module String` has no survivor: refused at the declaration, rename only.

## Sub-decisions, in dependency order

| # | Sub-decision | Position | Status |
|---|---|---|---|
| 1 | Reserve when decided, or when built? | **gating** | open |
| 2 | If when decided: which names — the ten in *resolved* tickets, or also `Binary` (93, open)? | follows 1 | open |
| 3 | `not`: stay an identifier (F27's holding position, 63's *"the absence teaches"*) or become reserved | independent | open — 65's |
| 4 | `bs@`: record that the lexer already makes it unwritable | independent | open — 65's, answerable by a sentence |
| 5 | Module names that differ from an OTP module only by case: refuse, or leave | independent | open — 65's; the corpus has two |
| 6 | Does the reservation reach types / records / functions named like a qualifier? | independent | measured: they coexist (65a §B2); see below |
| 7 | Do user names win a collision (ticket option 3)? | independent | prototyped, three ways (65g) |
| 8 | An unreachable namespace (ticket option 2) | independent | measured; not offered |
| 9 | Lowercase builtins refused as a bare `syntax error` | independent, small | a diagnostic, not a decision |

## What is reserved today (65a — real programs through `bsc`; 48 expectations, 48 as expected)

```
module List / Map / Term / Float   rc=1  "`List` is a reserved qualifier, so no module may be called it"
module Enumerable                  rc=1  "`Enumerable` is a protocol, so no module may be called it"
module String Enum Int Process GenServer Supervisor Logger   rc=0   (free today — controls)
module Shop.List, module List.Shop rc=0   (67 Q6: only the whole name is burned)
```

**Compiler-known types and functions are refused too, so user-loses already exists outside the qualifier set** (65a §E):
`type ValidationError = int`, `type Down = int`, `type Exit = int` → *"is a compiler-known type and cannot be redeclared"*
(`bs_check.erl:1372` `stratum_two`, `:1832`); `public int ToExistingAtom(…)` → *"is a compiler-known function and cannot be declared"*
(`:3486`). Controls: `type Foo`, and the other obligation names `ValidateAs`, `Raise`, `ToJson`, `FromJson` as user function names
all compile. So B# already burns names for types and one function; it does not do so uniformly.

**A type, record or function named `Map` or `List` coexists with the qualifier** (65a §B, §B2): `Pick(Map m)` beside
`Map.Size(...)` returns `2`; `List(n) + List.Length([n, n])` returns `103`. The qualifier position `Name.Op(` is syntactic, so the only
ambiguity is a module name, which is already refused. That is why sub-decision 6 is "measured: no collision", **not** "not needed":
`ValidationError` and `Down` are refused for a different reason (they are resolved by name in type position).

**Lowercase builtins are a second reserved class, and it is lexical** (65a §D): `type option = int`, `record list {…}`,
`public int map(…)`, `module list` are refused — as the bare `syntax error before: option` (`bs_lexer.xrl:1-9`). That is the only
"namespace the user's syntax cannot reach" B# has, and it is the one ticket 48 Q9 option (d) pointed at (*"lowercase functions for the
prelude alone, mirroring what the type prelude already does"*, `48:1077`).

## The set is closed to outsiders and grows from within (65b)

Read from the history of `bs_check.erl` (150 commits touch it; 967 in the whole repository — `git rev-list --count`, 65h) (the clone was shallow; `git fetch --unshallow origin` was run, and the probe
refuses a shallow clone because a 50-commit curve would be flat for the wrong reason):

```
2026-08-13  none                       0 rows
2026-09-04  List Map Term              4          F32
2026-09-16  List Map Term Float        8          the one qualifier added after founding
2026-09-25  List Map Term Float       10          ticket 96
2026-10-21  List Map Term Float       30          F75: 20 rows in one day
```

Qualifiers 0 → 3 → 4 by 09-16, flat for the 37 days since. Rows 0 → 30. `Enumerable` (protocol table) first appears
2026-09-28 (65h). Nothing a user ships ever joins the set (67's closedness), but 96 queues more on the compiler's own schedule.

## Options (for the gating question and sub-decision 2)

### A — Reserve when built (the literal reading of 96 Q6).

**Code.** The program above: valid today, refused on the day, the full path printed as the fix.
**Compiler delta.** None today. Each landing adds one atom to `reserved_qualifiers/0` (`bs_check.erl:1701`) and its rows to
`standard_table/0` (`:1709`) and `declared_rows/0` (`:1724`), and extends P3–P6 of `compiler/bin/check-reserved-qualifiers.sh`.
**Evidence.** 67 Q6 chose this break for `List` (*"`Totals.bs` and `LANGUAGE.md:139` then go red on the day"*); the break is loud —
the only program that changes meaning changes into an error (65c). Gleam reserves one module name, `gleam`
(`compiler-core/src/analyse.rs:1769-1772`, `type_/prelude.rs:31-33`) and refuses a user `gleam/list` as a duplicate (65f case 4).
**Strongest counterargument.** (1) The repo's own precedent, `LANGUAGE.md:2160-2162`, is the opposite: it reserved `Map` *before* its
operations, for exactly this reason. (2) Until a name lands the compiler gives the wrong fix — `String.Length(n)` with no user `String`
prints *"String is called but never imported — add `using String`"*, advice that can never work once `String` is reserved (65c, last
section). (3) For the clean-room handoff the oracle's reserved list changes under a fleet that was told what was reserved. I have no
run of a fleet hitting it, so (3) is an argument, not a measurement.

### B — Reserve when decided (the `Map` precedent), narrowly.

**Code.** The same program; `module String` is refused now instead of on the day. `String.Length(n)` with no user `String` prints,
from the scratch compiler (65c):

```
Go calls String.Length/1, and `String` has no operation of that name
`String` is a reserved qualifier, so this cannot be fixed with a `using` line — the operations under it are the compiler's own.
```

**Narrow means** the names a *resolved* ticket already commits to — **ten**: the eight 96 Q6 names (`Enum String Int Process GenServer
Supervisor Logger System`), `Task` (ticket 98:45, *"`Task` is a reserved qualifier (ticket 65)"*) and `Agent` (ticket 98 Q2, *"`Agent<S>` is in"*, covered by 96 Q6). **`Binary` is left out** — ticket
93 is open and asks that very question. The 65c and 65i prototypes reserved eleven: these ten plus `Binary`, so they measure the narrow set with one extra name.
**Compiler delta.** One line in `reserved_qualifiers/0`; the refusal and the "no operation of that name" diagnostic
(`bs_check.erl:3357-3362`) already exist; extend P3–P6 of the gate.
**Evidence (65c, scratch copy, 1-line delta).**
- Exit status unchanged on all 29 example modules; **generated code (`beam_lib:md5` of every beam) identical on the 22 that compile.**
  **This is close to a tautology and should be read as one:** the other 7 fail under *both* compilers (5 on a harness error — `--src-root`
  equals the module directory, the same wall `check-exemplar-frontier.sh` records — and 2 on syntax errors), and the 22 that compile
  never name a roster word as a whole module name (0), as a last segment (0), or as a qualifier (the only use anywhere is
  `Binary.Append` ×2, in `25b-websocket-handler/encode.bs`, which does not compile). The measurement establishes *absence of collisions
  in this corpus*, not safety for other authors.
- 0 of 173 tracked `.bs` files declare a roster word as a whole module name (65h), and no eunit inline program declares one of the ten or `Binary` as a module (65h). **The eunit suite was then run under the delta (65i): 1497 passed, 1 failed — the same single test, `body_check_tests:every_aoc_program_still_compiles_test`, fails identically on the pristine compiler; the delta adds no failure.** (65h's eunit grep covers all eleven names; the earlier version covered only the five already reserved.)
- Compile time, `bsc examples/Shop`, 40 pairs with order alternated: **pristine median 470.6 ms (IQR 455.6–495.4, stdev 63.2),
  patched 479.8 ms (IQR 462.3–531.7, stdev 49.2), difference +9.2 ms; a bare `erl` start-and-halt is 216.4 ms.** The spread is larger than the
  difference and most of the time is VM startup. **No cost is resolvable** (the difference is inside the interquartile range); the check is a `lists:member/2` over an atom list per qualified call.
**Strongest counterargument.** It burns names for operation sets that are not built, and the nouns are ordinary ones: `Task`, `Process`,
`System`, `Logger` in a language whose own exemplars are an HTTP API, a websocket handler, an event queue, a database client and an
LLM client. A name reserved for an operation set that never ships is a permanent hole. 96 Q6 already named eight of them and
David accepted that; `Task` is the one added by a ticket (98) that is resolved but whose qualifier is unbuilt.

### C — User names win (ticket option 3), prototyped three ways.

**Where this option stands.** *No ticket weighed it for qualifiers.* 67 Q6 offered (i) refuse a path segment, (ii) the reserved name
wins silently, (iii) refuse at the call site (67:315-343) — user-wins is not among them. The nearest refusal is ticket 48 Q9 option (b),
*"unqualified, user wins … exactly the kind of silent subtlety the standing constraint forbids"* (48:1073-1075), which is about
unqualified *function* names (`Get`), not about a module the author imported. So C is open, and its closest analogue was refused.

**Code (65g; the three prototypes are deltas on scratch copies, and the findings belong to them, not to the option in the abstract).**

```
                                   pristine        half          shadow         fall (per-site)
P1 module List declared            refused         compiles*     compiles*      compiles*
P2 using Shop.Coll; List.Length    "two things"    1  <- WRONG   99             99
P3 using Shop.Coll; List.Sum       "two things"    error         error          2  (falls to the standard op)
P4 no user List (control)          3               3             3              3   (code md5 identical on all four)
P5 using Shop.Coll; Term.Compare   "two things"    :lt <- WRONG  :user + warning :user + warning
P6b using List; Twice(n)+List.Sum  refused         3             3              3
P6/P7  List.Twice after `using List`, or Map.Twice from inside module Map: "no operation of that name" in every prototype

* "compiles" means the declaration is accepted. **In every prototype the user's top-level `module List` cannot then be called as `List.X`** — not from itself,
  not after `using List` (P6, P7; the same for a top-level `module Map`, where the standard `Map.Size` still works). Unqualified `Twice(n)` works (P6b).
  So the headline case of this option — the author declares `module List` and uses it — **does not work in any of the three prototypes**; only the
  namespace-tier collision (P2, P3, P5) does.
```

- **half** (checker only): type-checks against the user's signature and runs the standard operation — `1` where the user's function
  returns `99`, `:lt` where it returns `:user`. The emitter decides "reserved" from the module name alone (`bs_emit.erl:1049-1050`).
  This is a property of a *partial* delta, and shows why the delta has two halves; it is not a property of the option.
- **shadow**: the emitter also consults the `qmods` table (`bs_emit.erl:47,127`). Correct on P2, but the standard `List.Sum` becomes
  unreachable in any scope that names the word (P3) — a property of **this** prototype's "the user's module replaces the word".
- **fall**: the checker uses the claimant's function when it *declares* that name/arity and otherwise falls through to the standard
  operation, telling the emitter per site with a new `ruser` note (the F64 `pcall` mechanism). **P3 then returns the standard `2`.** It
  is 18 changed lines in `bs_check.erl` and 4 in `bs_emit.erl`. **No warning is emitted** — that needs a `bs_diag` clause and is *not
  built*, so "shadowing does not warn" holds for these prototypes only.
- **None** of the three patches `reserved_forms/1` (`bs_emit.erl:2102`): P5 under `shadow` and `fall` prints `Warning: function
  bs@Term@Compare@2/2 is unused` at compile time. The helper is not in the beam (it holds only `Go` and `bs@type_atoms`; erlc drops the unused function), so it survives
  only as that warning. None resolves a top-level user module through
  a module-tier `using` or from inside itself (P6, P7): the table the delta consults holds namespace-tier claimants only. A complete
  delta must do both.

**Prior art (65d, 65e, 65f).**
- *Types:* Erlang permits `-type map() :: …` since OTP 26, as a **warning on by default** with an opt-out (`erl_lint.erl:3345-3347`
  comment, `:547` text, `:844` the default-on switch; 65e). Gleam lets a user type be called `Result` or `List`, silently, and `Ok(1)`
  still resolves (65f). **B# itself does not do this** for `ValidationError`, `Down`, `Exit` (65a §E).
- *Modules:* a user `lists` ahead of stdlib on the path **kills the VM at boot** (65e: `Kernel pid terminated (logger)`); Elixir
  1.19.5 `defmodule Map` warns, clobbers `Map.new/0`, and crashes **its own type checker** at `lib/module/types.ex:291` and lexical
  tracker at `lib/kernel/lexical_tracker.ex:159` (65d; the dotted control `Shop.Map` runs clean). Reproduces ticket 48 Q9's measurement
  on the same Elixir version.

**Strongest counterargument.** Even built correctly (`fall`), `List.Sum(x)` stops telling a reader whose `List` it is without reading
the `using` lines — the property 67 bought by closing the qualifier set. And the half-built delta shows the failure is a silent wrong
answer, so every future qualifier path must be added to the emitter's side channel as well.

### Considered, measured, not offered — an unreachable namespace (ticket option 2)

The lexer has no rule mentioning `@`, `~` or `#` (65h), so a sigil costs one lexer rule, one production beside
`bs_parser.yrl:646-649` and a flag on `e_qcall`. The cost is the call sites, by `\b(List|Map|Term|Float)\.[A-Z][A-Za-z]*\(` (65h):
**31** calls in 12 `.bs` files, **186** in 9 eunit files, **38** in `LANGUAGE.md` (29) / `TOUR.md` (8) / `STANDARD-ENVIRONMENT.md` (1), 73 in
features, 154 in tickets. It would also reverse the spelling 96 Q2 chose. The cheaper form of the same idea — lowercase names for the
prelude alone — is ticket 48 Q9 (d), and is what the *type* prelude already does.

## Recommendation

For the gating question: **B, narrow** — reserve now the ten names resolved tickets commit to, leave `Binary` until 93 closes.
This **changes my first draft, which recommended A**, for one reason I had left out: the repo's own rule of thumb at
`LANGUAGE.md:2160-2162` is that reserving late takes a name away from a program that already used it, and F32 followed it with `Map`.
B costs one line, burns nothing David has not already named, passes the 22 compilable examples with identical code, and replaces
advice that can never work (*"add `using String`"*) with an honest diagnostic. **A is defensible** — it is what 96 Q6's word "adds" can
mean and it breaks loudly — and what swings it back is (a) a worry about `Task`/`Process`/`System` as author nouns, or (b) 93 resolving
differently so that a pre-reserved name is wrong.

For the rest of 65's scope, each is small and none is answered elsewhere: **keep `not` an identifier** (63's *absence teaches*; revisit
only if a program shows the confusion), **record that `bs@` is lexically unwritable** (65a §H), and **decide module names that differ
from an OTP module only by case** — `Queue` and `Math` are in this repo today, so either refuse the pattern (delta: a clause in
`reserved_module_name/2` over the OTP module list; 1,020 modules in this OTP install) or write down that B# targets case-sensitive
disks. I have no recommendation between those two; the failure cannot be reproduced on this Linux filesystem (cited, not run).

**Not C, as built:** it would need the emitter's side channel, the `reserved_forms/1` path, and the module-tier/self cases before it is
correct, to buy a freedom no program in the repo uses.

## Evidence ledger

| Probe | Claim tested | Control | Result | Does **not** show |
|---|---|---|---|---|
| [65a](probes/65/65a_what_is_reserved_today.sh) | What `bsc` reserves; compiler-known types/functions; `not`; `bs@`; OTP-shaped module names | 48 asserted cases incl. fresh names, `Shop.List`, `Foo`, `ValidateAs`, `Bs` | 48/48 as expected. **Asserts exit status, plus that a refusal's first line is refusal-shaped; the expected status comes from a label-pattern table inside the script** | The case-insensitive-disk failure; later qualifiers |
| [65b](probes/65/65b_growth_of_the_standard_environment.sh) | Set grows from within | refuses a shallow clone | 0→4 qualifiers, 30 rows | Future growth; counts `{{'Q','Op',N}` keys only |
| [65c](probes/65/65c_blast_radius_of_reserving_the_roster.sh) | Cost of reserving the roster now | `module List/String` before/after; author migration cases | 29/29 same status, 22/22 same code, **a near-tautology (above)**; wrong-fix diagnostic; timing within noise | Other authors' programs; the 7 non-compiling exemplars |
| [65d](probes/65/65d_elixir_defmodule_map.sh) | Elixir `defmodule Map` (1.19.5) | `Shop.Map` runs clean | 4/4 as expected. **Asserts exit status and the named error/crash-site strings** | Elixir ≥ 1.20 |
| [65e](probes/65/65e_erlang_shadowing.sh) | OTP 28 type and module shadowing | fresh type; `shop_lists` | 9/9 as expected. **Asserts `erlc`'s own exit status and the diagnostic text** | Releases that embed stdlib |
| [65f](probes/65/65f_gleam_shadowing.sh) | Gleam 1.18.1 | `Outcome`, `list`, `shop/list` | 7/7 as expected. **Asserts exit status; cases 2 and 4 also the error title; 1b runs the program and checks it prints 42 (prelude `Ok`); cases 1 and 1-control assert exit status only** | Gleam's other reserved words |
| [65g](probes/65/65g_user_names_win_prototype.sh) | User-wins, three prototype deltas | P4 no-user-List; code md5 | table above (printed, not asserted) | Warnings; `reserved_forms`; module-tier/self-qualified; a complete delta |
| [65i](probes/65/65i_eunit_under_the_roster_delta.sh) | The compiler's own eunit suite under the 11-name delta | pristine copy, same command | 1497 passed / 1 failed on both; the failing test is the same and pre-existing | The one failing test (its cause is not investigated); programs outside the suite |
| [65h](probes/65/65h_counts_and_citations.sh) | Every count, date, line number and status the brief quotes | `shallow` refusal | commands in the file | Nothing about behaviour; it runs no compiler |

## Not run, not measured, caveats

- **Elm: not run.** `elm make` needs the package registry (403). I seeded `elm/core` and `elm/json` into a private `ELM_HOME` and the
  compiler reached the registry fetch. Elm statements rest on reading the compiler clone at `1c278bf`: 11 implicit imports
  (`Elm/Compiler/Imports.hs:19-32`, used at `Parse/Module.hs:82`) and an *AMBIGUOUS IMPORT* error when a local module and a package module
  share a name (`Reporting/Error/Import.hs:84,98`).
- **Haskell, Rust, Scala rows of the ticket's table: not re-verified.** C# not surveyed. Of the rows I checked: Erlang holds with a
  nuance the table omits (types only; a default-on warning), Elixir holds as a counter-example.
- **"A fleet would hit the day-of break": not probed**, an argument only. **Whether anyone outside this repo has a module called `String`:
  unknown.**
- 65c's roster delta is a placeholder for the real change: it reserves names with no rows, so it measures the refusal and the diagnostic,
  not any operation.
- OTP 28.5 on x86_64 Linux. The compiler under test is the repo's at `c01d51f7`; scratch deltas never touched `compiler/`.
- `git fetch --unshallow origin` was run in the shared checkout to read history; it changes `.git` only.
