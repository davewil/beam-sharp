# The compiler at be9d56c: features, gates, REPL, LSP, and the clean-room handoff

**2026-09-01.** A read-only review of the compiler, measured against master `be9d56c`, written
so that the next review can diff against it rather than re-derive it. The rendered version, with
the diagrams, is the artifact
[The bsc Review](https://claude.ai/code/artifact/c6f95ef1-fde3-43b0-99e6-2b9a85d7b2c0); this
file is the record.

A snapshot, not a decision. Nothing here changes a ticket. **State lives in Linear**: the three
parents are `ENG-285` (compiler), `ENG-205` (LSP) and `ENG-244` (handoff), and every finding
below that is work names its child issue. This file will go stale as those close; the issues
will not.

---

## 0. The verdict strip

| Axis | Verdict | One line |
|---|---|---|
| Language features | 30 of 31 built | F1–F29 and F31 done or shipped. F30 spec'd, not started, held for David's read (`ENG-279`) |
| Gate suite | 37/37, twice from clean | 562 eunit tests green both runs. CI green on the last three pushes to master |
| REPL (`ibs`) | complete for its scope | Call-and-bind prompt over one module, 22 tests. One stale transcript (`ENG-286`); `:reload` never tested for its purpose (`ENG-288`) |
| LSP / completion | none | Highlighting only. No server, none started. Two of four compiler prerequisites built |
| Clean-room handoff | gate green, 13 gaps | Package builds and self-checks. Its README names files it does not ship (`ENG-289`); the audition's orchestrator contract is unwritten (`ENG-301`) |

## 1. What the compiler is today

About 10,000 lines of hand-written Erlang (leex and yecc output excluded) taking `.bs` through
lex, parse, exhaustiveness check and Erlang Abstract Format emission, then `erlc`. Beside the
pipeline: `bsc --diagnostics term` (F16), `bsc --api` (F17), the `ibs` REPL, and an `editor/` tree
holding a tree-sitter grammar plus two regex grammars that depend on nothing in the compiler.

| Module | Lines | Role |
|---|---|---|
| `bs_check.erl` | 3,142 | exhaustiveness, resolution, the five body check sites |
| `bs_types.erl` | 1,721 | the set-theoretic algebra: six part-wise buckets, intervals, subtraction |
| `bs_emit.erl` | 1,598 | Abstract Format emission with `-spec` |
| `bs_diag.erl` | 1,375 | the diagnostic term and the prose that is a pure function of it |
| `bs_parser.yrl` | 846 | yecc grammar, no `;`, zero conflicts |
| `bsc.erl` | 842 | the CLI: compile, run, `--api`, `--repl`, `--diagnostics term` |
| `bs_repl.erl` | 490 | the prompt |
| `bs_run.erl` | 388 | argument parsing in B# notation and the run mode |
| `bs_api.erl` | 337 | the declaration-level query |
| `bs_lexer.xrl` | 314 | leex, line-only positions |

## 2. Language features

Status is read from each feature file's own `**Status**` line, per the rule the features README
states about itself (`compiler/features/README.md:206-208`). The README table agrees with all
31 F-files on status word and date.

### 2.1 The grid

| F | Title | Status | Named debt still open? |
|---|---|---|---|
| F1 | walking skeleton | done 2026-08-13 | three gaps recorded in the file, all since closed by F2, F16 |
| F2 | interval refinements | done 2026-08-16 | — |
| F3 | records | done 2026-08-14 | — (its three deferred scenarios closed in F5) |
| F4 | local bindings | done 2026-08-14 | — |
| F5 | body check site | done 2026-08-14 | — |
| F6 | angle brackets, generics | done 2026-08-14 | **yes** — §(c) polymorphic signatures, `>>` (`ENG-295`) |
| F7 | switch | done 2026-08-15 | — |
| F8 | var binds, = matches | done 2026-08-16 | — |
| F9 | string and binary | done 2026-08-15 | — |
| F10 | OTP callbacks | done 2026-08-15 | — |
| F11 | module system | done 2026-08-17 | — |
| F12 | public / private | done 2026-08-17 | — |
| F13 | binary patterns | done 2026-08-20 | — |
| F14 | pipe and valve | done 2026-08-18 | — |
| F15 | module is a directory | done 2026-08-17 | — |
| F16 | diagnostic as a term | done 2026-08-18 | **yes** — JSON encoding (`ENG-298`) |
| F17 | `bsc --api` | done 2026-08-18 | same debt as F16 |
| F18 | `ValidateAs<T>` | done 2026-08-18 | **yes** — `ParseAtom<T>`, `ToExistingAtom` (`ENG-294`) |
| F19 | foreign try wrapper | done 2026-08-18, §2 reversed by F23 | **yes** — `raise` (`ENG-293`) |
| F20 | list length | done 2026-08-21 | — |
| F21 | field-value obligations | done 2026-08-21 | — |
| F22 | record pattern, binder | done 2026-08-22 | — |
| F23 | value-returned foreign error | done 2026-08-22 | same debt as F19 |
| F24 | boundary kind | done 2026-08-23 | **yes** — ticket 46's range half (`ENG-292`) |
| F25 | corrected signature | done 2026-08-23 | **yes** — §3, §6, §7 (`ENG-296`) |
| F26 | division, remainder | done 2026-08-25 | — |
| F27 | no negation | done 2026-08-26 | — |
| F28 | recursive types | done 2026-08-30 | — |
| F29 | residual prints a pattern | shipped 2026-08-27 | — (§1, §2 not built and not needed) |
| F30 | valve stops on `:nothing` | **not started** | the feature itself (`ENG-279`) |
| F31 | collapse at declaration | done 2026-08-28 | — |

### 2.2 Debts inside done features

This is the part that was not visible. The grid reads green; these sentences sit inside green
files saying a thing is unbuilt, and no later file struck them. As of this review each has an
issue, labelled `debt` in Linear, and `ENG-291` is the gate that will refuse any future one that
does not.

| Debt | Recorded at | Issue |
|---|---|---|
| Ticket 46's *range* half of the boundary guard: `Classify(300)` on an octet parameter still accepted at the exported boundary | `F24:150`, `F24:13`, `F2:8-10` | `ENG-292` |
| `raise`, ticket 12 §5's spelling for the producing half of the error model | `F19:242`, `F23:200` | `ENG-293` |
| `ParseAtom<T>` decided (10 §4) and unbuilt; `ToExistingAtom` owed | `F18:293-294`, `PRELUDE.md:108` | `ENG-294` |
| Polymorphic function signatures, F6 §(c); `>>` pinned but not solved | `F6:32`, `F6:333` | `ENG-295` (waits on David's ordering call in `ENG-204`) |
| F25 §3 and §6 unbuilt; §7 waits on ticket 22; §5 on ticket 16 §4 | `F25:12-13` | `ENG-296` |
| A JSON encoding of the diagnostic term, blocked on ticket 16 §4's serialisation mapping | `F16:137-139`, `F17:217`, `README.md:772` | `ENG-298` |
| Ticket 09 §4: a union may carry a member nobody can discriminate | Linear | `ENG-273` |
| `with`'s subject is not type-checked | Linear | `ENG-249` |
| A module that declares a name cannot call a top-level module that exports it (ticket 47's build half) | `bs_check.erl:416` | `ENG-270` |
| F30: the valve short-circuits on `(:error, _)` alone | `F30:3-7` | `ENG-279` |

**F30 is waiting on David, not on an agent.** Its spec found two things ticket 49 did not have:
existing correct programs' return types widen, and the shape 49 called "skipped silently" is
refused loudly today, so F30 replaces a working diagnostic with a silent skip. Its named gate
`check-valve.sh` does not exist yet, consistent with "not started".

### 2.3 Two small defects in the features README

- A blank line at `README.md:112` splits the feature table between F20 and F21.
  `check-status-claims.sh` greps for rows and does not notice. → `ENG-287`
- The correction at `README.md:781-785` saying the residual is not pasteable is itself stale:
  all eleven shapes read `clean` since F29 landed. → `ENG-287`

## 3. The gate suite, measured

Two fresh clones of `be9d56c`, each through `mise exec -- ./bin/verify.sh`, each with the fresh
`SPEC_CHECK_DIR` the script assigns itself.

| Run | Stages | eunit | Elapsed |
|---|---|---|---|
| 1 | 37 of 37 passed | All 562 tests passed | 398 s |
| 2 | 37 of 37 passed | All 562 tests passed | 390 s |

CI on master: the last three pushes (2026-08-31 01:35, 2026-08-31 13:57, 2026-09-01 00:22) all
green, about 12 minutes each. Thirty gate scripts across four `bin` directories, every one wired
into CI, `verify.sh` and the session list, which stage 4 asserts. *(2026-09-05: the session list
and seven of those gates were deleted at `ab7a196`; stage 4 now asserts the workflow and the entry
point.)*

Two counts in the tree are behind the 37: F28's status line says 36 stages, and the audition's
`stage.sh` comment says "stage 12 of 34". Neither is a gate failure. → `ENG-287`, `ENG-290`

On `ENG-229`: the named cause was removed on 2026-08-29 by routing every test subprocess through a
port with an exit status. These two runs make seven consecutive clean-clone greens against a former
20–40 % per-run failure rate. The issue stays open only on the rate question.

## 4. The REPL

`ibs -S examples/Fib` compiles the module to a temp dir, loads it and hands you a prompt.
`bs_repl.erl` is 490 lines with one export, `start/3`, reached only through `bsc --repl`.

| | |
|---|---|
| accepts | one call per line, `Name(arg, …)`; `var x = e` to bind; bare `=` to match; `== name` to match a bound value; tuple and list destructuring; `_` |
| commands | `:reload`, `:exports`, `:env`, `:quit` / `:q`; an unknown command is refused by name |
| says no to | a private function, by name and with the word "private"; a declaration ("put it in the file and `:reload`"); an unbound name; `--diagnostics term` under the prompt, as a refusal not a fallback |
| does not have | expressions, multi-line input, history, tab completion, type queries. The parser reads declarations, so a wider prompt waits on an expression parser |
| tests | 22 in `repl_tests.erl`, all driving the escript with stdin from a file |

### Findings

1. **`compiler/README.md:127-133` is stale and nothing replays it.** It shows `t = 9` binding at
   the prompt. F8 made a bare `=` match. Run today: the prompt answers *"t is introduced here, and
   a bare `=` matches rather than introduces -- write `var t = ...`"*, and the whole block is
   unreachable because `t` never binds. `check-tour.sh` reads `TOUR.md`, `check-language.sh` reads
   `LANGUAGE.md`; no gate reads this file. → `ENG-286`
2. **`:reload` is tested only for answering.** The module header calls it "the point of the
   thing" (`bs_repl.erl:12`); no test edits a file and observes the new behaviour. → `ENG-288`
3. **Three stale counts of one file.** `check-no-silent-skip.sh:24` says 20 tests; the module
   header says 12; there are 22. → `ENG-288`

## 5. LSP and editor completion

There is no language server, no client, no partial one. Greps for `textDocument`, `jsonrpc`,
`hover`, `goto definition` and `publishDiagnostics` return nothing outside generated C. The VS
Code extension is data-only: grammar and language configuration, no `main`, no activation events,
no dependencies.

What exists is highlighting at three levels, each gated: a tree-sitter grammar (stage 37, 16 of 16
examples parse with no ERROR node), a TextMate grammar and a vim syntax file (stage 36, every lexer
keyword present in both). `editor/README.md:11-12` is candid that the regex grammars cannot separate
`list<int>` from `a < b && c > d` and that tree-sitter is the destination.

The LSP is deliberately off the design map and tracked as `ENG-205` *(this sentence cited
`wayfinder/scope.md:35` until 2026-09-05, when that file was deleted)*. Its
prerequisite table had aged: it still said ticket 23 §1 and §10 were unbuilt, and both shipped on
2026-08-18 as F16 and F17. Corrected in place on 2026-09-01. The prerequisites, in build order:

| Prerequisite | State | Issue |
|---|---|---|
| 23 §1 — the diagnostic is a term | **built**, F16 | — |
| 23 §10 — `bsc --api` | **built**, F17 | — |
| columns: `bs_lexer.xrl` has 56 `TokenLine` actions, zero `TokenCol`/`TokenLoc`; six resolve-time errors carry no position | open, no decision owed | `ENG-297` |
| 23 §5 — a JSON encoding of the term | **blocked** on ticket 16 §4, which has no ticket of its own | `ENG-298` |
| a broken buffer: tree-sitter as the parse front, or yecc recovery | unmeasured | `ENG-299` (prototype) |
| the server: a `bsc` subcommand on Gleam's model | blocked by the three above | `ENG-305` |

What `--api` can and cannot carry: module atom, behaviours, every public signature with types
resolved. No positions, no per-expression types, no private functions. A substrate for signature
lookup, not for hover or completion at a use site.

## 6. The clean-room handoff

The package is defined by one file, `handoff/MANIFEST`: five spec documents, the compiler's own
README, every feature file, and the whole examples tree. Compiler source is excluded on purpose.
Built today: 89 files plus a lock with a SHA-256 per file.

### 6.1 Proven, live

Stage 12 passed in both clean-clone runs: the manifest covers the tree, the artifact holds
everything named, it refers only to itself by the gate's definition, provenance is true, two
builds to different paths are byte-identical, and the 16 compilable example modules compile under
the reference `bsc`. Both self-tests go red on their controls. Stage 13 proves the audition's
marker can tell an implementation from a lookup table.

### 6.2 What the audition established

| Round | Engine | Visible | Held-out | Note |
|---|---|---|---|---|
| 1 · 2026-08-22 | grok-4.6 | 7/8 | 7/7 | first attempt; its `run.json` records the contaminated attempt 2 |
| 1 | copilot claude-sonnet-5 | 7/8 | 7/7 | at one eighth of grok's tokens |
| 1 | copilot claude-haiku-4.5 | 7/8 | 3/7 | no `run.json` in its own lane |
| 1 | codex, deepseek | no measurement | | usage limit and server error; the harness refused to score either |
| 2 · after spec fix | copilot claude-sonnet-5 | 8/8 | 7/7 | first attempt, no retry |

Three of nineteen sections ship in the packet, the worker writes an analyser not a compiler, and a
perfect score is evidence that the specification of `switch` transfers, not that the language
does. The other sixteen sections have never been auditioned. The packet was rebuilt on 2026-08-28
(`c7c99be`), so every score above predates the artifact it would be evidence for; `ENG-248`'s last
criterion is open on exactly this.

### 6.3 Reproducibility gaps, substantiated

| Group | Gap | Source | Issue |
|---|---|---|---|
| package | The shipped README tells the recipient to run `mise install` and `./bin/verify.sh`; neither `.tool-versions` nor `bin/` ships. The gate inspects markdown links only | artifact `README.md:46-47`; `check-handoff-package.sh:94, 148-168` | `ENG-289` |
| package | The Layout block names `bin/`, `editor/`, `handoff/` without a "not shipped" mark | artifact `README.md:157-162` | `ENG-289` |
| package | A recipient without mise learns nothing: stage 1 requires mise-owned binaries and the runner stops at the first red | `README.md:71-72`; `verify.sh:57-63` | a decision, recorded on `ENG-244`, not a child |
| audition | the orchestrator contract is stated nowhere runner-independently; the README gives `ringer.py` as the only recipe. *Corrected 2026-09-01 23:07: this row first said the runner was missing. David: "ringer.py is not necessarily a pre-requisite, it was an example of what might be used to orchestrate the build of the clean-room handoff, other implementors might choose a different path."* | audition `README.md:125-126`; `stage.sh:11-16`; `run.sh:8-25` | `ENG-301` |
| audition | `ENGINES.md`'s manual paste is that example orchestrator's configuration, presented as a step in the recipe | `ENGINES.md:77-80` | `ENG-301` |
| audition | `manifest.json` hardcodes this checkout's absolute path five times | `manifest.json:11,24,37,50,63` | `ENG-300` |
| audition | the scores predate the packet | audition `README.md:67-70` | `ENG-248` |
| evidence | no round directory has a summary | `evidence/` | `ENG-302` |
| evidence | haiku's clean re-run has no run record of its own | `evidence/…/copilot-sonnet5/run.json` `tasks[1]` | `ENG-302` |
| evidence | grok's machine record is the contaminated attempt; the clean 7/8 exists only in prose | `evidence/…/grok/run.json`; audition `README.md:290` | `ENG-302` |
| ungated prose | nothing under `handoff/` is link-gated | `check-links.sh:143-149` | `ENG-304` |
| ungated prose | §3 Exhaustiveness ships in the packet with one bare fence and zero compiled blocks; §15–§19 likewise | `LANGUAGE.md:345-373`; `check-language.sh:176` | `ENG-303` |
| stale counts | "THREE CONTROLS" against four plus a positive; "stage 12 of 34" against 37; "46 of its 84 fences" against a file that no longer has 84 | `check-handoff-package.sh:186`; `stage.sh:38-40`; audition `README.md:430` | `ENG-290` |

The one gap that changes what a recipient can do is the first: the package's own opening
instructions cannot be followed from inside the package. Everything else degrades confidence in
the record; that one stops the recipient at step one.

## 7. Where the frontier is, and the order

From Linear, filtered to the project. Quick fixes first, then debts with the gate that guards
them, then the frontier that was already filed.

| Parent | Tier | Issues |
|---|---|---|
| `ENG-285` compiler | quick fixes | `ENG-286`, `ENG-287`, `ENG-288` |
| | debts | `ENG-291` (the gate, first), then `ENG-292`, `ENG-293`, `ENG-294`, `ENG-295`, `ENG-296` |
| | frontier | `ENG-270` (High, ready-for-agent), `ENG-279` (F30, David's read), `ENG-249`, `ENG-273` |
| `ENG-205` LSP | prerequisites, in order | `ENG-297` → `ENG-298` → `ENG-299` → `ENG-305` |
| `ENG-244` handoff | quick fixes | `ENG-289`, `ENG-290`, `ENG-304` |
| | then | `ENG-300`, `ENG-302`, `ENG-303`, `ENG-301` (write the orchestrator contract once, runner-independently) |
| | unchanged | `ENG-248` (fresh engine run; `c09`–`c11` need no engine), `ENG-229` (rate only), `ENG-263` (two build items) |

## 8. Claim → source

| Claim | Source | How checked |
|---|---|---|
| 30 of 31 features done or shipped; F30 not started | `compiler/features/F*.md:3`, each | grep of every Status line |
| Features README table agrees with all 31 F-files | `compiler/features/README.md:92-123` | row-by-row comparison |
| 37 stages, 562 tests, twice from clean | two fresh clones of `be9d56c`, 2026-09-01 | run |
| CI green on master | GitHub Actions runs 33454471830, 33399833638, 33348062026 | queried |
| REPL transcript stale | `compiler/README.md:127-133`; `repl_tests.erl:230-236` | ran `ibs -S examples/Shop` |
| Lexer is line-only | `compiler/src/bs_lexer.xrl` | 56 `TokenLine`, 0 `TokenCol`/`TokenLoc` |
| No LSP code | whole repo minus `_build`, `node_modules` | grep for six protocol terms |
| ENG-205 table stale on F16/F17 | Linear `ENG-205` (updated 2026-08-27); features `README.md:770` | read both; corrected 2026-09-01 |
| Package ships README naming unshipped files | `handoff/MANIFEST`; built artifact `README.md:46-47` | built the package, tested for `bin/` and `.tool-versions` |
| §3 has no compiled block | `LANGUAGE.md:345-373` | counted fences between the headings |
| Audition scores and rounds | audition `README.md:144-150, 338-340, 410-413`; `evidence/*/run.json` | read; `PACKET.md` last commit `c7c99be` 2026-08-28 |

---

Measured by three read-only sweeps (features, REPL and LSP, handoff) plus direct runs. Nothing in
the repository was modified by the review itself; this file and the Linear issues are its output.
