# Decision brief — ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

**Status of the ticket: left open.** This brief recommends; it decides nothing.
Probes: `artifacts/probes/52/` (`probe.sh`, `prototype.sh`, `output-*.txt`, `proto.patch`). Toolchain and caveats: `artifacts/probes/README.md`.

## The gating question (ask this one alone)

> Does the **source** name the application a `using :'Elixir.Req' { … }` block needs — yes or no?

Everything the ticket lists (name vs version, per block vs per module, what the compiler does) only exists if the answer is yes. The ticket's argument for yes is the handoff: a clean-room implementer given only the `.bs` files must learn what to fetch.

## Measured facts

1. **Today the compiler says nothing, and the artefact records nothing.** With `Req` absent, `bsc` compiles `using :'Elixir.Req'` with exit 0 and writes the `.beam`; running it gives `crashed: error:undef`. The `.beam` carries only `[{vsn,[…]}]` — no application, no module list (`probe.sh` P1–P3).
2. **The VM can answer "is it here" in microseconds** (`P4`, mean of 20,000 calls, OTP 29 on this VM): `code:which(M)` roughly 10–22 µs loaded and 13–30 µs absent (varies run to run; my first draft's 9.4/27.5 µs matches no rerun); `code:lib_dir(App)` **1.4 µs absent**. A compile-time presence check is free next to the ≈5 ms a module takes to compile (ticket 57's measure).
3. **Module → application is derivable when the module is present** (`P5`): `code:which(lists)` → `…/stdlib-8.1.1/ebin/lists.beam` → app `stdlib`. It is **not** derivable when the module is absent (`'Elixir.Req'` → `non_existing`) — and absent is exactly the handoff case. Elixir's own modules are only found if Elixir's lib dir is on the path (`P6`: `Logger` lives in app dir `logger`; plain `erl` reports `non_existing`).
4. **A hard compile-time check breaks what ships.** Prototype (`proto.patch`, **2 added lines** in `declared/4`): refuse a `using :mod` block whose module `code:which` cannot find. Across `compiler/examples`, `LANGUAGE.md`, `TOUR.md`, `STANDARD-ENVIRONMENT.md`, `aoc/`: **10 distinct foreign modules are named; 8 resolve on this machine, 2 do not**: `analytics_db` (3 uses) and `epgsql` (1). They sit in `LANGUAGE.md` lines 740/758/774 — two of those blocks are plain ```` ```csharp ```` fences that `check-language.sh` requires to compile, and the third expects a specific refusal — and in `compiler/examples/exemplars/25d-database-querying/index.bs:12` — **verifier correction:** exemplars/ is excluded from `check-examples` and FRONTIER already records 25d as having no module line, so a hard check cannot break it. The verifier also found that my scan missed `compiler/test`, where eunit names absent modules (`users_db`, `session_store`, `accounts_db`, …): a hard check would break eunit too. The prototype turns all three LANGUAGE.md blocks red (the diagnosed one gets `unknown_module` in place of `foreign_ret_beyond_one_guard`). (`prototype.sh` output.)
5. **There is no attribute syntax to hang `[app: req]` on.** The ticket's spelling `[external: elixir, app: req] using …` does not parse today: `error: syntax error before: '['` at the attribute line (`prototype.sh`, last lines). `grep -n attr compiler/src/bs_parser.yrl` finds nothing; ticket 32's `[external: …]` form is not what shipped (`using :mod { … }` is). Option A below therefore carries a parser addition the ticket did not price.

6. **Two further verifier findings.** (i) `code:which(erlang)` returns the atom `preloaded`, so "derive the app from the path" (fact 3, option C) fails for the most common foreign module, `erlang` itself. (ii) bsc's beams already carry abstract code, so `xref` on bsc's own `R.beam` reports `{'Elixir.Req',new,1}` as undefined today, with no compiler change; xref gives `[]` only on a beam built without `+debug_info`. No shipped example uses `Elixir.Req`. The ~5 ms compile figure, the `-bs_needs` attribute and "a warning breaks nothing that ships" were not probed.

## Survey

| language | where the dependency is named | what the compiler does about a missing one | evidence |
|---|---|---|---|
| Elixir 1.20.4 | `mix.exs` `deps` (outside source) | **compile-time warning**: `Req.new/1 is undefined (module Req is not available or is yet to be defined)` | `probe.sh` (executed) |
| Gleam 1.19.1 | `gleam.toml` `[dependencies]` (outside source); `@external(erlang, "Elixir.Req", "new")` in source | nothing: `@external` to a missing module **builds silently** | `probe.sh` (executed); dependency resolution itself cannot be exercised here (hex.pm blocked) |
| Erlang | `.app.src` `applications` (outside source) | `erlc` compiles silently; `xref` reports `[{{e,go,0},{'Elixir.Req',new,1}}]` as `undefined_function_calls`, but only on a beam compiled with `+debug_info` | `probe.sh` (executed) |
| Elm | `elm.json` | not probed — package server unreachable | — |

Reading: **nobody puts the application name in the source file.** Every neighbour keeps it in a manifest and either warns (Elixir) or does nothing (Erlang, Gleam). Option A would be a first. Elixir's choice — warn, never refuse — is the one that survives code that is legitimately compiled before its dependency is installed.

## Options

**A. The block names the application.** Syntax is new: either an attribute construct (nothing like it exists) or a clause on `using`.
```csharp
using :'Elixir.Req' from req {          // spelling illustrative
    term new(list<(atom, term)> opts)
}
```
Compiler delta: a parser production; `code:lib_dir(req)` at `declared/4` (1.4 µs absent); an `-bs_needs([req])` beam attribute so the artefact carries it; a diagnostic. **Not prototyped** — only the presence check (fact 4) was.
Strongest counterargument: it duplicates `mix.exs`/`rebar.config` in a place no tool reads, and the name can drift from the manifest. And fact 4 stands: if the check is an error, `LANGUAGE.md` and exemplar 25d stop compiling until each gains a `from` for an app that still does not exist on any machine; if it is a warning, nothing enforces the very thing the ticket wants.

**B. The module names its applications once, at the top.** `needs req, jason` beside `module`.
Delta: one header production; the same check and attribute as A. **Not prototyped.**
Strongest counterargument: the declaration sits away from the `using` it explains, so a `using` can be added with no `needs` and nothing links them — unless the compiler cross-checks, which is more work than A.

**C. The source says nothing; the compiler warns and records.** At each `using :mod { … }`, `code:which(Mod)`: absent → a *warning* (Elixir's behaviour); present → write the app derived from its path (fact 3) as an `-bs_needs` beam attribute.
Delta: **2 lines for the check as an error (measured)**, plus warning plumbing and the attribute; no syntax.
```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }   // unchanged source; bsc: warning: Elixir.Req is not on the code path
```
Strongest counterargument: it does not meet the ticket's argument. The handoff case is precisely "dependency absent", and fact 3 shows the app is derivable only when the module is present — so the clean-room implementer still cannot learn from the source that the program wants `req`.

## Recommendation

**C now, A only if the handoff truly needs the name in the source.** C costs two measured lines plus a warning, breaks nothing that ships (as a warning), and turns `error:undef` at run time into a diagnostic at compile time — the ticket says that "may be the whole feature". But I would not call the ticket answered by C: its argument is the handoff, and C leaves the handoff exactly where it is. If the gating answer is yes, take **A in its smallest form (name only, no version — a version is resolution, which 51 refused)** and settle its spelling together with ticket 50's, as the ticket asks. Do not pick A as an error-severity check without first deciding what happens to the four gated documents in fact 4.

## Not done / limits

- A and B not prototyped; only the presence check was.
- Elm and dependency resolution (hex.pm blocked) unprobed.
- Timings (fact 2) are a shared VM, mean of 20,000 calls, single run.
- The warning severity in C is a recommendation; the prototype is an error.
