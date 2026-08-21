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

**MEASURED 2026-08-21, and candidate 1 is cheaper than it was written.** Not *"one flag"* — **none**.

[`51a`](../prototypes/51a-code-path/Req/req.bs), against Req 0.7.3 and the nine-package tree
`mix deps.get && mix deps.compile` produced:

| | |
|---|---|
| `ERL_LIBS` unset (control) | `crashed: error:undef` |
| `ERL_LIBS=…/elixir/lib` | `'Elixir.String'.upcase("req")` → `"REQ"`; `'Elixir.Enum'.count/1` → `4` |
| `+ …/reqprobe/_build/dev/lib` | `Req.new/1` returns a real `%Req.Request{}` |
| the struct's tag | `:maps.get(:'__struct__', …)` → **`:'Elixir.Req.Request'`** |
| an ordinary field | `:maps.get(:method, …)` → `:get` |
| does it carry `Kind`? | **`:false`** — so no beam-sharp record pattern can ever match it (→ ticket 50) |
| the supervision tree | `Application.ensure_all_started(:req)` → `(:ok, [… :ssl, :mint, :finch, :jason, :req])`, 16 applications |

**`bsc` needed no flag, no change and no tool.** `ERL_LIBS` is honoured by the BEAM code server, an
escript inherits it, and `mix deps.compile` already emits one directory per application with an
`ebin` inside — which is exactly the shape `ERL_LIBS` means. rebar3's `_build` is the same shape.
So "read the directory a neighbour already produced" is not a thing to build; it is a thing that
already works.

**What the measurement does *not* settle, and it is the part worth deciding.**

- **Nothing records which dependencies a program needs.** `ERL_LIBS` is an environment variable, so
  a `.bs` file that calls Req carries no statement of that fact, and the clean-room handoff — the
  destination — cannot reconstruct it. That is what a flag or a manifest would actually buy, and it
  is a *provenance* question, not a package-management one. Candidate 2 exists for this reason
  alone.
- **Elixir is needed at BUILD time, and only as *files* at run time** — the distinction matters and
  was measured rather than assumed (David: *"So beam-sharp would need elixir and erlang installed?"*).

  | | |
  |---|---|
  | Req's `ebin` alone, no Elixir | `crashed: error:undef` — Elixir-compiled modules reach for `Elixir.Kernel` and the protocol machinery |
  | Elixir's `ebin` added | works |
  | Elixir's beams **copied to `/tmp/elxcopy`**, install path not on `ERL_LIBS` | **works identically** |

  So nothing consults an Elixir *installation* — no version manager, no `PATH`, no `elixir`
  executable. `elixir.app` is an ordinary OTP application and `req.app` names it in
  `applications`, so at run time Elixir is a set of `.beam` files you ship exactly like any other
  dependency, which is what an OTP release already does. **The genuine "installed" requirement is
  build-time only**: `mix` is what fetches and compiles the hex packages, and that lands on the
  developer's machine and CI rather than on the deployed artefact.

  **MEASURED 2026-08-21, and the guess above was wrong.** "rebar3 can build them with a plugin, so
  the build-time Elixir requirement disappears" is false in its second half.

  | | |
  |---|---|
  | `rebar3 compile`, Req as a hex dep, no plugin | **fetches all nine packages**, then `Error building application jason: No project builder is configured for type mix` |
  | `+ {plugins, [rebar_mix]}` | **builds the whole tree**, consolidating 14 `Jason.Encoder` implementations |
  | did Elixir run? | **yes** — the build emits *Elixir* compiler warnings while parsing `req/mix.lock`, and `_build` ends up holding an `elixir/ebin` that was never a declared dependency, copied from the local install |
  | `ERL_LIBS=…/rebarreq/_build/default/lib` alone | `Req.new/1` → **`:'Elixir.Req.Request'`** — one path, because rebar_mix vendors `elixir`, `logger` and `mix` into the build tree |
  | `ensure_all_started(:req)` from that one path | **fails**: `(:error, (:eex, "no such file or directory", "eex.app"))` — `eex` is *not* vendored |
  | add Elixir's own lib dir back | `(:ok, [… :eex, :plug, :brotli, :req])`, 23 applications |

  **So rebar_mix drives Elixir rather than replacing it.** The build-time requirement stands, and
  there is no Erlang-only path to consuming an Elixir library — which is unsurprising once stated:
  something has to compile `.ex` source, and only Elixir does.

  **What it does buy is worth having anyway.** The *project* can be a **rebar3** project rather than
  a mix one — no `mix.exs`, dependencies declared in `rebar.config` — which matters because `bsc` is
  itself a rebar3 escript, so a beam-sharp application consuming Elixir libraries stays inside one
  toolchain. And the vendoring means the run-time path is *nearly* one directory; the `eex` gap is a
  packaging bug in the plugin, not a property of the approach.

  Note also that **Erlang/OTP is not a dependency at all** — it is the target. `bsc` emits BEAM and
  is itself an Erlang escript. And none of this applies to a program that calls no Elixir library.
- **A gate would need a dependency tree.** Any exemplar binding Req makes CI fetch and compile nine
  packages, which is the first time this repo's gates would depend on the network.
