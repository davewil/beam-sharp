# Decision brief — ticket 60 (ENG-242): which modules may name this one?

**The decision stays open.** This is a brief for David, not a resolution. Nothing in the tracker or
the ticket file was changed.

Toolchain, stated once: **OTP 25.3, Elixir 1.14.0, rebar3 from apt.** The repo pins OTP 28.5, and the
real `bsc` cannot be built here (`bs_lexer.xrl` needs OTP 27's `leex` option). Every number below is
OTP 25 on one noisy cloud VM. Gleam's compiler is not installed, and `repo.hex.pm` and
`package.elm-lang.org` returned 403 on the proxy tunnel; I did not work around either. So Gleam and Elm
appear below as **UNVERIFIED background knowledge**, not as evidence.

Vocabulary: **MEASURED here** means a probe in `probes/` ran and its output is saved beside it.
**RECORDED, not re-executed** means read from a source file; it cites file:line.

## 1. The question, in B# terms

`public`/`private` (F12) says what a module offers. Nothing says who may name it. Today this program
compiles, and the ticket asks whether it should:

```csharp
// Other/Peek.bs
module Other
using Shop.Pricing.Rounding        // Rounding is `public`, so anyone may name it
public int Peek(int c) -> Round(c)
```

Where it lives: `add_module_import/3` at `bs_check.erl:509` reads only the callee's export set.
RECORDED, not re-executed (`bs_check.erl:509-520`). The ticket cites an older line range.

Two facts from reading the source change the shape of the problem:

- **`using` is the only way to name another module.** `qualified_module/3` refuses a module with no
  `using` entry (`module_not_imported`, `bs_check.erl:4557-4572`). One checkpoint therefore covers
  qualified calls too. RECORDED, not re-executed end to end.
- **`using` has two branches, not one.** `add_import/7` (`bs_check.erl:497-507`) sends a module path to
  `add_module_import` and a namespace path (`using Shop`) to `add_namespace_import`. A check at the
  module branch alone leaks. See probe p7 below.

The consumer the ticket names is `RecomputeTotal/1`, "neither client API nor callback". Since F12, an
unmarked signature is private, so that function is not callable from outside its module. The real
remaining case is narrower: a `public` helper that sibling modules in one subtree need and the rest of the
world should not name (for example `Shop.Pricing.Rounding`, used by `Shop.Pricing` and `Shop.Billing`).
I grepped `wayfinder/prototypes`, `wayfinder/research`, `compiler/examples/exemplars` and
`wayfinder/issues` for 11 phrasings of "who may call/name" and "only X may call", and found no
friction entry asking for it. A grep with no hits is weak evidence, but it is all the evidence
there is.

## 2. The sub-decisions, gating one first

Per CLAUDE.md, ask the gating question alone and let the rest follow.

1. **Gate: is there a program that must be refused today and is not?** If no, nothing is built and
   questions 2-4 do not arise. That is the question to answer first.
2. **Direction.** The callee names its audience, or the caller declares its dependencies.
3. **Unit** (only if 2 is answered): a dotted-name subtree, or an explicit list.
4. **Marker vs construct, and checker cost** follow from 2 and 3. Their measurements are in §4.

I did not build a matrix of 2 x 3 x 4. The options below differ on 1 and 2 only.

## 3. Options

### Option 1 — nothing new now: `private` plus module-is-a-directory is the mechanism

```csharp
// Shop/Pricing/Rounding.bs    one module, one directory, nothing about who may call it
module Shop.Pricing
private int Round(int cents)    // unreachable outside Shop.Pricing today (F12)
```

A helper two modules need goes in one directory (one module), because F15 makes a directory a module.
A reader who wants to see cross-subtree edges asks `--api` or an xref-style query after the fact (p1).

- **Compiler delta:** none. Optionally a report that prints cross-subtree `using` edges. That is
  reading `imported` (already built by `import_env`, `bs_check.erl:491`), not a new check.
- **Evidence (MEASURED here).**
  - **p1:** Erlang has only `-export`, so `other_thing` linked against `shop_orders_internal` with no
    complaint. xref reported the edge `{other_thing, shop_orders_internal}`, and a 3-line prefix filter
    separated 1 violation from 1 allowed caller. `-ignore_xref` did not hide the edge (it
    silences xref's own warnings).
  - **p2:** Elixir's `@moduledoc false` is documentation-only: `Module.ParallelChecker` and
    `Kernel.Utils` both report `:hidden` and `Kernel.Utils` was called from an unrelated script with no error.
- **Strongest counterargument:** the case F15 does not cover is a *public* function that must be shared
  across two sibling directories. Under option 1 the only fix is to merge the directories or leave
  the function world-visible, and that is where an agent author will drift. I have no measurement of that
  drift. It is a prediction from the ticket's own argument, not evidence.

### Option 2 — the callee names its audience; the unit is a dotted-name subtree

```csharp
// Shop/Pricing/Rounding/index.bs
module Shop.Pricing.Rounding visible_to Shop.Pricing, Shop.Billing   // spelling is a LATER question
public int Round(int cents)
Round(c) -> c / 10 * 10
```

Default stays "anyone", so no existing program changes. `Shop.Pricing` in the list means itself plus
every module whose name starts `Shop.Pricing.`. The unit is a dotted-name prefix, and not a
filesystem path, because the checker already treats a namespace that way: `children/2`
(`bs_check.erl:587-589`) is `lists:prefix(P ++ ".", atom_to_list(M))`.

- **Compiler delta, as concrete work:**
  1. a parser clause on the `module` header, and a `visible_to` entry in the World entry (`exports_of`
     and `--api` carry it);
  2. a check in `add_import` before `add_module_import` (`not_visible_to`, carrying `Self`, the callee
     and the line);
  3. **a filter in `add_namespace_import`**, so `using Shop` does not hand an outsider a restricted
     child (p7 shows this is required);
  4. one diagnostic text in `bs_diag`; `--api` prints the list.
- **Evidence (MEASURED here, on a patched scratch copy of the real `bs_check.erl`, not the shipped `bsc`).**
  - **p5:** unpatched copy accepts insider and outsider (control). Patched: insider accepted, outsider
    refused with `{not_visible_to,'Shop.Orders','Other.X',1}`.
  - **p7:** with the check at the module branch only, an outsider's `using Shop` still reaches
    `Shop.Orders` (`imported` = `['Shop.Orders','Shop.Reports']`, the leak). With children filtered the
    outsider gets only `Shop.Reports` and the insider still gets both.
  - **p6:** the check alone costs about **0.5 µs** (506 ns at N=100, 481 ns at N=10 000 modules, 2 prefixes,
    compiled loop; empty-loop baseline 2.4 ns). It does not grow with the number of modules.
  - **p5:** one whole `import_env` costs about **16 µs per import at N=100 and 2.7 ms at N=10 000**,
    because it rebuilds `qual_table`, `poly_table` and `private_table` over the whole World on every
    call. The check is a few percent of an import at N=100 and negligible beyond. The
    base-versus-patched differences in p5 (+29%, -13%, +12%) are run-to-run noise and I do not
    read them as signal.
  - **p3:** Elixir's compiler tracer (`Code.put_compiler_option(:tracers, ...)`) rejected the outsider
    (`Elixir.Other.Peek may not name Shop.Orders.Internal`), accepted the in-subtree caller, and the
    same outsider compiled when no tracer was set. Added compile time was inside noise (N=100: 2.26 s
    vs 2.21 s; N=1000: 22.2 s vs 22.6 s, median of 3). That shows a caller-side subtree check is cheap
    in a real compiler; it says nothing about B#'s own cost beyond p6.
- **Strongest counterargument:** it adds a clause to the module header, and the sixteenth-keyword
  budget is the thing ticket 22 closed to avoid spending (RECORDED, not re-executed:
  `wayfinder/issues/22-how-opinionated.md`, "the sixteenth keyword is not spent"). The word could be
  a contextual clause rather than a keyword, but that is a lexer question I did not test. A second
  weakness: a prefix match makes a rename of `Shop.Pricing` a silent narrowing of every list that
  mentions it.

### Option 3 — the caller declares what it may use

```csharp
// Other/index.bs
module Other may_use Shop.Reports, Shop.Pricing     // anything else under `using` is refused
using Shop.Reports
```

- **Compiler delta:** the same `add_import` site and the same namespace filter as option 2, with the
  list carried by the importing module instead of the imported one.
- **Evidence (MEASURED here):** p5 H3: `Other.X` with `may_use [Shop.Reports]` imported `Shop.Reports`
  and was refused on `Shop.Orders` (`not_in_may_use`). Cost is the same prefix-match shape as p6.
  I did not re-measure it separately; p6 times the callee-side function only.
- **Strongest counterargument:** it answers "what may I use", not "who may name me". A module that
  wants protection does not get it unless every would-be caller opts in, and the module that wants to
  cross the boundary is the one holding the pen. It is closer to what `using` already does, as the ticket
  says, but it does not serve the consumer the ticket names.

## 4. Neighbouring languages

| language | what it does | status |
|---|---|---|
| Erlang | `-export` only; no caller-side control; xref answers it after the fact | MEASURED (p1) |
| Elixir | `@moduledoc false` hides from docs, not from callers; tracer API makes a caller-side rule cheap | MEASURED (p2, p3) |
| Gleam | `internal_modules` in `gleam.toml` and an `@internal` attribute restrict a package's own modules to that package | UNVERIFIED — compiler absent, hex fetch denied |
| Elm | `exposed-modules` in a package's `elm.json` bounds what other packages import | UNVERIFIED — `package.elm-lang.org` denied (p4 inconclusive) |
| C# | `internal` = assembly-scoped; B# has no assembly | RECORDED, not re-executed (ticket 60 note); not borrowed |

Gleam and Elm are the closest peers, and both bound visibility at a **package** boundary, which B# does
not have (ticket 51: no dependency tool). That is background knowledge and should not be cited
without a source.

The installed Elixir is `ebin` only (no `.ex` source), so there are no Elixir file:line citations;
the artifacts cited are `Code.fetch_docs` results from the installed `.beam` files.

## 5. Recommendation

Answer the gate first: **no program is refused today that needs to be, and I found no friction asking for
it.** My recommendation is **option 1 (build nothing now)**, and revisit when an exemplar needs a
`public` helper shared across two sibling directories. If you want it built anyway, **option 2**, with
the namespace filter as part of the first cut. p7 is the reason that part cannot follow later.
Option 3 does not answer the question as asked.

This is a judgement on thin demand evidence. If David has a case that I could not find in the repo,
it overrides it.

## 6. Not verified / limits

- The real `bsc` was never run. Options 2 and 3 were modelled on a patched copy of `bs_check.erl`
  compiled with `+export_all` on OTP 25. The checker was exercised through `import_env/4` with
  hand-built Worlds, not through parsed `.bs` source, so parser work, `--api` and diagnostic text are
  all untested.
- That qualified calls go only through `using` is read from source, not run end to end.
- p6's 0.5 µs includes an `atom_to_list` and a prefix scan per entry; I did not try to optimise it.
- Cost at N=10 000 uses synthetic padding modules, not a real corpus.
- Gleam, Elm and C# rows in §4 are not evidence.
- Every number is one run on a shared VM; I did not control CPU frequency or neighbours.

## 7. Probe index (all in `probes/`, each with its `.out`)

| probe | what it tests | notes |
|---|---|---|
| `p1_erlang_xref.sh` | export gives no caller control; xref can catch it | run 1 saw no edges (compiled without `debug_info`): `p1_run1_no_debug_info.out`. Setup fault, not a result |
| `p2_elixir_hidden_module.exs` | `@moduledoc false` is docs-only | I rewrote this file twice in one command before running it; only the final version ran |
| `p3_elixir_tracer.exs` | tracer rejects outsider, accepts insider; overhead | |
| `p4_elm_exposed.sh` | Elm sibling import inside one project | **inconclusive**: run 1 `p4_run1_missing_elm_json_dep.out` (my `elm.json` lacked `elm/json`), run 2 hit the 403 |
| `p5_checker_site.sh` | direction A and B at the real import site | run 1 `p5_run1_my_bug_atom_prefix.out` (my bug: atoms where strings were needed) and run 2 `p5_run2_format_string_crash.out` (my `~.0f` format) were probe bugs |
| `p6_check_alone.sh` | cost of the check alone | run 1 `p6_run1_interpreted_loop.out` showed 5.8 µs from an interpreted `erl -eval` loop; replaced by a compiled loop |
| `p7_namespace_leak.sh` | module-branch-only check leaks via `using Shop` | |

Each probe states its hypothesis at the top and has an observation that can fail. No probe was changed
to produce a preferred result; every fix above repaired a defect in the probe's own code and kept
the failed run's output. A verifier should re-run p1, p3, p5, p6 and p7 and read each
fix against that rule.
