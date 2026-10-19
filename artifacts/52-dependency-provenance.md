# Brief — ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

Status of the ticket: **open, left open.** Tickets 50 and 51 (the sequencing note and "do not re-open") are both resolved.

## Sub-decisions
1. Does the source record the dependency at all, or does the compiler derive it?
2. If recorded: a name only, or a version too? (the ticket says a version is resolution and stays refused)
3. Per `using` block or once per module?
4. What does the compiler do with it: check presence at compile time, record it in the `.beam`, both, neither?

## Measurements and probes

**Corpus: how many `using` blocks name a dependency that is not OTP or Elixir's standard library?**
38 `using` declarations in 22 files, 30 of which name a foreign module (the other 8 are B#-to-B# imports) (`probes/52/corpus_using.sh`).
Foreign modules named: `erlang` 13, `maps` 4, `gen_server` 2, `string`, `lists`, `json`, `file`, `ets`, `binary` (all OTP),
`Elixir.String`, `Elixir.Enum`, `Elixir.Application` (Elixir's stdlib), and **`epgsql` and `Elixir.Req`: 2 of 30**.

**The module name does map to an application, when the module is present** (`probes/52/module_to_app.escript`, OTP 25 +
Elixir 1.14.0): `maps`/`string`/`lists`/`ets`/`binary`/`gen_server` -> `stdlib 4.3.1.3`; `file` -> `kernel 8.5.4.2`;
`Elixir.String`/`Enum`/`Application` -> `elixir 1.14.0`; `erlang` -> preloaded (erts, no `.app`). **When the module is
absent it maps to nothing**: `Elixir.Req`, `epgsql` and `json` (OTP 25 lacks `json`, which arrived in OTP 27) all print
"absent from the code path". That is exactly the case the ticket worries about.

**What each neighbour says when the dependency is missing** (`probes/52/probe.sh`):
| | compile | run |
|---|---|---|
| `erlc` | rc=0, **no warning** | `error:undef` |
| `xref` (needs `+debug_info`) | reports `{caller,go,0} -> {'Elixir.Req',get,1}` as an undefined call | n/a |
| `elixirc` | rc=0, **warning**: `Req.get!/1 is undefined (module Req is not available or is yet to be defined)` | n/a |
| `elixirc` with `@compile {:no_warn_undefined, Req}` | rc=0, silent | n/a |
| Gleam 1.12.0, `@external(erlang, "Elixir.Req", "get")` | rc=0, **no warning** (it declares no application) | n/a |
| Elm | **not measured**: its package host is unreachable here | |

So the two nearest languages split: Elixir warns and offers an opt-out; Erlang and Gleam are silent. Gleam keeps its
dependencies in `gleam.toml`, away from the `@external`.

**Cost of the check** (`probes/52/probe.sh`, OTP 25): `code:lib_dir(missing_app)` = `{error, bad_name}` in ~2 µs;
on OTP 25, `code:which(missing_module)` takes ~450-1350 µs (it scans the code path; varies with path length), on OTP 28 ~8 µs;
`code:lib_dir(missing_app)` takes ~2 µs on both. For a module that is present, `code:which` (~5 µs) and `code:lib_dir` (~5 µs) cost
the same. **Speed does not separate the options**; a ~200x gap appears on OTP 25 only, from its scan for a missing module.

**Cost of recording it in the `.beam`** (`probes/52/attr_cost.sh`): a `-bsharp_requires` attribute adds **40 B** for one
dependency and **68-76 B** for three depending on OTP (592 -> 632 B on OTP 25, 580 -> 620 B on OTP 28 for one).

## Options

**A. Nothing in the source; the compiler derives and records.** `bsc` resolves each `using` module with `code:which` and
writes the application names into the `.beam` attribute.
- Evidence: derivation yields an application for 10 of 14 modules in the table above (`erlang` is preloaded and has no application; `json`, `Elixir.Req`, `epgsql` are absent on OTP 25).
- Strongest counterargument: it fails on precisely the case the ticket exists for. A machine whose `ERL_LIBS` lacks `req`
  cannot map `Elixir.Req` to anything, so the compile either refuses without a useful name or succeeds silently. Source
  that "records nothing" is also what the ticket calls un-handoff-able.

**B. A name-only application on the `using` declaration.** For example
`using :'Elixir.Req' app req { ... }` (the spelling is not decided here; the ticket's `[external: elixir, app: req]` is one candidate).
The compiler checks `code:lib_dir(req)` and a missing application becomes a diagnostic instead of `error:undef`.
- Evidence: the check costs ~2 µs (no cheaper than checking the module on OTP 28); 2 of 30 foreign `using` blocks would need it if OTP and Elixir's own application are
  implicit (`Elixir.Req` appears only in the 51a prototype, `epgsql` only in exemplar 25d: two samples, one synthetic); recording costs 40 B.
- Strongest counterargument: the rule "implicit for OTP and Elixir, explicit otherwise" needs a list of which applications
  are implicit, and `json` shows that list is OTP-version-dependent (absent on OTP 25, present on 27+). A name does not
  record that the program needs OTP 27. Written naively it also repeats the name on every block that draws on one application.

**C. One declaration per module, not per `using`.** The module header lists the applications it needs.
- Evidence: corpus modules have 1-2 `using` blocks each (38 blocks, 22 files), so repeating a name per block costs little
  today.
- Strongest counterargument: it is a *new construct* (a header line), where B reuses the one place the source already names
  a foreign thing. It also separates the application from the call it justifies, so removing a `using` leaves a dead requirement.

## Recommendation
**B, name-only, checked at compile time and written into the `.beam`; version stays refused.** The check turns the
only observed failure (`error:undef`) into a diagnostic, which is also what Elixir does by default, and it is the smallest
extension of the construct tickets 32 and 50 already use. Settle first the one thing the probes cannot: whether OTP-version
requirements (`json` = OTP 27+) belong in this ticket or a separate one.

## Not measured
Elm. Whether `rebar3`/`mix` already put the application list where `bsc` could read it instead of `code:lib_dir` (ticket 51's
territory). The verifier re-ran the timing on OTP 28 (reported above).
