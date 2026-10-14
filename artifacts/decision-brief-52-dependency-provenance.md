# Decision brief — ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

Status of the ticket: **left open.** Evidence: `artifacts/probes/results/52-*.txt`. Limits: `artifacts/README.md`. Tickets 50 and 51 are resolved and were read; this does not reopen 51.

## The one question David decides

Does the *source* name the application behind a foreign module, so that a missing one is a compile-time diagnostic instead of a run-time `undef`?

```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }          // today
using :'Elixir.Req' from req { term new(list<(atom, term)> opts) } // one candidate spelling (illustrative, not in any grammar)
```

## Sub-decisions

1. Name only, or name and version (the ticket says version is resolution and stays refused).
2. Per `using` block or once per module.
3. What `bsc` does with it: check presence, record it in the `.beam`, or both.

## What was measured

- **Today a missing dependency is silent at compile time and an `undef` at run time** (`52-no-diagnostic-today.txt`): `using :'Elixir.NoSuchLib'` compiles with exit 0; running it ends `{'Elixir.NoSuchLib',new,[[]],[]}` `undef`. `erlc` is equally silent on a remote call to an absent module. `elixirc` warns: "NoSuchLib.go/0 is undefined (module NoSuchLib is not available or is yet to be defined)".
- **The application is not derivable from the module name** (`52-app-not-derivable-from-module.txt`, from the installed code path): of 13 modules, 6 would be guessed wrong by "first segment, lowercased": `Elixir.Enum`, `Elixir.Kernel` and `Elixir.Registry` (all app `elixir`), `Elixir.ExUnit.Case` (`ex_unit`), `gen_server` and `lists` (`stdlib`). Among the Elixir modules alone it is 4 of 7; the Erlang rows are a weak example and `ExUnit` differs only by an underscore. So the app name has to be declared or looked up; the module name alone does not say.
- **Checks are cheap if they ask about the app, dear if they ask about the module** (`52-check-cost-and-attribute-size.txt`, OTP 25): `code:lib_dir(App)` **2.7–5.8 µs**; `code:which(Module)` **0.5–1.3 ms** per call (a code-path scan), roughly 100–500 times more at this code-path size; `which` grows with the path (verifier: 630 to 970 µs going from 32 to 38 entries) while `lib_dir` stays flat. `code:lib_dir(req)` returns `{error,bad_name}` when absent.
- **Carrying it in the artifact is nearly free:** a custom `-requires([req])` attribute (my invention for the probe, not an existing OTP attribute) adds **44 bytes** to a 588-byte module; three apps add 76.
- **Erlang's own convention records dependencies outside the module:** the installed `crypto.app` has `applications = [kernel,stdlib]`, `elixir.app` has `[kernel,stdlib,compiler]`. Ticket 51 already puts a beam-sharp program's Elixir dependencies in `rebar.config` (via `rebar_mix`), so one record exists; the question is whether the source must agree with it.

## Neighbours (executed)

Elixir warns on a call to an absent module at compile time (above); Erlang does not. Gleam and Elm are **not installed**; I made no claim about them.

## Options

### A. Name the application on the foreign declaration, check it, and record it in the `.beam`
Compiler delta: one attribute on `foreign_decl` in the grammar, a `code:lib_dir/1` check in the foreign-import step (about 5 µs), a `requires` attribute emitted (+44 bytes for one app).
**Strongest counterargument:** a second record of what `rebar.config` already says, with nothing checking they agree. And the check is weaker than it looks (verifier probes): an app directory can be present while a module it should hold is absent (`lib_dir` says present, the call is still `undef`); a working Elixir module on the path via `-pa` with no app directory makes `lib_dir` return `{error,bad_name}`, so A would reject a working program; `lib_dir(elixir)` is `{error,bad_name}` on a stock `erl` until the Elixir ebin dirs are added, so A depends on the build machine's path just as B does. A is sound only for apps laid out as `<name>[-vsn]/ebin`, which is what ticket 51's `ERL_LIBS` and rebar layout give. Per-`using` repetition is also the cost the ticket flags.

### B. No syntax: check the module is on the code path at compile time
Zero language surface; the `undef` would become a diagnostic naming the module (what it should say about `ERL_LIBS` is untested). Cost 0.5–1.3 ms per distinct foreign module per compile (about 5–13 ms for ten, extrapolated, not run).
**Strongest counterargument:** it does nothing for the stated reason for the ticket: the source still does not say what to fetch, and the clean-room handoff reader cannot tell. The check also only works where the dependency is installed, which is exactly the machine that does not need telling.

### C. Say nothing in source; rely on `rebar.config`
It is what 51 decided, and 51 closes the language side. **Strongest counterargument:** the handoff spec has to point at `rebar.config` for what a `.bs` file needs, so the language's source is not self-describing, which is the ticket's premise.

## Recommendation

**A, in its smallest form:** application name only, checked with `code:lib_dir/1`, recorded as `-requires`, spelling and granularity (per `using` block vs once per module) left to David, since sub-decision 2 is still open. The measurements say the check is cheap and the name cannot be inferred. B's module check is two orders of magnitude dearer; whether to offer it as an option is open. If David prefers to keep 51 absolute, C is consistent and the handoff spec should say so in words.
