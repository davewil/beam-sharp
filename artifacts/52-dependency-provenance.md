# Decision brief — ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

Status of this brief: **evidence and a recommendation. Nothing is decided.** The ticket stays open for David.
Ticket: `wayfinder/issues/52-dependency-provenance.md`. Probes: `artifacts/probes/52/` (`./run.sh` runs all; last output in `run.out`).

**Environment caveat.** Measured on OTP 25.3 / Elixir 1.14.0 / Gleam 1.12.0 / Elm 0.19.1. The tickets were measured on OTP 28 / Elixir 1.19, so absolute timings are not comparable. `bsc` was rebuilt from `compiler/src` on OTP 25 with a lexer patch (leex there has no `TokenLoc`), so diagnostic *columns* are wrong; none of the probes read a column.

## The program under question

What exists today (`compiler/src/bs_parser.yrl:170`, `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'`):

```csharp
module Dep

using :fakereq {
    term new(list<(atom, term)> opts)
}

public term Make(int n)
Make(n) -> :fakereq.new([(:n, n)])
```

Measured (P1): with `fakereq` off the code path, `bsc Dep` **compiles clean** (exit 0), and running `Make 1` ends `crashed: error:undef`. With `ERL_LIBS` pointing at the app it prints `(:request, [(:n, 1)])`. The source promises nothing, the compiler checks nothing, and the failure lands at the call site, as the ticket says.

(The ticket's sketch `[external: elixir, app: req] using :'Elixir.Req' { … }` predates the final `using :atom { … }` form of ticket 32; the app clause below is therefore written as an extra word on the `using` line. The spelling is not prototyped — only its checks and emission are.)

## Sub-decisions

| # | Sub-decision | Gates |
|---|---|---|
| Q1 | Does the source name the application at all? | everything else |
| Q2 | If so, name only, or name + version constraint? | needs Q1 = yes |
| Q3 | Per `using` block, or once per module? | needs Q1 = yes |
| Q4 | What does the compiler do with it, and how loudly? | needs Q1 = yes |

Ask **Q1 alone first**; the rest follow. The options below are therefore the three answers to Q1/Q2, with Q3/Q4 resolved inside each.

## What was measured

### M1. A compile-time presence check is feasible, cheap, and needs no declaration (P3, P2)

A scratch copy of `bsc` with **one line** added in `bs_check:check_dir1/3` (the line after `Module = module_name(Decls)`, `bs_check.erl:99`) calling `code:which/1` over the `{foreign, Line, Mod, Sigs}` decls (the same pattern `bs_check.erl:623` already matches):

```
--- module absent
probe52: line {3,1}: using fakereq: module not on the code path
--- module present      (no output)
```

| call | cost, 2000 calls, this box |
|---|---|
| `code:which(lists)` (OTP, loaded) | 2.7 µs |
| `code:which(fakereq)` (on `ERL_LIBS`) | ~120–145 µs |
| `code:which(nope)` (absent; walks the whole path) | ~1.1–1.2 ms |

So a module with N foreign blocks costs ≈ N × 0.1–1.2 ms. Negligible next to a compile.

### M2. What OTP can tell a compiler, and what it cannot (P2)

| question | answer |
|---|---|
| Is module M reachable? | `code:which(M)` → path or `non_existing` |
| Is application A reachable? | `code:lib_dir(A)` → dir or `{error,bad_name}`; `code:where_is_file("a.app")` |
| Which app owns module M? | `application:get_application(M)` is **`undefined` until the `.app` is `application:load`ed**; after that `{ok,fakereq}`. Without loading, you scan every `.app` on the path (38 files, ~4–9 ms) |
| Is the module→app name derivable from the module name? | **No.** `'Elixir.Logger'` is in app `logger`, `'Elixir.String'` in `elixir`; `'Elixir.Req'` is in `req` only by convention |
| What is A's version? | `application:get_key(A, vsn)` after load → `{ok,"1.2.3"}` |

The consequence: the app name in the source is **information the compiler cannot reconstruct when the dependency is absent** — and absence is the only case where the name matters. That is the one thing a declaration adds over M1.

### M3. Carrying it into the `.beam` is almost free and survives (P4)

On the real emitted `Interop` module (`compiler/examples/Interop`), re-compiled from its own `.abstr` with a `-bs_requires` attribute:

| attribute | `.beam` bytes | Δ |
|---|---|---|
| none | 1324 | 0 |
| `-bs_requires([req])` | 1368 | **+44** |
| `-bs_requires([req,jason,plug_cowboy])` | 1408 | +84 |
| `-bs_requires([{req,"~> 0.7"}])` | 1392 | +68 |
| three attributes, one per `using` block | 1440 | +116 |

Readable **without loading** by `beam_lib:chunks(B, [attributes])` → `[req]`, and after load by `Mod:module_info(attributes)` → `[req]`. So a tool (or the clean-room judge) can ask a compiled module what it needs.
Caveat: bsc's own `Interop.beam` is 1384 bytes (60 more than my `compile:forms` re-compile, which lacks the file/source chunk). Only the deltas are claimed.

### M4. Version constraints cannot lean on what exists (P7)

`vsn` strings from the `.app` files installed here: `elixir 1.14.0`, `logger 1.14.0`, `mix 1.14.0` parse under Elixir's `Version.parse/1`; **`kernel 8.5.4.2`, `stdlib 4.3.1.3`, `ssl 10.9.1.3`, `crypto 5.1.4.1` are refused** (four-part OTP versions). `Version.match?("1.2.3", "~> 1.2")` is `true`, so the constraint algebra exists in Elixir, but `bsc` is Erlang and would need its own comparison, plus a requirement syntax of its own.

### M5. How the neighbours handle the same fact

| language | where the dependency is declared | what the compiler does when it is missing | evidence |
|---|---|---|---|
| **Erlang** | `.app` `applications` list, outside the source | `erlc` compiles a call to `nosuch:call/1` **silently**; `xref` (separate tool) reports `{{b,f,0},{nosuch,call,1}}`; `systools:make_script` refuses a release naming an absent app (`{error_reading,{fakereq,{not_found,"fakereq.app"}}}`) | P5; `systools_make.erl:589` (`/usr/lib/erlang/lib/sasl-4.2/src/`) |
| **Elixir** | `mix.exs` `deps` + `extra_applications`, outside the source | **warning, not error**: `Req.new/1 is undefined (module Req is not available or is yet to be defined)`; `elixirc` exits 0. Under mix, a module from an app the project does not depend on warns `defined in application :logger … does not depend on :logger` | P5; absent-module message at `lib/module/types/of.ex:332`; `extra_applications` is validated at `lib/mix/tasks/compile.app.ex:288` (Elixir 1.14.0 debug_info, P6). The "does not depend on" text was **observed** (P5) but its source line was not located |
| **Gleam** | `gleam.toml` `[dependencies]` (Gleam owns the manifest) | module in no package: **error** `Unknown module`. Module from a *transitive-only* package: **warning** `Transitive dependency imported … is not a direct dependency of your package. In a future version of Gleam this may become a compile error.` | P8, executed with path deps |
| **Elm** | `elm.json` | not measurable here: `elm make` needs `package.elm-lang.org` (403 from this box); the only observed output was `MISSING DEPENDENCY … elm.json` for an absent `elm/json` | probe in transcript, **not reproduced as a script** |

Gleam and Elm sources were not reachable (GitHub archive/API 403), so no `file:line` is cited for them; Gleam's claims are executed output only. No neighbour puts the dependency *in the source file*; the real question for B# is that ticket 51 gave B# no manifest, so the source file is the only B#-owned place.

---

## The options

### Option A — Say nothing in the source; add the presence check anyway

```csharp
using :fakereq { term new(list<(atom, term)> opts) }   // unchanged
```

Compiler delta: one function call in `check_dir1` (M1), a diagnostic in `bs_diag`. Nothing emitted.

* Compiles under A, refused under neither: `using :fakereq` with the app absent prints "module `fakereq` is not on the code path" (as a warning, to match Elixir, or an error, to match Gleam).
* Evidence: M1 (≈1 ms, one line), M5 (Elixir does exactly this with no declaration).
* **Strongest counterargument:** it fixes the *symptom* and not the ticket's actual complaint. The ticket's argument is the handoff — a program "whose dependencies exist only in the environment that happened to build it cannot be handed over". Under A the program still names a module, not an application; the diagnostic cannot say *what to install* (M2: module→app is not derivable), and a machine without the dependency compiles the same program fine (P1) and only learns at run time when A is a warning.

### Option B — Name the application, per `using` block; no version

```csharp
using :'Elixir.Req' app req {          // spelling illustrative
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' app req {  // repeated: same app
    ...
}
```

Compiler delta, concretely:
1. `bs_parser.yrl:170`: `foreign_decl` gains an optional `app <lident>` and the AST `{foreign, L, Mod, Sigs}` a fifth element (the one pattern at `bs_check.erl:623` and its siblings must accept it).
2. `bs_check:check_dir1` (line 99): for each declared app, `code:lib_dir(App)` and `code:which(Mod)`; a declared app that is absent is an **error naming the app**; an undeclared foreign module is unchecked (as today).
3. `bs_emit.erl:73-77`: one `{attribute, ?A, bs_requires, Apps}` (deduplicated), +44 bytes for one app (M3).
4. Optional, Gleam-style cross-check: if the module is found but its owning app (via a loaded `.app`) differs from the declared one, say so. Costs a path scan (M2, ~4–9 ms), so it is optional and probably only under `--check-deps`.

* The failure it turns into a diagnostic: `error: using :'Elixir.Req' needs application req, which is not on the code path (ERL_LIBS)` instead of `error:undef`.
* Evidence: M1–M3.
* **Strongest counterargument:** it writes the same fact a second time. `mix.exs`/`rebar.config` still must list `req`; the `.bs` file says it again, and nothing forces the two to agree (the Gleam cross-check in step 4 is the only guard, and it does not exist for B# unless built). Per-block repetition also makes a Req binding say `app req` once per foreign module of Req (M3: +116 bytes for three attributes if not deduplicated, +44 if it is). Honest framing: A is a diagnostic; B turns a diagnostic into a *promise the source makes*, which is what the handoff needs and what costs a keystroke per block.

### Option C — Name and version constraint, per module

```csharp
module Shop.Billing requires req "~> 0.7"      // spelling illustrative
using :'Elixir.Req' { ... }
```

Compiler delta: everything in B, plus a requirement parser/comparator in `bsc` and a choice of requirement dialect.

* Evidence: M4. Elixir's `Version` handles `"~> 0.7"` but **rejects OTP's own four-part versions**, so an app named `kernel`/`ssl` could not be checked by reusing it; `bsc` would own a comparator.
* **Strongest counterargument (against C):** the ticket itself says a version constraint "is resolution, which is the boundary's territory and should stay refused". A recorded constraint that nothing resolves is a claim the compiler cannot enforce except by comparing against whatever happens to be installed — a *check*, not a resolver, but it forces `bsc` to pick a constraint dialect (a third one beside whatever `mix.exs`/`rebar.config` use), and it duplicates `mix.lock`'s job. Counter-counter: it is the only option that lets the handoff say "0.7.x", and Gleam does carry versions — but Gleam owns the manifest and B# decided not to (ticket 51).

## Q3 and Q4 inside the options

* **Per block vs per module.** Nothing measured separates them on cost (M3: dedup makes both +44). A module is a **directory** (F15) with several files, each with its own `using` blocks; "once per module" needs a home (`index.bs`?) that is not the place that justifies it. Per block puts the app next to the signatures that need it, and the check already runs per block. *Recommendation: per block, deduplicated at emission.*
* **Severity.** Today `bsc` compiles with the module absent (P1) and the elixir/erlang neighbours warn. A hard error for a *declared* app that is absent breaks compile-only runs on a machine without the dependency (e.g. a judge type-checking a binding). *Recommendation: error when an app is declared and absent; no check when nothing is declared; provide an escape (`--no-deps-check`) only if a ticket from the audition shows it is needed.* That asymmetry is the point of B: the declaration is what creates the obligation.

## Recommendation

**Option B**, name only, per block, with the check as an error for a declared-and-absent app and the attribute emitted deduplicated. It is the smallest change that makes the *source* say what it needs (the handoff argument, which Option A does not meet), it costs ~1 ms of compile time and +44 bytes, it turns `error:undef` into a named diagnostic, and it stays on the right side of ticket 51 (no resolution, no lock, no fetch). Do C's version only if the audition shows a failing ticket that a name could not have prevented; the dialect question alone makes it a separate ticket. **Sequence with ticket 50** as that ticket asks: both extend the `using` declaration, and the parser change in step 1 should be made once.

## Probe honesty notes (what could be circular)

* **P3** adds the hook myself and the absent-module case is absent because I removed it from `ERL_LIBS`; it proves *feasibility and cost*, not that the diagnostic is what David would want.
* **P4** uses `compile:forms` on bsc's `.abstr`, not bsc's own pipeline (baseline 60 bytes off, see M3 caveat). Deltas only.
* **P5/P8** neighbour behaviour is observed on the versions installed here (Elixir 1.14, Gleam 1.12), not the OTP 28 / Elixir 1.19 the tickets use; Gleam's "may become a compile error" wording is from 1.12 and could differ later.
* Elm and the Gleam/Elixir source files were unreachable; no `file:line` is cited where none was read.
* The spelling `using :'Elixir.Req' app req { }` is a placeholder, not a design.
