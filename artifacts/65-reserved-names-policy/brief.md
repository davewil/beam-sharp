# Decision brief — ticket 65 (ENG-255), reserved names: the policy

Prepared 2026-10-25 against `1429fdc`. Nothing under `wayfinder/` was edited, Linear untouched, no commit.
Toolchain: OTP 29 (ticket text says 28), Elixir 1.20.4, gleam 1.19.1, Elm 0.19.3, `bsc` built from `compiler/src` at HEAD.
Probes live in `probes/`; every claim below cites one. Two prototype compilers were built **from copies** of the
sources in the session scratchpad (patches kept in `probes/opt2-patch/`, `probes/opt3-patch/`); the repo compiler was not modified.

## 0. Read this first: the ticket has been partly answered underneath itself

The ticket body (2026-08-25) says "B# reserves no name today" and "48 decided `Map` becomes the first". At HEAD:

| ticket text | HEAD, measured |
|---|---|
| "B# reserves no name today" | **Four reserved qualifiers + one protocol name are refused as bare module names**: `List, Map, Term, Float` (`bs_check.erl:1699`) and `Enumerable` (`bs_check.erl:1426` `protocol_table`, refused through `reserved_module_name`, `:241-254`). `probes/p1_reserved_module_names.out`, `probes/p9_std_name_count.out`. |
| "`Map` costs nothing; the next one might" | `List`, `Term` (F32, 2026-09-04), `Float` (F51, 2026-09-16), `Enumerable` (F64, 2026-09-28) all landed. Corpus cost so far: **0 of 81** distinct single-segment `module X` names in the shipped `.bs` corpus collide with the 5 (`probes/p10_*`; note this excludes `_build`, a first run that included it is kept as `.v1-includes-_build.out` and was wrong). |
| "decide whether the environment is closed by intent, first" | **Already answered twice.** Ticket 67 (resolved 2026-09-03): "closed **by construction** — nothing a user writes can accrete into it, which answers the first question ticket 65 put to itself" (67:424-426; also 67:270-271). Ticket 96 round 3 (David, 2026-09-25, `96-standard-environment-breadth.md:205-208`): "Every qualifier the standard environment adds is reserved on ticket 67 Q6's terms... This answers ticket 65's first question by rule: what the standard environment qualifies is reserved, and nothing else." Decisions entry of 96 repeats it (`:252-253`). |
| "policy: 1 / 2 / 3" | **Option 1 is the decided and built behaviour**, bare name only (a dotted path holding it stays legal, 67 Q6). Built by F32 (`compiler/features/F32-reserved-qualifiers.md`), gate `compiler/bin/check-reserved-qualifiers.sh`. |

So the live question is not "which of three" from a blank page. It is: **does David ratify 96 Q6 and close 65, or overturn it?**
And 65 has quietly become the parking place for three neighbouring questions other tickets handed it (section 5), which no round has answered.

## 1. Sub-decisions, in dependency order

- **G (gating). May a user declaration ever beat a standard name?** If *no*, options 1 and 2 remain and 1 is built; if *yes*, option 3.
  The ticket's own gate ("is the environment closed by intent?") is answered: closed to users (67), but **not static** — see section 2.
- **S1.** Given *no*: reserve the bare name (1) or move the standard environment behind an unreachable prefix (2).
- **S2 (never asked in the ticket; handed to it by 87, F54, F55, F27, 63, 98).** Three adjacent surfaces: module names colliding with OTP modules
  (case-insensitively), the `bs@` export prefix, and `not` as a legal identifier.

G is asked alone below (section 6). S1 follows from its answer; S2 is a separate, smaller round.

## 2. What "closed" measures out to (the gating question's facts)

**Closed against users, by syntax, today.** Builtin type names are lowercase tokens, user types and modules PascalCase (`bs_lexer.xrl:3-6`).
`probes/p2_type_namespace.out`: `type int = string`, `record list {..}`, `type atom = int` are all `syntax error`. So Erlang's "user type shadows built-in" problem
(OTP 26 "starting from OTP 26, redefining built-in types is allowed", `erl_lint.erl:3951-3955` in stdlib-8.1.1) **cannot arise in B#**: the types
column is already option 2 by lexical case. And a user `record Map`/`record List`/`record Enumerable`/`type Map` is accepted (types and qualifiers are different positions); control `record Money` accepted.
Module atoms: `module lists` is a syntax error (`p1_reserved_module_names.out`, last line), so a B# module atom can never equal an OTP atom exactly.

**Not static against the compiler's authors.** The reserved set grew 1 -> 5 in five weeks (dates in the table above). Ticket 96's roster
(`96:190-194` and the roster table "What a yes makes cheap") names nine more qualifiers: `Enum, String, Int, Process, GenServer, Supervisor, Logger, System` (96:190) plus `Binary` (93), `Task`, `Agent` (98). Today `module String`, `module Binary`, `module Option`,
`module Json`, `module Set`, `module Int` all compile clean (`p1_reserved_module_names.out`). Each future qualifier is a **source-breaking change for any user who has a bare-named module of that name**.
That is the real cost axis for the policy, and it is a one-time-per-name cost, borne by the user, decided in this ticket's name by rule.

Size of the list a reserved-name table holds: 4 qualifiers carrying **30 rows** (`List` 16, `Map` 12, `Term` 1, `Float` 1; `p9_std_name_count.out`) + 1 protocol = 5 refused module names now; ~14 with the 96 roster.

## 3. Facts that contradict or sharpen the ticket's evidence (probes, not memory)

1. **Elixir `defmodule Map` — claim holds on 1.20.4, but conditionally** (`p4_elixir_defmodule_map.out`, `p4b_elixir_repeat.out`).
   Warning (`redefining module Map (current version loaded from .../Elixir.Map.beam)`), the stdlib module is replaced (`Map.new/1` then `UndefinedFunctionError`),
   and when a script finishes, **Elixir's own checker crashes**: `function Map.update!/3 is undefined or private ... lib/module/types.ex:303: Module.Types.local_handler/5` (6/6 runs of script D;
   the ticket's line was `types.ex:291` on 1.19.5). It did **not** reproduce for the ticket's literal repro (script A: my own `Map.new` call kills the script first, 0/6)
   nor for `elixirc` of a file (B, 0 crash, exit 0). Control C (`MyMap`): clean. Elixir sources are not installed (only `ebin`), so the line is from the runtime trace, not the source.
2. **Erlang** (`p5_erlang_type_shadow.out`): `-type list()`, `-type atom()`, `-type integer()` compile, exit 0, with `Warning: local redefinition of built-in type` by default;
   `-compile({nowarn_redefined_builtin_type, ...})` silences it (`erl_lint.erl:3969-3983`). The ticket's "OTP 26 permitted" is right and understated: the default is *warn*, not silent.
   A probe line with the wrong flag (`nowarn_shadow_vars`) still warned, which is the control showing the right flag is the one doing the work.
3. **BEAM-level truth** (`p6_beam_flat_namespace.out`, `p6b_..`): module atoms are one global flat namespace. A user `lists.beam` on the path makes **the VM die at boot**
   (`Runtime terminating during boot ({undef,[{lists,usort,...`), in normal and embedded mode alike. A PascalCase atom `'Map'` beside `maps` collides with nothing (p6b: `Map:size -> user_map_size`, `maps:size -> 1`, `lists:map -> [1]`).
4. **Consequence for B#: the Elixir catastrophe is structurally unavailable.** Standard operations lower to *lowercase OTP* calls (`bs_emit.erl:1049-1062`, `standard_target`: `lists:sum`, `maps:put`...); no `List.beam`/`Map.beam` ships.
   P3 (option-3 prototype) shows a user `Map.beam` next to a dependency whose own `Map.Size` stays `erlang:map_size` (`Lib.beam imports [erlang]`). So the ticket's headline justification
   for protection — "Elixir clobbers and crashes" — does not carry over. What reservation actually buys in B# is **compile-time call-site ambiguity** (P13), not runtime safety.
5. **Gleam 1.19.1 reserves at the BEAM-atom level, not the stdlib-name level** (`p7_gleam.out`, `p7b_gleam_collision_list.out`): local `erlang.gleam`, `lists.gleam`, `maps.gleam`, `kernel`, `code`, `io`, `string`, `file`, `gen_server`...
   -> `error: Erlang module name collision ... would overwrite the Erlang one`; `gleam.gleam` -> `Reserved module name`. Local `gleam/list.gleam` and `list.gleam` compile. A user `type Result(a,b)` / `type List(a)` / `type Bool { True False Maybe }` **compile, no refusal**
   (prelude types are shadowable; the one `Warning: local redefinition of built-in type: bool()` there is **erlc's own OTP 26 warning surfacing through Gleam's generated `-type bool()`**, not a Gleam diagnostic). `gleam_stdlib` unavailable (hex.pm blocked), so "local module named like `gleam/list` beside the real dependency" is **not tested**.
6. **Elm**: `source unavailable`. `elm make` could not fetch `elm/core` (`package.elm-lang.org` 403, `p8_elm.out`; first attempt `.v1-missing-json.out` was my elm.json missing `elm/json`). Only offline evidence: the 0.19.3 binary carries an `AMBIGUOUS IMPORT` error with the hint
   "Try changing the name of the locally defined module to clear up the ambiguity?" (`p8b_elm_binary_strings.out`) — i.e. Elm refuses at the **import**, not the declaration, but I did not trigger it, so treat as unverified.

## 4. The options, each as B# code and compiler delta

Common fixture: a user module named like a standard qualifier, a dependency that means the *standard* one, an app that uses both.

### Option 1 — reserve per module (HEAD; decided by 96 Q6; built by F32)

```csharp
// src/List/List.bs
module List                                      // error, today (probes/p1): 
public int Sum(list<int> xs)                     //   List is a reserved qualifier, so no module may be called it
Sum(xs) -> 1000                                  //   `List.` names operations the compiler knows and inlines at the site;
                                                 //   no beam ships for it ... `Shop.List` is still legal
// src/Shop/List/List.bs
module Shop.List                                 // legal (p1 last control): the whole name is reserved, not a path segment
// src/R/R.bs
using Shop
Go(xs) -> List.Sum(xs)                           // error (p13, HEAD): Go calls List.Sum, and `List` means two things here
                                                 //   `List` is a reserved qualifier — the compiler's own operations —
                                                 //   write the module's full path to reach it ...
Go2(xs) -> Shop.List.Sum(xs)                     // the escape: the full path
```

Lowering: none for the user module. `List.Sum(xs)` -> `lists:sum(Xs)` (`bs_emit.erl:1049-1062`).

Compiler work, **all of it already exists**; cost of *one more name* is measured here:

| site | what | lines |
|---|---|---|
| `bs_check.erl:1699` `reserved_qualifiers()` | add the atom (protocols are added via `protocol_table`, `:1426`) | 1 |
| `bs_check.erl:241-254` `reserved_module_name/2`, called `:339` before `module_matches_path/3` | refusal, shared by every name | 0 per name (15 total) |
| `bs_diag.erl:675-677` + `:1385-1400` | `reserved_module_name` diagnostic and message | 0 per name (~20 total) |
| `bs_check.erl:3238-3260`, `:3283-3295` `reserved_call` | the call-site collision (67 Q6 iii) | 0 per name (~12 total) |
| rows | `standard_table()` / `declared_rows()` (`:1706-1740`), one line per operation | n per name |
| tests + gate | `reserved_qualifier_tests.erl:229-245` style, one `declaring_a_module_called_X_is_refused_test` (~6 lines) per name; the gate's P3-P6 extend by rule | ~6-10 per name |

So option 1's marginal cost per name is about one line of compiler and one test; the diagnostic text is generic. (The message's "no beam ships for it and no `using` is ever written" is correct for qualifiers and is separately specialised for protocols at `:1385-1392`; a future non-inlined entry like `GenServer`, which `96` lowers to `gen_server:call`, fits the existing wording.)

Evidence for: `check-reserved-qualifiers.sh` P3-P6 (bare refused, dotted legal, collision named, non-reserved short qualifier unaffected), measured by me in `p1`, `p13`.

**Strongest counterargument, stated fairly.** The list grows forever and **every addition is a breaking change to someone's source** — and the damage it prevents is not the damage the ticket cites.
Section 3 item 4: in B# a user `module Map` cannot clobber anything at runtime, so the refusal is paying a permanent compatibility tax to avoid a *compile-time ambiguity* that a loud
call-site rule (P13) already catches on the `using Shop` path. Five weeks bought five names; the 96 roster buys nine more, and 5 of them (`String, Int, Binary, Json, Logger`) are also OTP module names, i.e. words real programs will want.
If the project stays at one author, the tax is zero; once there are external users, it is levied each release.

### Option 2 — a namespace the user's syntax cannot reach

The spelling B# lacks exists in miniature: the *types* column already is one (lowercase tokens, `p2`). For qualifiers the program would be:

```csharp
module List                                      // legal now: nothing is burned but the prefix
public int Sum(list<int> xs)
Sum(xs) -> 1000

module App
using List
Mine(xs)   -> List.Sum(xs)                       // the user's        -> 1000
Theirs(xs) -> Std.List.Sum(xs)                   // the standard row  -> lists:sum/1 -> 6
module Std                                       // error: the one burned name (and `Std.*`)
module Old ... List.Sum(xs) with no `using`      // error: List is called but never imported — every existing program
```

Measured on the prototype (`p11_unreachable_namespace.out`, patch `probes/opt2-patch/`: 16 lines added, 8 removed across `bs_check.erl`, `bs_emit.erl`):
App.Mine = 1000, App.Theirs = 6, a dependency that wrote `Std.List.Sum` = 6, `module Std` refused; under HEAD the same `module List` is refused. Lowering is unchanged (still `lists:sum`).

Compiler work: a `std_name/1` mapping `Std.X` -> `X` in `type_of(e_qcall)` (`bs_check.erl:3236-3250`) and `expr(e_qcall)` (`bs_emit.erl:1049`), `reserved_forms` at `:2099`, `reserved_module_name` refusing `Std`/`Std.*`;
a rename of the lookup, **not** of the 30 rows. Prototype shortcomings, honestly: the `Std` refusal reuses the old message text, which is now wrong ("`Shop.Std` is still legal" — the prototype refuses `Std.*`); and I did not make `using Std` short-qualify.

Migration cost (`p12_migration_sites.out`): **50 call sites in 20 `.bs` files, 187 in 9 test files, 30 in LANGUAGE.md/CONTEXT.md, 181 in wayfinder tickets** for `List./Map./Term./Float.` alone. Every program the audition packet has seen changes spelling.

**Strongest counterargument.** It does not remove the burned name, it moves it to one (`Std`) and leaves every future qualifier free: no breaking change when `String` arrives, `Shop.String` and `String` both legal, the standard operation always reachable. That is the only option under which the policy needs *no further decision per name*, and it matches the types column that B# already got right by lexical case. Its cost is paid once, now, by a corpus of 20 `.bs` files — the cheapest the migration will ever be — against a cost option 1 pays on every roster addition for the life of the language. The fair objection to my own framing: "`Std.List.Sum`" is longer than every pipeline in 96's roster (`os |> List.SortBy(...) |> List.Take(3)`), so unless short `List.` is *also* accepted when unambiguous, the language gets uglier daily, and "also accepted when unambiguous" is option 3's silent shadow again.

### Option 3 — user names win

```csharp
module Map                                       // legal under 3
public int Size(int n)
Size(n) -> n + 1000

module Lib                                       // a TRANSITIVE dependency; no `using Map`
public int Count(map<atom, int> m)
Count(m) -> Map.Size(m)                          // the standard row: erlang:map_size

module App
using Map                                        // brings the user's module
using Lib
Go(n)  -> Map.Size(n)                            // 1005: the user wins here
Via(m) -> Count(m)                               // 1: the dependency is untouched
module AppB
using Map
Go(n) -> Map.Size(Map.FromList([(:a, n)]))       // error: Go calls Map.FromList/1, which nothing declares
```

Measured on the prototype (`p3_user_wins_tree.out`; patch `probes/opt3-patch/`: 12 lines added, 3 removed): HEAD refuses `module Map` at the declaration (all three cases);
prototype: `App.Go 5 -> 1005`, `App.Via #{a=>1} -> 1` (the dependency resolved to the standard row; `Lib.beam imports [erlang]`, no `Map`), `AppB.Go -> error ... which nothing declares`.
Ticket's worry "what a user `module Map` shadowing does to a **transitive dependency that calls `Map.Get`**": **nothing** — resolution is scoped by `using` (a qualified call needs the module imported, `bs_check.erl:4558-4570`, `require_imported`), and no beam named `maps`/`lists` is ever produced. The ticket's Elixir-shaped fear does not exist in this language.

What it *does* do:

1. **Silent flip.** `p13_silent_shadow.out`: `using Shop` where `Shop.List.Sum(xs)` has the standard row's arity. HEAD: the 7-line `List means two things here` diagnostic. Prototype: `1000`, no output, where the standard `List.Sum([1,2,3])` is `6`. Option 3 deletes 67 Q6(iii)'s loud check (David's "nothing is silent (Elixir's clobber is the thing refused)", 67:458) in exactly the shape it was written for.
2. **The standard operation becomes unreachable inside the shadowing module** (AppB): there is no spelling for it, so a fix needs option 2's prefix anyway.
3. It leaves compiler-known entries the *user's* definitions can silently take over: `F32`'s whole premise ("`List` is an operation set the compiler knows, not a module it ships") is inverted per module.

Compiler work: the checker's reserved test must consult the import tables first (`bs_check.erl:3238-3250`, a `user_wins/3` of 8 lines) and the emitter must learn the same decision (`bs_emit.erl:1049-1062`) — **in the prototype I passed it through the process dictionary keyed on `{Mod, Line}` because the emitter does not receive `imports`; a real build threads it through the AST or ctx, which touches `bs_emit`'s context record and every `reserved_forms` caller** (so the 12 lines understate the real delta). The declaration refusal at `:241-254` is deleted. Prototype caveat: line-keyed state would misfire across modules compiled in one run on equal lines; each probe compiled one entry module, and Lib/Map have different lines.

**Strongest counterargument against option 3 is item 1 (silent flip); the strongest argument *for* it is**: Scala designed this in (the research table, "lowest precedence... always shadowed by user code"), it makes every roster addition non-breaking (`module String` written today keeps working when `String` becomes a qualifier because user wins), and P3 shows the sky-is-falling Elixir case does not exist here. If section 3 item 4 is the real situation, option 3 is the policy with the smallest long-term cost. Its price is that `List.Sum` can mean two things in one codebase depending on a `using` line far from the call, and the language is in the very phase (clean-room handoff, a stranger developing blind) where "what does this name mean" must be answerable from the call site alone.

## 5. What 65 has become: S2, the part no round has answered

Other tickets handed 65 three questions the ticket body does not mention. None is covered by 96 Q6 (that covers *qualifier* names).

1. **Module names that collide with OTP modules, case-insensitively.** F54:166-172 recorded a real incident: a test module `Peer`'s `Peer.beam` made a spawned VM die at boot (`beam_load.c: module name in object code is 'Peer'`) on a case-insensitive disk, "exactly as the stray `Json.beam` did in ENG-391". Measured now (`p15_otp_case_collisions.out`): OTP 29 ships **1321** modules in `lib/*/ebin`; of B#'s 81 corpus module names, **`Math` (shipped example `compiler/examples/Math/math.bs`) and `Queue`** lowercase to OTP modules (`math`, `queue`). Of the roster, `String, Int, Supervisor, Logger, Binary` plus `Json, Peer` do too.
   Gleam refuses exactly this at BEAM-atom level (section 3 item 5; 10 names tried, 9 refused). This was measured case-**sensitively** on Linux; I cannot test a case-insensitive FS here, so the failure is from F54's record, not reproduced.
2. **`bs@` as a reserved export prefix** (87:168, F55:173): "which the PascalCase rule already guarantees" — user function names are PascalCase (lexer), `bs@` is lowercase with `@`, so it is unspellable; probably dissolves without a decision.
3. **`not` as a legal identifier** (63:406, F27:44, LANGUAGE.md:334): `F(not) when not > 100` compiles today. This is the *unqualified, lowercase* column, a different policy surface from qualifiers.

## 6. The question to put to David, alone

The gating question, as B# code, in 96 Q6's own terms:

```csharp
// App.bs   (src/List/List.bs defines module List with its own Sum;  src/Lib/Lib.bs calls the standard List.Sum)
module List ...                  // today: refused, `List` is a reserved qualifier
using List
Go(xs) -> List.Sum(xs)           // Option 1: n/a (the module cannot exist)   Option 3: the user's, silently   Option 2: the user's; the standard one is Std.List.Sum(xs)
```

**"May a user's `module List` exist in a program that also uses the standard `List.Sum`?"** — David has said no once (96 Q6, 2026-09-25). The new fact he did not have when he said it: **in B# this cannot crash anything** (section 3 item 4), so the refusal is a pure source-compatibility policy, and the cost is the roster. If still no, S1 is a separate, later question between the built behaviour and option 2's prefix.

## 7. Recommendation

1. **Ratify option 1 (as built) and close 65's qualifier policy by pointing at 96 Q6 and 67.** It is decided, built, gated, and its marginal cost per name is one line plus one test. The two alternatives each cost more *now* with an uncertain payoff: option 2 rewrites ~490 sites to defer a breakage nobody has met (0 of 81 corpus modules hit the 5 names); option 3 deletes a loud diagnostic David chose (P13) and leaves the standard operation unreachable in the shadowing module (AppB).
2. **Record the corrected premise** in the resolving entry: the Elixir crash reproduces (1.20.4, `types.ex:303`) but **cannot occur in B#**, because B# ships no `List.beam` and lowers to lowercase OTP atoms (P3: dependency unchanged). Reservation is justified by call-site ambiguity and by keeping a path to a single meaning of `List.` per program, not by runtime safety.
3. **Keep one cheap guard against the roster's real cost:** when a new qualifier lands, the compiler change and the corpus scan (`probes/p10_corpus_module_names.sh`) ship together. That is a sentence in CLAUDE.md, not a gate (house rule: one occurrence gets a sentence).
4. **Split S2 out.** The OTP case-insensitive collision (`Math`, `Queue` are in the corpus today) is the only item with a measured past incident; it needs its own question, Gleam's list-of-OTP-modules refusal being the precedent. `bs@` likely dissolves; `not` should stay with 63/F27 and be answered when the lexer next gains a keyword.

Reasons I would give up recommendation 1: if David expects external users before the 96 roster lands, option 2's one-time migration is cheapest *now* — and that is a product call, not a measurement.

## 8. Ticket claims that no longer hold

- "B# reserves no name today" — false (5 names refused; 4 qualifiers + `Enumerable`).
- "Deciding whether it is closed is deciding this ticket" — decided by 67 (closed to users, by construction) and 96 Q6 (reserved by rule).
- "Erlang: OTP 26 permitted a user type to shadow" — true but it warns by default (`erl_lint.erl:3951-3983`).
- "Elixir ... crashes Elixir's own type checker, which was calling `Map.update!/3`" — true on 1.20.4 under conditions (script run to completion; not for `elixirc` of a file or the ticket's literal script); line is `types.ex:303` now.
- "OTP 28" — runs here on OTP 29; nothing measured depended on the difference.

## 9. Not measured

Elm's behaviour (package server blocked); Gleam local module vs a real `gleam_stdlib` `gleam/list` (hex blocked); case-insensitive filesystem collision (Linux only; relied on F54's record); Elixir/OTP *sources* (Elixir `lib/` absent, only erl_lint and code_server from OTP were readable); git history of `reserved_qualifiers/0` (repo history is 50 commits, `p14` shows only the squash commit `d720c46`, so the dates above come from the F-files, not blame).

## 10. Probe index

All under `probes/`. Run with `probes/<file>`; toolchain PATH is set inside each script. Scratch trees go to the session scratchpad `65/`.

| file | re-run | supports |
|---|---|---|
| `p1_reserved_module_names.sh` / `.out` | `bash p1_reserved_module_names.sh` | `Map List Term Float` refused; `String Binary Option Result Json Set Int Bool Atom Tuple Foo Shop.List` accepted; `module lists` syntax error. `.v1-wrong-layout.out`: my first layout put the root at the module dir (refused for the path, not the name) |
| `p2_type_namespace.sh` / `.out` | same | lowercase builtins unreachable by user types (syntax error); `record Map/List/Enumerable`, `type Map` accepted. `.v1-bad-record-syntax.out`: wrong record syntax, control failed, fixed |
| `p3_user_wins_tree.sh` / `.out` | needs `bsc-opt3` (see below) | option 3: user wins in importing module (1005), dependency unchanged (1), standard `Map.FromList` unreachable. `.v1.sh/.v1-...out`: first version put FromList in App and hid the Go result |
| `p4_elixir_defmodule_map.sh` / `.out`; `p4b_elixir_repeat.sh` / `.out` | same | Elixir 1.20.4 clobber and checker crash (script D 6/6; script A 0/6; elixirc 0) |
| `p5_erlang_type_shadow.sh` / `.out` | same | OTP 29 user type shadows built-in: compiles, warns; nowarn option silences |
| `p6_beam_flat_namespace.sh` / `.out`; `p6b_beam_pascal_atom_control.sh` / `.out` | same | user `lists.beam` kills VM boot; PascalCase `'Map'` coexists with `maps` |
| `p7_gleam.sh` / `.out`; `p7b_gleam_collision_list.sh` / `.out` | same (p7 first) | gleam: types shadowable, `erlang/lists/maps/...` module names refused, `gleam` reserved |
| `p8_elm.sh` / `.out`, `.v1-missing-json.out`, `p8b_elm_binary_strings.out` | same | Elm could not run (network); offline strings only |
| `p9_std_name_count.sh` + `.escript` / `.out` | same | 4 qualifiers, 30 rows, `Enumerable` protocol |
| `p10_corpus_module_names.sh` / `.out`, `p10_bs_mods.txt`, `.v1-includes-_build.out` | same | 81 distinct single-segment corpus modules, none colliding with the reserved five; `_build` pollution in v1 |
| `p11_unreachable_namespace.sh` / `.out` | needs `bsc-opt2` | option 2 prototype: `Std.List.Sum` 6, user `List` 1000, `module Std` refused, old programs break |
| `p12_migration_sites.sh` / `.out` | same | 50 / 187 / 30 / 181 call sites |
| `p13_silent_shadow.sh` / `.out` | needs `bsc-opt3` | HEAD names both meanings; option 3 silently returns 1000 vs 6 |
| `p14_reserved_set_growth.out` | n/a | git history squashed; not usable |
| `p15_otp_case_collisions.sh` / `.out` | same | 1321 OTP modules; `Math`, `Queue` in corpus lowercase to OTP modules; roster collisions |
| `opt2-patch/*.diff`, `opt3-patch/*.diff` | `patch` against `compiler/src/bs_check.erl`, `bs_emit.erl` into a copy | the prototype compilers; built into `$S/bsc-opt2`, `$S/bsc-opt3` (`$S` = the session scratchpad) |

## Errata from independent verification (verification.md)

The verifier re-ran p1–p13 and p15 on a fresh copy of HEAD and reproduced them; p14 and p8b have no script and could not be re-run. Corrections to the text above:

- The "nine more qualifiers" list names **eleven**, so "~14 with roster" should read about 16. `Json` is not in the roster.
- "~490 call sites" is **448** by p12, and that is an upper bound (the regex also matches prose and dotted paths).
- `reserved_forms` at `:2099` is in `bs_emit.erl`, not `bs_check.erl`. "Lowers to lowercase OTP calls" omits the `generated` rows; the conclusion is unaffected.
- "One line of compiler plus one test per name" has one probe behind it: adding `'String'` to the list refuses `module String` with the generic message. The line totals beyond that are estimates.
- Option 3's "silent flip" (p13) is a property of that prototype, whose `user_wins` skips `reserved_call`, the only place the Q6(iii) error lives. A variant that keeps the error was not built, so the flip is not shown for option 3 in general.
- p10's "0 of 81 collide" is true by construction, because names HEAD refuses cannot appear in a compiling corpus.
- The Gleam "erlc warning surfacing" attribution is inferred from message format.
- Ticket 65 is still `Status: open`, and 96 Q6 never compared options 2 and 3, so "already decided" means option 1 is built and was ratified in 96 round 3, not that 65 was closed.
