# 51 — Does beam-sharp need a build tool, or does it ride on rebar3 and mix?

Type: grilling
Status: open — [ENG-233](https://linear.app/davewil/issue/ENG-233)

Raised 2026-08-21 by David, alongside [ticket 50](50-naming-a-foreign-struct.md): *"I want to look
at something like the mix tool from Elixir that manages deps, should probably consider needing a
tool like that."*

## This ticket sits against a stated boundary, and says so up front

`scope.md`'s **Tooling and ecosystem** boundary names, in its own words, *"package manager, build
tool, hex/rebar3/mix integration"* and concludes *"a package manager is not"* in scope. It is not
being quietly reinterpreted here.

Two things make raising it legitimate rather than a reversal:

- **The boundary's own clarification** (David, 2026-08-13, via ticket 23) says it *"rules out the
  ecosystem **track**, not any capability that happens to serve tooling — tooling is not out of
  scope if there's a genuine need"*, and gives the test: **"is this the multi-year track, or one
  capability the language owes its author"**.
- **The need is now measured rather than asserted.** [`50a`](../prototypes/50a-elixir-ffi/Elx/elx.bs)
  compiles a call to `'Elixir.String'.upcase/1` and it runs to `crashed: error:undef`. Nothing puts
  a dependency's `ebin` on the code path, and `bsc` has no flag that could. **Today beam-sharp can
  call no BEAM library that is not already in OTP.** That is not an ecosystem ambition; it is a
  capability the language owes its author, and it is the exact wording the boundary admits.

**But the question is not "build a mix".** Stated that way it is the multi-year track and the
boundary refuses it correctly. Stated honestly it is the opposite:

## The question

**Does beam-sharp build a tool of its own, or does it consume what rebar3 and mix already produce?**

A BEAM dependency, once fetched and compiled by *either* neighbour, is a directory of `.beam` files
and an `.app` file. Both tools already solve fetching, version resolution, locking and compilation,
and both already know how to build the other's packages. The cheapest defensible answer is therefore
that beam-sharp **builds none of it** and `bsc` learns one flag — where the compiled dependencies
are — leaving `mix.exs` or `rebar.config` to declare them.

If that is the answer, it is a decision worth **one line and no track**, and it closes ticket 50's
second row permanently.

## Candidates

1. **No tool. `bsc --lib PATH…`** (or an env var), pointed at an existing `_build`. Dependencies are
   declared in a neighbour's manifest. Cost: beam-sharp has no manifest of its own, so a project is
   a mix or rebar3 project that happens to contain `.bs` files. Honest, and it makes the first
   binding a day's work rather than a track.
2. **A manifest, no resolver.** beam-sharp declares its dependencies in its own file and *shells out*
   to rebar3 or mix to fetch and build them. Buys a native-looking project layout; costs a format
   nobody else reads, and it is a resolver-shaped hole that will want filling.
3. **A tool of its own.** The thing the boundary refuses. Gleam is the cited evidence for the
   multi-year claim — and note it is evidence in *both* directions, since Gleam did build one and
   also consumes hex directly.

## What must be decided before the exemplar

Ticket 50 asks how a foreign aggregate is **named**; this asks how it is **reachable**. The Req
exemplar David asked for needs both, and this is the cheaper of the two — candidate 1 may need no
language change at all, only a flag and a code-path append.

## Notes

**Do not let this become the ecosystem track by accident.** The scope test is the guard: any answer
here that requires beam-sharp to resolve versions, lock, fetch over the network, or publish is the
track, and belongs back behind the boundary. Reading a directory somebody else built is not.

**Measure before choosing.** Whether `bsc` can simply append to the code path and call an Elixir
module — including whether `Application.ensure_all_started/1` is needed for a library like Req that
runs a supervision tree — is a half-hour experiment and nothing here should be decided without it.
