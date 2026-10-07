# Brief — ticket 52, dependency provenance (ENG-234)

Status: OPEN - for human review. Not resolved here; ticket file, compiler/ and Linear untouched.
Probes: `artifacts/probes/52/` (one command: `bash artifacts/probes/52/run.sh`, raw output in `*.out`).
Env: OTP 28.5, Elixir 1.18.5, Gleam 1.19.0, Elm 0.19.2, prebuilt `bsc`.

## Ticket and gating question

Nothing in a `.bs` file says which BEAM application a `using :'Elixir.Req' { ... }` block needs, so a
program cannot be handed over on its source alone (ticket 52; 51 decided no tool, `ERL_LIBS` suffices).

**Gating question, asked alone: may the source name the application a foreign module comes from — yes
or no?** If no, nothing else here is owed. If yes, "once per module or per block" and "version or
name" follow from the answer (see the last section) and are not asked now.

**Premise correction, prominent.** The ticket's sketch `[external: elixir, app: req] using :'Elixir.Req' { }`
is not an extension of anything that exists. The attribute spelling is ticket 32's (`[external: erlang, "ets"] module Ets`),
which shipped instead as `using :atom { }` (LANGUAGE.md:2899-2945). The parser has no attribute production
on a declaration (the only `'['` rules are list patterns/expressions, `bs_parser.yrl:544-783`), and
`foreign_decl` is the single rule `'using' atom_lit '{' foreign_sigs '}'` (`bs_parser.yrl:170`). So
"yes" is one new optional clause on that rule, not an attribute added to a construct that has attributes.

## Sub-decisions the ticket implies

1. **Does the source name the application at all?** (gating)
2. Name only, or name plus version. 3. Per `using` block, or once per module.
4. What the compiler does with it: nothing / check presence / record in the artefact.
5. Is the check applied by `bsc --api` and on tests that name invented drivers (`:analytics_db`).

2 and 3 depend on 1. 4 and 5 depend on 1 being yes.

## Evidence

| # | Claim | Probe | Result | Verdict |
|---|---|---|---|---|
| E1 | bsc compiles a program whose Elixir module is missing, with no diagnostic | `probes/52/bsc_missing.out` P1 (`A_missing/Up/up.bs`, ERL_LIBS unset) | compile rc=0; run: `crashed: error:undef` (rc=1). With `ERL_LIBS=<elixir lib>`: `"HI"` | confirmed; the ticket's claim holds |
| E2 | same for a module that exists nowhere (Elixir or Erlang) | `bsc_missing.out` P2, P3 | compile rc=0 both; run `crashed: error:undef` | confirmed |
| E3 | the crash names no module | `bsc_missing.out` | the whole message is `crashed: error:undef` | confirmed; the reader learns nothing about what to install |
| E4 | `ERL_LIBS` layouts of mix and rebar3 both work | `bsc_missing.out` P4, `fixture/` (SYNTHETIC `req` app: hex is unreachable here, so real Req 0.7.3 was NOT re-run; 51 measured that) | `req-0.7.3/ebin` and `req/ebin` layouts both resolve `'Elixir.Req'.new/1` | confirmed for the synthetic app only |
| E5 | the module (not the app) is already machine-readable from the `.beam` | `bsc_missing.out` P5 | ImpT chunk lists `{'Elixir.String',upcase,1}`; bsc builds with `debug_info` (`bsc.erl:843`, Dbgi chunk 322 B) | confirmed |
| E6 | stock `xref` already flags a B# beam's missing module, with no compiler change | `xref_bsc_beam.escript`, `xref_bsc_beam.out` | missing: `[{{'Nope','Go',1},{'Elixir.NoSuchLibrary',frob,1}}]`; `Elixir.String` with Elixir's lib as library: `[]`; without it: flagged | confirmed; **this is a module check that costs zero compiler work**. It needs `+debug_info` (my first run without it returned `[]`) |
| E7 | nothing in the beam or source can say which *app*, and the module name does not give it | `measure.out` [3] | `application:get_application('Elixir.Req')` = `undefined` until the app is loaded; the app is recoverable only from the path (`code:lib_dir`) and `req.app`, i.e. only when the dependency is present | confirmed; **the absent case is exactly the case the source must carry** |
| E8 | a provenance attribute is cheap to carry | `measure.escript` [1] on `Up.abstr` | beam 844 B baseline; `bs_requires=[req]` +44 B; `[{req,"0.7.3"}]` +56 B; 3 apps +64 B; three separate attributes +108 B and read back merged into one list | confirmed (one module, one run; sizes are deterministic) |
| E9 | a presence check is cheap | `measure.out` [2][4] | `code:lib_dir(app)` 1.1-3.6 us/call; `code:which(module)` 35-90 us/call (two runs differed: 37 and 73 us median); combined module-in-app check 61 us; one `compile:forms` of a tiny module 1.5-2.1 ms | confirmed; negligible next to a compile. N=5 batches x 2000, spread shown in the `.out` |
| E10 | an unconditional "module must resolve" check would break existing material | `census_tests.out` (grep over `compiler/test`, `compiler/examples`, LANGUAGE.md; textual, so it over-counts blocks that are never compiled) | 89 foreign blocks, 17 name a module absent from a stock OTP+Elixir path (`analytics_db` 4, `users_db` 3, `trees` 3, `session_store` 3, `epgsql` 1, ...) | confirmed as an upper bound. Only `epgsql` (the 25d exemplar, which does not parse today: "does not parse today" header of `compiler/examples/exemplars/25d-database-querying/index.bs`) and `'Elixir.Req'` (51a prototype) are real third-party libraries; the rest are invented stand-ins |
| E11 | demand today is one prototype | `census.out` | non-OTP real libraries named in `.bs` files: `Elixir.Req` (51a), `epgsql` (non-parsing exemplar), `bs_front` (the compiler's own, F48) | measured; no audition ticket or parsing exemplar needs a dependency yet |

## Neighbour survey

| Language | Where the dependency is recorded | What the compiler checks | Evidence |
|---|---|---|---|
| Gleam | `gleam.toml [dependencies]`; the generated `.app` gets `{applications,[dep]}` from it | an `import` of an undeclared Gleam package is `error: Unknown module`; **`@external(erlang, "Elixir.NoSuchLibrary", "frob")` with no dependency compiles clean** and `applications` stays `[]` | `probes/52/gleam.out` (behavioural; the Gleam compiler source is not installed, only the binary, so no file:line) |
| Elixir | `mix.exs deps:`; `:applications` is derived from it by default | the compiler warns `NoSuchLib.Thing.frob/1 is undefined (module ... is not available or is yet to be defined)` at compile time, for Elixir and Erlang module atoms alike; **no warning that an OTP app (`:crypto`) is missing from `extra_applications`** (1.18.5 did not emit one) | `probes/52/elixir.out`; `elixir/lib/module/types/apply.ex:921-936`; `mix/lib/mix/tasks/compile.app.ex:449` (`apps = Keyword.get(properties, :applications) \|\| deps_loader.()`), `:20-26` (`extra_applications`); suppression `mix/lib/mix/tasks/compile.elixir.ex:174-181` (`xref: exclude`) |
| Erlang | `.app.src` `{applications,[...]}`, read when the app starts | `erlc` says nothing (`compile result: ok`, no warnings); `xref` reports the undefined call after the fact; a missing listed app fails at start: `{error,{ghost_app,{"no such file or directory","ghost_app.app"}}}`; `systools` has `undefined_applications` (read at `systools_make.erl:824-828`, `:2386`; **I did not get it to run**, my script failed on a missing `.rel`) | `probes/52/erlang.out`; `/nix/store/qlcl...erlang-28.5.0.7/.../sasl-4.3.2/src/systools_make.erl` |
| Elm | `elm.json` dependencies | **not measured**: the registry is unreachable from this sandbox (`ProxyConnectException ... 403`, `probes/52/elm.out`); Elm's source is not installed | none; I will not cite memory |

Pattern across the three that ran: each records the dependency in a manifest or `.app` beside the code,
none records it in the module source, and **no neighbour checks an FFI target against the declared
dependencies** (Gleam explicitly does not). So "yes" below would be a first among them, not a borrow.

Repo lines: LANGUAGE.md:2899-2945 (§11, `using` "attaches types to the name Erlang already has"),
ticket 32 §2 (the declaration binds the module, one arity per signature), ticket 106 (an entry may add
`= :'atom'`, so `using` entries already take a suffix), ticket 51 "What is deliberately NOT closed here",
`bs_emit.erl:74-78` (where module attributes are emitted).

## Options

### Option NO. The source names the module only (status quo); the module check is a tool, not a language rule

```csharp
module Fetch

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

public term Make()
Make() -> :'Elixir.Req'.new([])
```

Compiles and fails at run time without Req (E1, E4). Both the status quo and this are accepted; nothing is refused.
- **Compiler delta:** none. For a diagnostic, a CI recipe "compile with `+debug_info`, run xref over the
  output" already works today (E6). Optional later: `bsc` prints the ImpT modules it could not resolve.
- **Measured:** 0 B, 0 us, 0 sites touched.
- **Strongest counterargument:** a stranger holding only the source and an empty machine learns the
  module `Elixir.Req` but not the app, the package, or that a missing one is the cause (E3, E7). The
  ticket's reason for existing ("cannot be handed over") is untouched.

### Option YES-BLOCK. The `using` block may carry the application; the compiler checks it and records it

Spelling is a placeholder (`from :req`), not the question.

```csharp
module Fetch

using :'Elixir.Req' from :req {
    term new(list<(atom, term)> opts)
}

using :maps {                       // no `from`: stock, unchecked, as today
    term get(atom k, term m)
}

public term Make()
Make() -> :'Elixir.Req'.new([])
```

Compiled without `req` on the path: refused at the `using` line, e.g.
`fetch.bs:3: error: application req is not on the code path (needed by 'Elixir.Req')`. Compiled with it: runs as today.

- **Compiler delta (concrete):**
  1. `bs_parser.yrl:170`: optional `'from' atom_lit` after the module atom; the node becomes
     `{foreign, Line, Mod, App, Sigs}`. `{foreign,` appears at 6 sites (`bs_check.erl` x4, parser x2 incl. generated), all
     needing the new field.
  2. `bs_check.erl` near `:622` (the foreign symbol table): when `App` is set, require
     `code:lib_dir(App)` to be a path and `code:which(Mod)` to lie under it (E9: ~60 us); one new diagnostic
     `dependency_not_on_path` in `bs_diag.erl`.
  3. `bs_emit.erl:78`: `{attribute, ?A, bs_requires, Apps}` (E8: +44 B for one app), so `bsc --api` and tooling can list needs.
  4. Tests in the style of `foreign_wrapper_tests`, and a gate that must be seen red first (CLAUDE.md).
- **Measured:** +44 B per module, ~60 us per block against ~2 ms to compile a module (E8, E9).
  Optional use keeps the 72 of 89 blocks that name stock modules, and the 17 invented-driver blocks (E10), unchanged.
- **Strongest counterargument:** it duplicates `rebar.config`/`mix.exs`. Ticket 51 made those the
  place dependencies are declared, so the same fact lives in two files and can drift (a dependency
  removed from the manifest but still declared in source is caught only if the path no longer has it;
  one declared in the manifest and not in source is never caught). It also makes **compile output depend on the
  machine**: the same `.bs` compiles on one box and is refused on another, and a clean-room
  implementer must reproduce an environment-dependent check, not only a pure function of source. And it
  proves presence at *build* time only; whether the release that ships includes the app is not checked (not measured).

## Recommendation

**Answer the gating question "yes", on the `using` block, name only, optional.** Reason: the one
fact the ticket exists for, the app name when the dependency is absent, is exactly the fact no tool can
recover (E7), and neighbours that stay silent leave the same failure (Gleam compiles a bogus `@external`
clean; Erlang's `erlc` is silent). Per-block is the form that lets the compiler check the *pair*
(module belongs to app; E9, row 4 of `measure.out`), which a module-level list cannot, and
repetition costs one token on a block that already exists. Keep it optional so E10's fixtures need no edit.
Version stays refused: a version constraint is the resolution 51 kept out, and `code:lib_dir`
returns `.../req-0.7.3` only in the `ERL_LIBS` layout, not in mix's or rebar3's `_build` layout (E4), so a
check could not even read it uniformly.

If David weighs the environment-dependent compile (counterargument above) heavier than the
handoff, the defensible alternative is Option NO plus an xref step in CI; I have no measurement that
decides between those two, only the costs shown. Decide in the order: yes/no first.

## Follow-up, not asked now

If yes: whether the same fact is written once per module (a `requires :req` header beside `behaviour GenServer`,
`bs_parser.yrl:158-164`) instead of per block. That form drops the module-in-app pairing check and nothing else.
Also owed then: should `bsc --api` run the presence check (it promises "nothing built")?

## What I could not measure

- Real Req 0.7.3: hex is unreachable (`mix local.hex` failed), so E4 uses a synthetic `req` app. 51's numbers stand unrepeated.
- Elm: registry blocked; no result, no claim.
- Whether a mix/rebar3 release omits an OTP app such as `crypto` that the dev shell has: my release probe was invalid (`-pa` is ignored
  in embedded mode; interactive mode still saw `crypto`) and was removed. The argument that a compile-time check does not prove run-time presence is reasoning, not a probe.
- `systools:make_script` behaviour on an undeclared app (script failed on a missing `.rel`); cited from source only.
- Gleam's compiler internals (binary only). Mix's behaviour with real deps (no network); `compile.app.ex:449` was read, not exercised with a dep list.
- Compile-time variance of the new check across machines (one machine, no repeat across hosts); E10 is a textual grep, not an execution of the test suite with the check in place.
- How an agent fleet actually behaves with or without the declaration; no audition run was done.

Status: OPEN - for human review.
