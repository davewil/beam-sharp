# ENG-234 / ticket 52 — Dependency provenance: what does a `.bs` file say about what it needs?

Decision brief. **Nothing here resolves the ticket.** Probes: `artifacts/probes/ENG-234/` (`run-all.sh` re-runs all; each `*.out` is the captured run).
Host: OTP 25, Elixir 1.14, Elm 0.19.1. Gleam not installed. `bsc` not built here (it targets OTP 28 per `.tool-versions`) — **every `bsc` claim below is cited from the repo and was not re-executed.**

## Sub-decisions the ticket implies

1. Does the declaration name the application only, or also a version?
2. Per `using :'…' {}` block, per module, or not declared at all (derived)?
3. What does the compiler do with it?
4. Spelling.
5. Interaction with ticket 50 (the ticket says sequence them).

Ticket 50 is now **resolved** (`50-naming-a-foreign-struct.md`: "no new surface"; a foreign struct is a `map<atom, term>`), so the "two sessions extend the same construct" risk is gone; this ticket is the construct's only pending extension. Sub-decision 5 needs no answer; it needs the owner to know that.

## Measured facts everything below rests on

| claim | probe | result |
|---|---|---|
| Erlang caller of an absent app compiles clean and fails only when called | `a_missing_app.out` | `erlc` exit 0; run → `error:undef` |
| `xref` finds it **only if the beam has debug_info** | `a_missing_app.out` vs `a2_xref_dialyzer.out` | without `+debug_info`: `[]`. With: `[{{caller,go,0},{req,new,1}}]` |
| dialyzer finds it (needs a PLT; ~29–32 s to build a tiny one, timed twice by hand and not captured in any `.out`) | `a2_xref_dialyzer.out` | `Unknown functions: req:new/1 (caller.erl:3:9)` under `-Wunknown` |
| An absent app listed in an `.app` is caught at **boot**, not compile | `b_app_boot.out` | `{error,{req_absent,{"no such file or directory","req_absent.app"}}}`; with the app on `ERL_LIBS`: `{ok,[req_absent,me]}` |
| Elixir: undeclared + not on path → **warning**, build succeeds | `c_mix_undeclared.out` case 1 | `warning: Depa.hello/0 is undefined (module Depa is not available or is yet to be defined)`; exit 0 |
| Elixir: on path but undeclared → **warning naming the fix**, build succeeds | case 2 | `Depa.hello/0 defined in application :depa is used by the current application but the current application does not depend on :depa. To fix this …` ; exit 0 |
| Elixir: declared → silent | case 3 | no warning |
| Is the application on the code path? costs microseconds | `e_cost.out` | `code:lib_dir(app)` hit 5.2 µs, miss 2.4 µs (n=10000, 39 path entries). `code:where_is_file("x.app")` miss **1.13 ms** — use `lib_dir` |
| A custom attribute survives into the `.beam` and `module_info` | `f_beam_attr.out` | `[{app,[req]},{external,[{elixir,req}]},…]` via both `erlc` source and hand-built abstract forms |
| The repo already has both repeat patterns | `g_using_census.out` | `51a/Req/req.bs`: `Elixir.Req` (app `req`) and `Elixir.Application` (app `elixir`) in one module; `51a/Elx/elx.bs`: `Elixir.String` and `Elixir.Enum`, **both app `elixir`**, two blocks |
| Elm requires `elm/core` and `elm/json` in `elm.json` whatever the module imports (**the verifier showed the probe cannot establish an import-vs-manifest ordering**: the case and its no-import control print the same error) | `d_elm_undeclared.out`, `d2_…` | only "MISSING DEPENDENCY … elm/core / elm/json" reported; **the undeclared-import case itself was not measured** — `d3` hit `package.elm-lang.org` → `403 Forbidden` from the sandbox proxy. Not worked around |

Cited, not re-run: `bsc.erl:843` compiles with `[from_abstr, debug_info, …]`, so bsc's own beams carry debug_info and the `xref` row would apply to them. Parser: `bs_parser.yrl:170-171` `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' : {foreign, Line, Mod, Sigs}`. Five sites match `{foreign,…}`: `bs_check.erl:620, 638, 1076, 1114` and the parser. `bs_parser.yrl` has **no attribute syntax** (`[…]` before a declaration is not a rule), so the ticket's `[external: elixir, app: req]` is a new construct, not a reuse.

## 1 + 2. What is declared, and where

Same hypothetical four-block module (not a repo file; `req.bs` has 3 blocks and `elx.bs` has 2), three answers.

```csharp
// (A) name only, per using block
using :'Elixir.Req' from req { term new(list<(atom, term)> opts) }
using :'Elixir.Application' from elixir { (atom, list<atom>) ensure_all_started(atom a) }
using :'Elixir.String' from elixir { binary upcase(binary s) }
using :'Elixir.Enum'   from elixir { int count(list<term> l) }      // `elixir` written twice
```

```csharp
// (B) once per module
needs req, elixir
using :'Elixir.Req' { … }   using :'Elixir.Application' { … }
using :'Elixir.String' { … }   using :'Elixir.Enum' { … }
```
Under (B) nothing ties `Elixir.Req` to `req`: the compiler cannot say *which* block is wrong, and a `needs` entry no block uses cannot be refused without a module→app map, which is (A)'s information anyway.

```csharp
// (C) nothing written; the compiler derives the app from the code path
using :'Elixir.Req' { … }
```
The compiler resolves module→app on its own machine and records it in the beam. It compiles on the author's machine and says nothing in the **source**. The ticket's argument is that the source must carry it for the handoff; (C) fails that argument by construction. Version, in all three: a version constraint is resolution, which 51 refused; `from req "~> 0.7"` would need a parser for requirement strings and a comparison with `.app`'s `vsn`. Measured cost of the name-only check is 5 µs; the version check has no measurement because nothing here defines the grammar.

**Strongest counterargument to (A):** the `elixir` repeat is real (census, `g_using_census.out`: both `using` blocks in `elx.bs` repeat `elixir`; `req.bs` has 3 blocks, 2 of them Elixir — and its `:maps` OTP block shows (A) has an unanswered case: does an OTP module need a `from` clause?) and the reader pays it every time. Against (B): it is the same information minus the link, so the repeat is saved by losing the diagnostic.

## 3. What the compiler does

Under (A), four concrete pieces of work:
1. `bs_parser.yrl:170`: `foreign_decl -> 'using' atom_lit 'from' lident '{' foreign_sigs '}'`; AST gains a field → update the four `bs_check.erl` matches.
2. `bs_check`: one `code:lib_dir(App)` per distinct app per compile (5 µs); `{error,bad_name}` → a named diagnostic in the project's voice, not erlc's.
3. `bs_emit.erl` around line 73-78 (where `behaviour` attributes are emitted): one `{attribute, ?A, bs_needs, [App,…]}`. Probe f shows it lands in the `.beam`.
4. Tests: a gate `.bs` with `from nonesuch` red, and the same with `from stdlib` green.

Check severity, same program:
```csharp
using :'Elixir.Req' from req { … }     // `req` not on the path
```
- **error:** compile stops. Neighbour precedent for the opposite: Mix only *warns* (probes c1/c2, exit 0); nothing else here refuses.
- **warning:** compiles, `error:undef` at run time remains possible, as in Erlang today (probe a).
- **no check, attribute only:** the beam records the need; a release tool can read it. Nothing is reported to the author.

**Strongest counterargument to the error:** a build machine that compiles without the dependency present (compile in one stage, ship `.abstr`/`.beam` to another with the libs) would be refused for a correct program. Mix chose warning, plausibly for the same reason. Whether a staged build exists is **not measured** — no such workflow is in the repo. (An earlier draft claimed `bsc` already resolves `ERL_LIBS` at compile time; the verifier found no such code in `compiler/src`, so the claim is withdrawn.)

## 4. Spelling

(A)'s `from req` after the atom would be a reserved word, not a contextual one: yecc has no contextual keywords, so `'from'` joins the Terminals list and the lexer; `from` is not a B# keyword today (`bs_parser.yrl:28`, the keyword list — **I did not grep every use of `from` as an identifier**, so a collision is unchecked). The alternative `[external: elixir, app: req]` needs the attribute grammar the parser lacks; carrying `elixir` as a language tag is information the module atom's `Elixir.` prefix already carries.

## Recommendation

(A), name only, per block, **error** on a missing application, plus the `bs_needs` attribute. Reasons: only per-block ties an app to the module it serves, so the compiler can say which line to fix; name-only keeps resolution out (51); the compiler delta is the four items above, plus the tree-sitter grammar (`editor/tree-sitter-beam-sharp/grammar.js`, `queries/highlights.scm`), LANGUAGE.md, the spec and tests; the 5 µs is only the `code:lib_dir/1` call on a present application (`e_cost.out`), not the whole check. Take the severity as David's call: error is my pick, warning is the Mix-shaped answer, and the staged-build case above is the only argument for it, unmeasured.

## Evidence limits

- No `bsc` was built or run (OTP 25 host; the compiler needs 28). All of `bsc`'s behaviour is cited from source.
- Gleam: **not surveyed.** No Gleam binary or source is present, and downloading and running a release binary was denied by the sandbox; I did not work around it.
- Elm: undeclared-import error text not captured (registry 403). Only the pre-import `elm.json` check was observed.
- Mix probes used a local path dependency, not Req from Hex (no Hex access tested), so they show Mix's mechanism, not Req's.
- Elixir's source (`.ex`) is not installed (dfsg package, `ebin` only). The warning text was confirmed from a run and its presence in `Elixir.Mix.Compilers.ApplicationTracer.beam` by `grep -l`; there is no file:line to cite.
- OTP 25 vs the project's 28: `code:lib_dir/1`, `xref`, `beam_lib` behaviours measured here are old, stable APIs but not re-run on 28.
- An independent verifier re-ran every probe: all reproduce (`e_cost` timings are noise: ~5 µs hit, ~1–2 ms `where_is_file` miss); no hand-edited output; `g_using_census` needs the repo checkout. Corrections it forced are applied above (Elm row, block counts, `from` as a reserved word, withdrawn `ERL_LIBS` claim, delta scope).
- Probe `c` is labelled `-pa` but uses `ERL_LIBS`, so "on path" means "on ERL_LIBS". `code:lib_dir(elixir)` returns `bad_name` unless Elixir's lib is on the path, so `from elixir` needs ERL_LIBS like the module itself. Probe `f` tests `app`/`external` attributes, not `bs_needs` itself (mechanism only). The census excludes OTP modules and the `:json`/`:epgsql` uses in exemplars 25d/25f, so (A)'s cost on an Erlang dependency is unmeasured.
