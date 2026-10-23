# Decision brief — ticket 65: reserved names, the policy

**Ticket** [65](../wayfinder/issues/65-reserved-names-policy.md) · **Linear** [ENG-255](https://linear.app/davewil/issue/ENG-255) · **Brief date** 2026-10-23
**Status: DECISION OPEN — for David's review; nothing resolved.** No ticket, feature, glossary or Linear state was changed.

Toolchain for every number below: Erlang/OTP 28.5 (erts 16.4, built from `otp_src_28.5`), Elixir 1.19.5, Gleam 1.18.1,
Elm 0.19.3 (installed, but see "Not run"), `bsc` built from this repo's `compiler/` at the branch head. Probes are in
[`probes/65/`](probes/65/); every one prints its own evidence and has a captured `65x_output.txt` beside it.

## The answer first

**Ticket 65 describes a repo that no longer exists, and most of what it asks has been answered.**

- It says *"B# reserves no name today."* The compiler reserves **`List`, `Map`, `Term`, `Float`** as whole module
  names, plus the protocol **`Enumerable`**, and carries **30 operation rows** under them
  (`bs_check.erl:1701`, probe **65a**, **65b**).
- It asks whether the standard environment is *closed by intent*. [Ticket 67](../wayfinder/issues/67-stdlib-shape-as-a-principle.md)
  answered that on 2026-09-03 (*"closed by construction — which answers 65's first question"*), and
  [ticket 96](../wayfinder/issues/96-standard-environment-breadth.md) Q6 answered the policy on 2026-09-25:
  *"what the standard environment qualifies is reserved, and nothing else"*, on 67 Q6's terms (whole name only;
  `Shop.List` stays legal). [F32](../compiler/features/F32-reserved-qualifiers.md) built it.
- Ticket 65's three options map onto what is built: **option 1 (reserve per module) is the shipped rule; option 3 (user names
  win) was weighed and refused at 67 Q6; option 2 (an unreachable namespace) is measured below and costs the most.**

**What the ticket's framing hides is one real, still-open question: *when* a name becomes reserved.** 96 plans eleven more
qualifiers (`Enum String Int Binary Process GenServer Supervisor Logger System Task Agent`). None is reserved today, so a
program that is valid today stops compiling on the day each one lands. 67 Q6 accepted exactly that cost for `List`. The
question is whether David still accepts it for eleven names, now that a clean-room fleet will be writing against the compiler.

**Recommendation: Option A — keep 96 Q6 as written (reserve on landing), and close 65 as answered by 67 Q1/Q6 and 96 Q6.**
Pre-reserving buys a stable list at the price of burning names for designs that are not built, one of which (`Binary`,
[ticket 93](../wayfinder/issues/93-binary-operations-under-a-reserved-qualifier.md)) is not even decided.

## The gating question — alone

> **Is the reserved list allowed to grow after the language is handed off?**

A program an author can write today, and what the compiler does with it on the day `String` lands
(probe **65c**, scratch compiler with `String` added to `reserved_qualifiers/0`):

```csharp
module Shop.Text.String                      // legal today: the path is not the reserved word
public int Length(int s)  ...

module A
using Shop.Text
Go(n) -> String.Length(n)                    // today: calls Shop.Text.String.Length   -> 98
                                             // the day String lands: refused —
                                             //   "Go calls String.Length, and `String` means two things here …
                                             //    Shop.Text.String.Length"
```

Same author, two more spellings that survive the day unchanged (probe 65c, cases B and C): `using Shop.Text.String` then
`Shop.Text.String.Length(n)`, and the module-tier `using Shop.Text.String` then bare `Length(n)` both print `98` before and after.
A module *declared* `module String` (whole name) is the one shape with no survivor: refused at the declaration, rename only.

- **Yes, it may grow** → the rule is A. The break is loud, never silent, and the fix is local.
- **No, the list is frozen at handoff** → the planned names must be reserved before it, which is B.

Everything else in this brief follows from that answer, and the third option (C) is the ticket's own, kept so it is on the page.

## Sub-decisions, in dependency order

| # | Sub-decision | Gates / follows | Status |
|---|---|---|---|
| 1 | May the reserved list grow after handoff? | **gating** | open — the question above |
| 2 | If frozen: which names, and does an undecided design (`Binary`, 93) get one? | follows 1 | only if 1 = no |
| 3 | Does the reservation reach types / records / functions named like a qualifier? | independent | **measured: not needed** (65a §B) |
| 4 | Do user names win a collision (ticket option 3)? | independent | **measured: refused at 67 Q6; costs below** |
| 5 | An unreachable namespace (ticket option 2) | independent | **measured: 246 call sites; not offered** |
| 6 | The lowercase builtin names are refused as a bare `syntax error` | independent, small | a diagnostic, belongs in a feature (below) |

## What is reserved today (probe 65a — real programs through `bsc`)

```
module List / Map / Term / Float   rc=1  "`List` is a reserved qualifier, so no module may be called it"
module Enumerable                  rc=1  "`Enumerable` is a protocol, so no module may be called it"
module String Enum Int Process GenServer Supervisor Logger   rc=0   (all free today — controls)
module Shop.List, module List.Shop rc=0   (67 Q6: only the whole name is burned)
type List = int / type Map = int / record Map {…} / public int List(int n) / public int Map(int n)   rc=0
```

The last line is sub-decision 3. **A type, record or function named `Map` or `List` coexists with the qualifier** and neither
captures the other: a body holding `Pick(Map m)` and `Map.Size(...)` returns `2`; `List(n) + List.Length([n, n])` returns `103`
(65a §B2). The qualifier position (`Name.Op(`) is syntactic, so the only collision surface is a **module name** — which is what is
already refused. Widening the reservation to declarations would burn names to prevent a collision the grammar already rules out.

**Lowercase builtins are a second reserved class, and it is lexical.** `type option = int`, `record list {…}`,
`public int map(…)` and `module list` are each refused (65a §D) — with the bare `syntax error before: option`, not a reserved-name
message (`bs_lexer.xrl:1-9`: *"Builtin type names are lowercase; user types and functions are PascalCase"*). That is the only
"namespace the user's syntax cannot reach" B# has. The message is the one defect I found there (sub-decision 6).

## The standard environment is closed to the outside and grows from within (probe 65b)

Read from the 956-commit history of `bs_check.erl` (the clone had been shallow; `git fetch --unshallow` was needed and the probe
refuses to run on a shallow clone, because a 50-commit curve would be flat for the wrong reason):

```
2026-08-13  none                       0 rows
2026-09-04  List Map Term              4          F32 founds the set
2026-09-12  List Map Term              7
2026-09-16  List Map Term Float        8          the one qualifier added after founding
2026-09-25  List Map Term Float       10          ticket 96
2026-10-21  List Map Term Float       30          F75: 20 rows in one day
```

Qualifiers: **0 → 3 (2026-09-04) → 4 (09-16), flat for the 37 days since.** Rows: 0 → 30. Plus `Enumerable` (protocol table, 2026-09-28).
So the set is *closed to outside contribution* (nothing a user ships ever joins it — 67's closedness) but **not frozen**:
96 queues eleven more on the compiler's own schedule. That is the ticket's own caveat realised — *"nothing new ever arrives to
collide"* holds for third parties, not for the compiler's roadmap. Hence the gating question.

## Options

### A — Reserve on landing (the shipped rule, 96 Q6). Close 65 as answered.

**Code.** The program in the gating question. Valid today; refused on the day, with a diagnostic that prints the full path as
the fix. Nothing is built now.

**Compiler delta.** None today. Each qualifier that lands adds one atom to `reserved_qualifiers/0` (`bs_check.erl:1701`) and
its rows to `standard_table/0`/`declared_rows/0`, and extends P3–P6 of `compiler/bin/check-reserved-qualifiers.sh` (96 Q6).

**Evidence.**
- Precedent: 67 Q6 chose this break for `List` and named the cost — *"`Totals.bs` and `LANGUAGE.md:139` then go red on the day, and the
  fix is theirs to make"*. F32 records the corpus module it had to rename.
- Loud, never silent: 65c cases A/B/C — the only program that changes meaning *changes into an error*.
- Neighbours do the same: Gleam reserves exactly one module name, `gleam` (`compiler-core/src/analyse.rs:1769-1772`,
  `type_/prelude.rs:31-33`), and refuses a user `gleam/list` as a duplicate rather than choosing (probe **65f** case 4). Elm
  refuses the ambiguity at the import (`Reporting/Error/Import.hs:84-98`, *not run*).

**Strongest counterargument.** Until each name lands, the compiler gives a *wrong fix*. Today, `String.Length(n)` with no user
`String` prints *"String is called but never imported — add `using String`"* (65c, last section) — advice that can never work once
`String` is reserved. And for the clean-room handoff the oracle's reserved list *changes* underneath a fleet that was told
what was reserved: it develops blind against a list that is longer next month.

### B — Pre-reserve the planned roster now.

**Code.** The same program; `module Shop.Text.String` itself is fine, `module String` is refused today instead of on the day.
`String.Length(n)` with no user `String` prints, from the scratch compiler:

```
Go calls String.Length/1, and `String` has no operation of that name
`String` is a reserved qualifier, so this cannot be fixed with a `using` line — the operations under it are the compiler's own.
```

**Compiler delta.** One line: `reserved_qualifiers/0` gains eleven atoms (`bs_check.erl:1701`). The refusal, the "no operation of
that name" diagnostic (`bs_check.erl:3357-3362`, `unknown_reserved_operation`) and the namespace-collision error already exist and
fire unchanged. Extend P3–P6 of the gate.

**Evidence (probe 65c, scratch copy, 1-line delta).**
- Breakage in this repo: **0 of 29 example modules** differ (22 compile under both; the other 7 are unbuilt exemplars that fail
  under both, so they carry no signal). **0 of 169 `.bs` files** declare a roster name as a whole module; the nearest is
  `compiler/examples/Stream/stream.bs:22 module Stream`, which is not on the roster. Of the roster names, eunit sources declare none; the
  only reserved-name modules they declare are the already-reserved ones (`api_tests.erl:278`, `float_tests.erl:256`,
  `implements_tests.erl:330`, `reserved_qualifier_tests.erl:236-250`).
- Compile time, `bsc examples/Shop`, 40 interleaved runs: **517.7 ms median (stdev 63) with 4 names vs 506.2 ms (stdev 53) with 15.**
  No difference is resolvable; the check is a `lists:member/2` over an atom list at each qualified call.
- Does not touch generated code: the emitter's decision is by name only (`bs_emit.erl:1050`), so nothing changes for an unshadowed
  program.

**Strongest counterargument.** It burns eleven names for operation sets that are **not built**, and some are not decided:
`Binary` is [ticket 93](../wayfinder/issues/93-binary-operations-under-a-reserved-qualifier.md), still open; `Task`,
`Agent`, `Process`, `Logger`, `System` are ordinary domain nouns, and the repo's own exemplars (25a–25g) are an HTTP API, a
websocket handler, an event queue, a database client, a web page, a jev server and an LLM client. A name reserved for an operation set that never ships is a **permanent hole**; and 96 Q6 said *"and
nothing else"* — B overrides that sentence, and 67 Q6 declined to burn even a path segment because *"nobody has asked for that."*
*(A narrower B reserves only roster names whose design is closed — 97, 98 and 99 are resolved, 93 is not — and leaves `Binary`
out. That is the variant to take if B wins.)*

### C — User names win (ticket option 3), built.

**Code.** A user module named `List` is allowed, and where a `using` short-qualifies it the user's module wins instead of the
refusal. Probe **65g**, scratch copy:

```
P1  module List                                  pristine: refused      user-wins: compiles
P2  using Shop.Coll; List.Length([n])            pristine: "means two things"   user-wins: 99   (the user's Length)
P3  using Shop.Coll; List.Sum([n, n])            pristine: "means two things"   user-wins: "Shop.Coll.List.Sum/1, which nothing declares"
P4  no user List anywhere (control)              3 under both; beam_lib:md5 of the compiled code IDENTICAL
```

**Compiler delta.** Not the ten lines it looks like. **Ten lines in `bs_check.erl` plus three in `bs_emit.erl`**, and the second
half is the part that matters: the emitter decides "reserved" from the module name alone (`bs_emit.erl:1049-1050`), independently
of the checker. **A checker-only user-wins type-checked `List.Length([n])` against the user's signature and then lowered it to
`lists:length` — it printed `1` where the user's function returns `99` (65g, last section).** The correct delta passes the
checker's per-module table (`qmods`, `bs_emit.erl:47`, `:127`) to the emitter's reserved test. I did not patch the second
reserved test at `bs_emit.erl:2102` (`reserved_forms/1`, which generates the local helper for `generated` rows); a complete
delta must, or a shadowing module that also uses `Term.Compare` or `List.Insert` carries a stray helper.

**Evidence.**
- Unshadowed programs are unchanged (P4, equal md5 of the code chunk).
- The cost is P3: **in any scope that shadows `List`, the standard `List.Sum` is unreachable** — the author must write whatever
  they shadowed. Shadowing does not warn.
- Prior art says user-wins is safe for **types** and unsafe for **modules**, which is the distinction ticket 65's table blurs:
  - *Types:* Erlang permits `-type map() :: …` since OTP 26 — as a **warning on by default** with an opt-out
    (`erl_lint.erl:3345-3347`, `:547`, `:844`; probe **65e** case 1, 1b). Gleam lets a user type be called `Result` or `List` with no
    diagnostic and `Ok(1)` still resolves (probe **65f** cases 1, 1b).
  - *Modules:* a user `lists` ahead of stdlib on the path **kills the VM at boot** (65e case 2: `Kernel pid terminated (logger)`, crash
    dump written); Elixir 1.19.5 `defmodule Map` warns, clobbers `Map.new/0`, and crashes **its own type checker** at
    `lib/module/types.ex:291` (a `put_in`, which `Kernel` expands to `Map.update!/3`, `kernel.ex:3372`) and its lexical tracker at
    `lib/kernel/lexical_tracker.ex:159` (probe **65d**; the control `Shop.Map` runs clean). This reproduces ticket 48 Q9's measurement on
    the same Elixir version.

**Strongest counterargument.** It is the one option that can produce a *silently wrong answer* when built halfway (above), and
fully built it still gives the word `List.` two meanings in the same language, which is exactly the property 67 bought by closing
the qualifier set: a reader seeing `List.Sum(x)` no longer knows whose it is without reading the `using` lines. Four of ticket 65's
five "prior art" languages did land on user-wins, but for **types, operators and traits**, not for module qualifiers.

### Considered, measured, not offered — an unreachable namespace (ticket option 2)

B# has no free sigil: `bs_lexer.xrl` has no `@`, `#`-prefix or `~` token to borrow. Minimal spelling costs one lexer rule, one
production beside `bs_parser.yrl:646-649` and a flag on `e_qcall`. The cost is the call sites: **31** qualified calls in 12 `.bs`
files, **186** in 9 eunit files, **29** in `LANGUAGE.md`/`TOUR.md`/`STANDARD-ENVIRONMENT.md`, 73 in feature files, 154 in tickets
(grep `\b(List|Map|Term|Float)\.[A-Z]\w*\(`). It would also reverse the spelling 96 Q2 chose (*"Names are Elixir's,
PascalCased"*). Not a candidate unless the closed-set assumption fails.

## Recommendation

**A.** It is what David decided at 96 Q6 and 67 Q6, it is the shipped behaviour, it fails loudly with the fix printed, and the
probes find no breakage to pay for. Close 65 as answered, with a `## Decisions entry` that points at 67 Q1, 67 Q6 and 96 Q6.
A small cost to carry knowingly: until each name lands, calling it gets the wrong fix ("add `using String`").

**What would change it:** (1) a handoff run in which a fleet-written program hits the day-of break — then B; (2) 93 resolved and a
second rename like F32's in the corpus; (3) any evidence of a program that did not break when it should have (a user-wins path
reaching the emitter).

**If David wants the list frozen (gating answer "no"), take B narrowed** to the roster names whose design is resolved, in one commit,
and state the list in the spec as *reserved* rather than *planned*.

## Sub-decision 6, for completeness (not a ticket)

`type option = int` and `module list` are refused as `syntax error before: option`. That is a diagnostic gap in a feature, not a
decision: 65a §D has the five cases. CLAUDE.md asks for a ticket only when a feature needs a *decision*; this one does not.

## Evidence ledger

| Probe | Claim tested | Control | Result | Does **not** show |
|---|---|---|---|---|
| [65a](probes/65/65a_what_is_reserved_today.sh) | What `bsc` reserves today; whether non-module declarations collide | `module String Enum Int …`, `Shop.List`, `record Widget`, `type Option` (all accepted) | 5 module names refused, 5 declaration kinds coexist, lowercase builtins refused as syntax errors | Behaviour of later-added qualifiers; protocol names beyond `Enumerable` |
| [65b](probes/65/65b_growth_of_the_standard_environment.sh) | Set is flat after founding | refuses to run on a shallow clone | 0→4 qualifiers by 2026-09-16, flat since; 30 rows | Future growth; the regex counts `{{'Q','Op',N}` keys only |
| [65c](probes/65/65c_blast_radius_of_reserving_the_roster.sh) | Cost of reserving the roster now | patched vs pristine on 29 modules; `module List/String` before/after | 0 differ; 22 compile; 0 collisions in 169 files; 517.7 vs 506.2 ms; wrong-fix diagnostic | External programs; the 7 non-compiling exemplars; a realistic author corpus |
| [65d](probes/65/65d_elixir_defmodule_map.sh) | Elixir `defmodule Map` still clobbers and crashes (1.19.5) | `Shop.Map` runs clean | reproduced, crash sites cited | Elixir ≥ 1.20 |
| [65e](probes/65/65e_erlang_shadowing.sh) | OTP 28 user type/module shadowing | fresh type name; `shop_lists` module | type: warning + opt-out; module `lists`: VM boot crash, `sticky_directory` on reload | Behaviour in releases (`rebar3`/`mix release` embed stdlib) |
| [65f](probes/65/65f_gleam_shadowing.sh) | Gleam 1.18.1 type/module shadowing | `Outcome`, `list`, `shop/list` | user types shadow prelude; only `gleam` reserved; `gleam/list` duplicate | Gleam's own stdlib sources beyond the path dep |
| [65g](probes/65/65g_user_names_win_prototype.sh) | User-wins cost; checker-only delta is wrong | P4 no-user-List; md5 of code | P1–P4 as shown; half-built prints 1 vs 99 | Delta complete at `bs_emit.erl:2102`; error-message quality; docs/gates updates |

## Not run, not measured, caveats

- **Elm: not run.** `elm make` needs `package.elm-lang.org`'s registry (403 here). I seeded `elm/core` and `elm/json` into a private
  `ELM_HOME` and the compiler got as far as asking for the registry. Elm claims rest on reading the compiler clone
  (`Elm/Compiler/Imports.hs:19-32`, `Parse/Module.hs:82`, `Reporting/Error/Import.hs:84,98`, commit `1c278bf`), not on a run.
- **Haskell, Rust, Scala rows of the ticket's table: not re-verified** (no local source). Two rows I did check: *Erlang* holds, with a
  nuance the table omits (default-on warning, and only for types); *Elixir* holds as a counter-example on 1.19.5 with the crash
  sites in 65d. *Elm* ("keeps default imports small") holds as to size — 11 entries in `Imports.defaults`.
- **C# not surveyed** (no local source).
- OTP 28.5 on x86_64 Linux only. The compiler under test is the repo's at the branch head; the scratch deltas never touched `compiler/`.
- 65c's "15 names" delta is a placeholder for the roster; it has no rows, so it measures the refusal and not any operation.
- `git fetch --unshallow origin` was run in the shared checkout to read history; it changes `.git` only.
