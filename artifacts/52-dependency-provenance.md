# Decision brief: ticket 52, what does a `.bs` file say about what it needs

Linear: ENG-234. Repo ticket: `wayfinder/issues/52-dependency-provenance.md`.
Status after this brief: **still open**.

Probes: `artifacts/probes/p52_reproduce.sh`, `p52_neighbours.sh`, `p52_declared.sh`, `p52_check_cost.sh`.
Prototype patches: `patches/52a-presence-warning.patch`, `patches/52b-declared-apps.patch`.
Toolchain: OTP 28, Elixir 1.20.4, Gleam 1.19.1. Elm 0.19.3 is installed but its package registry is unreachable here, so Elm was only observed reading its manifest before any source (it refused my `elm.json` for lacking `elm/json`).

## The gating question

Should the compiler check a `using` module against anything at compile time? Ticket 52's questions (a version or a name, per block or per module, what the compiler does) only arise if the answer is yes. They are asked after it, not with it.

## What I measured

**The claim reproduces.** `p52_reproduce.sh` builds a stand-in application `mydep-1.0.0/ebin/{mydep.beam,mydep.app}` in the layout rebar3 and mix produce, and compiles this module:

```csharp
module Dep
using :mydep { int answer() }
public int Ask()
Ask() -> :mydep.answer()
```

With `ERL_LIBS` pointing at it: prints `42`. Without: the compile is silent, and the run crashes with `error:undef`. Nothing in either output names `mydep` as an application or says what to install.

**What the neighbours do about the same case** (`p52_neighbours.sh`, each one run):

- Erlang: `erlc` compiles a call to a module that is not there without a word (exit 0). `xref` is a separate tool and does find it: `[{{e52,f,0},{mydep,answer,0}}]`, but only on a module compiled with `+debug_info`.
- Elixir 1.20.4: `mix compile` warns, exit 0: `:mydep.answer/0 is undefined (module :mydep is not available or is yet to be defined)`. It gives the same warning for `:xmerl_scan.string/1`, a stock OTP application, because `xmerl` is not in `extra_applications`. So Elixir's check is against the project's application list, not against what happens to be on the path. The message does not name an application.
- Gleam 1.19.1: an `@external(erlang, "mydep", "answer")` to an undeclared module builds clean, exit 0. That is B#'s position today. A Gleam `import gleam/list` with no dependency is refused: `error: Unknown module`. So Gleam checks its own packages and leaves foreign code unchecked.
- Elm: observed above, not probed further.

**Two prototypes** (neither adds source syntax):

- 52a. For each `using :M`, warn if `code:which(M)` is `non_existing`. 16 changed lines across `bs_check.erl` and `bs_diag.erl`. Output: `warning: `using` names mydep, which is not on the code path here`. Run on the 22 modules in `compiler/examples`: 0 warnings, 0 false positives, and compile wall time 1.25 s before, 1.06 s after (noise). Per-`using` cost: `code:which` is 8.7 to 12.6 µs (`p52_check_cost.sh`).
- 52b. As 52a, plus compare the module's owning application (the directory name in `.../req-0.5.0/ebin/Elixir.Req.beam`, minus the version) with a list of declared applications (`BSC_APPS` stands in for the `applications` entry of `.app.src` or `rebar.config`). A module under the OTP lib directory counts as declared. `p52_declared.sh` shows all four cases: path and list agree: silent. Path has it, list lacks it: `warning: ... application `mydep` ... is not in the application list this build declares`. Path lacks it: the 52a warning. Standard OTP modules (`lists`, `erlang`): silent.

A version check would read the `.app` file: 269 µs per `using`. Cheap, but it is resolution, which 51 refused.

## The three programs

**A. Nothing in the source. The compiler warns when a `using` module is not loadable (52a).** The source is exactly what it is today.

```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }
```

On a machine without Req: a compile-time warning naming the module. 16 changed lines of compiler work.
Strongest counterargument: it checks the machine, not the program. The author's machine passes and the clean-room implementor's machine warns, which is the right outcome, but the source still says nothing, so a stranger handed only the `.bs` files cannot tell which application to install. A warning is also not an error, so a conformance suite cannot make a ticket fail on it.

**B. The build's application list is the declaration (52b).** The program is unchanged. The handed-over repository carries its `rebar.config` or `.app.src` (ticket 51 chose rebar3), and `bsc` checks each `using` module's owning application against it. Source unchanged; compiler gains the owner-application function and a list reader (38 changed lines in the prototype, with the list passed in an environment variable standing in for reading the real file).
Strongest counterargument: it makes `bsc` read a build file. Ticket 51 decided `bsc` builds nothing and reads what rebar3 produced. Reading is not building, but this is the first time `bsc` reads a file that is not B#. A `.app.src` also lists applications at start-up, not compile-time dependencies, so a library needed only to compile would still be a separate question.

**C. The source says it, per `using` block.**

```csharp
[external: elixir, app: req] using :'Elixir.Req' { ... }
```

Not prototyped. The compiler work is a parser production, an AST field, and then the same check as 52b with the application read from the block. I did not build it because it needs the grammar decision that 50 and 52 jointly own, and the spec shape matters more than the check.
Strongest counterargument: it is a second place that names the application, next to `rebar.config`. Two declarations drift. With the attribute the file is self-describing, with B it is not.

## Recommendation

A first, then B. A is free of syntax and does what the ticket says may be the whole feature: it turns a run-time `undef` into a diagnostic. B is the step that makes the handoff property true (the repository declares what it needs and the compiler checks it) without a second declaration. C is the only one that adds source syntax; I would leave it until a handoff run shows an implementor stuck for lack of the application name.

## What the independent re-run found

The verifier (`verification/52.md`, `verification/52-extra.sh`) reproduced every case in the brief and found no circularity, then broke prototype B with layouts my probe never used:

- A directory `mydep-1.0.0-rc-1` is parsed as application `mydep-1.0.0-rc`, a false positive even when `BSC_APPS=mydep`.
- A module loaded from a flat directory not named `ebin` crashes `bsc` with a `badmatch` at `bsc.erl:802`, because `owner_app` has no fallback clause.
- A directory named `ebin` under a non-application directory names the parent as the application.
- An application under a path that string-prefixes `code:lib_dir()` (for example `<lib>2/...`) is treated as OTP, so a missing declaration passes silently.

So 52b's owner-application function is a sketch. The idea survives; the way to find an owner does not. Reading `<app>/ebin/<app>.app` next to the beam, rather than parsing a directory name, would avoid the first, third and fourth. Also, the "0 false positives" on the 22 example modules proves little: every foreign `using` there is an OTP module (`erlang`, `ets`, `file`, `lists`), so no non-OTP application was ever tested. Under load the verifier saw `code:which` at 15.6 and 25.5 µs against my 8.7 and 12.6, so read the costs as microseconds, not as exact.

## Limits

- Prototype B reads the list from an environment variable. A real `.app.src` reader is unbuilt and may be harder than it looks (rebar profiles, umbrella apps).
- Req itself could not be fetched (hex.pm is blocked here), so every case used a hand-built stand-in application.
- A warning, not an error, was the choice in both prototypes. Whether the reference compiler as oracle should error is a separate question this brief does not answer.
