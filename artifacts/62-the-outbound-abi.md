# Decision brief — ticket 62 (ENG-252): the outbound ABI

Prepared 2026-10-01 by a scheduled run. **Nothing is resolved.** Every probe is a script under
`artifacts/probes/62/` with its captured output beside it. Toolchain: Erlang/OTP 27.3.4 (built from
source) for `bsc`, OTP 25 + Elixir 1.14.0 from apt for the Elixir probes, Gleam 1.18.1 binary.
Elm 0.19.1 is installed but cannot run a project here (needs `elm/core` from package.elm-lang.org,
which the sandbox cannot reach), so **no Elm claim in this brief is measured**.

## Headline: the ticket's central claim is wrong

The ticket (§1) says *"Elixir cannot call a PascalCase export, and no module prefix fixes it"*, and
`LANGUAGE.md` §12 (lines ~3115-3126) repeats it: it says the PascalCase name *"costs Elixir its call syntax"* and, on a separate line of its code block, shows `apply(:Shop, :New, [1])` as *"the way in"*; it never mentions the quoted spelling.
**Elixir can call it, with the function name quoted:**

```
:Shop.New(1)                  -> SyntaxError (unexpected ( after alias New)   <- the ticket's measurement, true
:Shop."New"(1)                -> %{Id: 1, Kind: :"Shop.Order", Total: 0}      <- works
1 |> :Shop."New"()            -> works
import :Shop, only: [new: 1] -> works (for a lowercase name)
defdelegate new_order(id), to: :Shop, as: :New   -> works
```

(`p1_elixir_call_syntax.sh`, and re-measured on a beam `bsc` itself emitted in `p4_real_bsc_beam.sh`:
`:Shop59."SumAll"([])` returns `0`.) The friction is a **quoting tax**, not a missing way in. That
changes what the three candidates are worth.

## Sub-decisions the ticket implies

1. Is the PascalCase export an interop defect at all, now that a quoted call works?
2. If an alias is emitted, what derives its name, and can it collide?
3. Does the answer change what the spec owes a clean-room implementer?

## Claims checked

| claim | probe | result |
|---|---|---|
| Elixir cannot call a PascalCase function | `p1`, `p4` | **False.** Only the *unquoted* form fails. |
| Erlang unaffected | `p1` | True (`'Shop':'New'(1)` is ordinary). |
| Gleam unaffected, `@external(erlang,"Shop","New")` compiles | `p2` | True, and **now run**: `shop:foreign_new(3)` returns the map. The ticket measured only the compile. |
| "Gleam downcases when it emits — PascalCase becomes snake_case" (ticket 10 §7, cited as precedent for candidate 2) | `p2` | **Misleading.** Gleam *refuses* a PascalCase function or module name in source (`warning: Invalid module name`, and functions must be snake_case). Only **type constructors** are lowercased in the term (`Order(7,0)` is the tuple `{order,7,0}`). Gleam never exports a PascalCase function, so it is **no precedent for emitting two exports**. |
| A B# record reaches Elixir as a plain map, not a struct | `p4` | True. An Elixir struct with identical fields gives `FunctionClauseError`; a map with the right `Kind` returns `5`. |
| The module atom needs no prefix | `p1`, `p4` | Consistent: `module 'Shop59'`, no prefix; the `:Shop."New"` form works with no prefix. |
| (new) A derived snake_case alias could collide with a user's own export | `p6`, verifier | Mostly cannot: a lowercase function name is a syntax error everywhere in B#. **But** distinct PascalCase names can derive the same alias (`Get` and `GET` both give `get`; `GetX` and `Get_x` both give `get_x`), and a public `ModuleInfo` would derive `module_info/0`, which collides with the compiler-generated export ("already defined"). Behaviour callbacks such as `HandleCall` and `Init` already export snake_case names. |

## Neighbour survey

- **Erlang** quotes any atom: `'Shop':'New'(1)`.
- **Elixir** reads `.Capitalized(` as an alias, but accepts `Mod."Name"(args)` (measured, Elixir 1.14).
  Its sources are not installed here (only `ebin/`), so I cite behaviour, not file and line.
- **Gleam** (binary only, no source): functions snake_case by rule; constructors become snake_case
  atoms (`p2`: `{order,7,0}`); `@external` takes the foreign name as a string.
- Naming scheme is the **module** atom's business and is already settled in the ticket (no prefix).

## Measurements (candidate 2: alias exports)

`p3_alias_cost.sh`: N PascalCase functions of one two-clause shape; bytes of the `.beam`.

| N | base | + forwarding alias | + duplicated body |
|---|---|---|---|
| 10 | 2512 | 3172 (**+26%**) | 4232 (+68%) |
| 50 | 9084 | 12388 (+36%) | 17768 (+96%) |
| 200 | 34696 | 47956 (**+38%**) | 69760 (+101%) |

About 66 bytes per aliased function. A verifier's forms-level prototype on real `bsc` output (not an `bs_emit.erl` change) measured **+21% to +40%**; its own hand-written generator gave +28/+39/+39%. Call time: indistinguishable (`Fun1` 37.3–39.6 ns, alias
37.5–38.9 ns, 5 samples each, 20M calls; samples overlap). Name derivation: Elixir's own
`Macro.underscore` over all **158** distinct function names the corpus declares gives **0
collisions** (`p5`; the verifier found the extraction regex misses signatures whose type contains `:` or `|`, so the corpus has 163 names, not 158, still 0 collisions among them), but acronym and digit runs are ambiguous: `IPv4Addr` becomes `i_pv4_addr`,
`OAuth` becomes `o_auth`, `HTTPGet` becomes `http_get`; Gleam's own constructor rule gives `HTTPGet` -> `h_t_t_p_get`, so the two neighbours disagree. Any alias needs a written rule, and that rule
becomes ABI.

## Options

**A. Accept it; document the quoted call.** B# emits nothing new.

```elixir
Shop = :Shop
Shop."New"(1)          # the idiom; LANGUAGE.md §12 currently teaches apply/3 instead
```
Compiler delta: none. Doc delta: correct §12 (it says Elixir has no call syntax for it) and the
ticket. *Strongest counterargument:* it is still a syntax tax at every call site, and a quoted name
survives neither `import` (no `:Shop.New` shorthand) nor autocompletion; incremental adoption inside
an Elixir codebase is the likeliest way anyone tries B#.

**B. Emit snake_case aliases for public functions.**
```
Shop.beam exports: 'New'/1, new/1, 'Total'/1, total/1 ...      # :Shop.new(1) parses in Elixir
```
Compiler delta: in `bs_emit.erl` where exports are built, one extra export and a one-line forwarding
clause per public function, plus a derivation rule in the spec. Cost: **+26% to +38% beam bytes**
for the forwarding form, no call-time cost, no collision with user names. *Strongest
counterargument:* it publishes a second name for every function **permanently** (an ABI promise),
the derivation rule for acronyms is a design decision of its own (`OAuth`), and its only precedent
(Gleam) is not one.

**C. Change B#'s convention to snake_case.** Not measured: the ticket itself calls it the largest
blast radius and it contradicts the C#-family premise. Listed for completeness only.

## Recommendation

**A now, B later and only on demand.** A fixes the actual error (the ticket and `LANGUAGE.md` tell
Elixir callers something false) at zero compiler cost. B's cost is real but small, so it is
reasonable to add *if* a user reports the quoting tax; deciding it now would put an acronym rule into
the ABI on no evidence that anyone wants it.

## Caveats

- Elixir is 1.14 (apt); newer Elixir may differ, but quoted remote calls are long-standing syntax.
- `bsc` was built under OTP 27, not the repo's OTP 28 baseline (compiler README lists 24–28 for the
  emitted `.abstr`; the *compiler's own build* needed ≥ 26 for the `error_location` xrl option).
- The alias prototype is **hand-written Erlang** (`p3`), not an emitter change; it measures bytes and
  calls, not that `bs_emit` can produce it.

## Verification

An independent verifier (full report: `artifacts/probes/62/verify/REPORT.md`) re-ran p1, p4, p5 and p6
(all match their captured output) and re-probed Gleam and the alias cost itself; it found no circular
probe and the six corrections above are applied. It confirmed the quoted call also works through
`alias`, a variable module, a pipeline, the `&:M."F"/1` capture and `defdelegate`, survives
`mix format`, and that `import :Shop` cannot expose PascalCase names at all. p2 and p3 were not re-run
verbatim by the verifier (p3 was regenerated independently).
