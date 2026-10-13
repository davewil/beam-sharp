# Decision brief — ticket 60 (ENG-242): which modules may name this one?

**Status: OPEN. Nothing is resolved.** Prepared autonomously 2026-10-13. The ticket says "not owed a
decision soon"; this brief prices the choice so that it can be taken cheaply when it is owed, and
says what would make it owed. Probes: [`probes/60/`](probes/60/). The verifier section at the end
records which a second agent re-ran.

## The one question

**Who writes the rule: the callee's *path*, or a list in the callee?** The ticket's four questions
(unit, direction, marker-or-construct, checker cost) collapse once that is answered: the unit is
"a module", the direction is "the callee declares", and the checker cost is measured below. The
ticket's other direction — the *caller* declaring what it depends on — is already `using`, and
cannot restrict who else names a module, so it is not a competitor; it is the half that exists.

## What is there today

`using` is the only gate. Baseline fixtures (`probes/60/fixture-R1`, `run.sh`):

| importer | spelling | HEAD |
|---|---|---|
| `Shop.Billing` | `using Shop.Internal.Cost` | compiles |
| `Other` | `using Shop.Internal.Cost` | compiles |
| `Other2` | `using Shop.Internal` (namespace) | compiles |
| `Other3` | calls `Shop.Internal.Cost.Cost(n)` with no `using` | refused — "called but never imported" |

Two consequences the ticket did not have. **A qualified call is already gated by `using`**, so a
rule enforced at `using` covers both spellings; and **there are two sites, not one**: `add_import`
(`bs_check.erl:498`) for a module, and `add_namespace_import` for a namespace, whose `children/2`
would otherwise hand every `Internal` module to anyone who writes `using Shop`. The ticket cites
`add_module_import/5` at `bs_check.erl:407-425`; the function is now `add_module_import/3` at
`bs_check.erl:512` and the import loop is `import_env/4` at `bs_check.erl:489`.

## Options, built and run

Both variants compile and give the same verdicts on the same fixtures.

| importer | R1 `Internal` in the path | R2 callee says `friend Shop` |
|---|---|---|
| `Shop.Billing` (under `Shop`) | compiles | compiles |
| `Other`, `using Shop.Internal.Cost` | **refused** | **refused** |
| `Other2`, `using Shop.Internal` | **refused** | **refused** |
| `Other3`, no `using` | refused (as before) | refused (as before) |

| cost | R1 | R2 |
|---|---|---|
| diff, non-generated source | **1 file, +17 −2** | 4 files (lexer, parser, `bsc.erl` world entry, `bs_check.erl`), +19 −4 |
| grammar | none | one token, one nonterminal; `yecc` still reports 6 shift/reduce, 0 reduce/reduce — unchanged |
| new reserved word | none | `friend`; 0 uses as an identifier in any `.bs` in the repo (the only hit is the fixture) |
| a new consumer outside `Shop` | edit its own file | edit **the callee**'s file |
| expresses "Billing and Reports but not Pricing" | no — the visible set is the parent subtree | yes |

Both reuse `unknown_module` for the refusal, and **its text is wrong for this case**: "`using
Shop.Internal.Cost` names no module and no namespace — a module is a source file this invocation
can reach". The module exists and was reached; it is merely not nameable from here. That is the
shape of ticket 57's diagnostic (a message that sends the reader back to what they wrote). A real
implementation needs its own tag: `bs_diag.erl` carries `unknown_module` in two clauses
(`built/2` at line 660, `message/1` at line 2073) and a new tag needs the same two.

## Neighbours

| | what it does | evidence |
|---|---|---|
| Gleam 1.19.0 | `internal_modules = ["lib/internal", …]` in `gleam.toml` | package `app` imports `lib/internal/secret` from package `lib`: `gleam build` printed `Compiled in 0.45s`, **no error and no warning** (`neighbours/`). It marks, it does not enforce, at least in this build |
| Elixir 1.18.5 | `@moduledoc false` / `@doc false` | `Lib.Internal.secret()` called from an unrelated module returned `42`; hides from docs, enforces nothing (`neighbours/ex.exs`) |
| Erlang | none beyond `-export` | — |
| Go | an `internal/` path segment limits importers to the parent subtree | **not run** — no Go toolchain is installed here. This is the model R1 copies, stated from memory and unverified |

The only neighbour that enforces is the one I could not run. What I could run says that the two
BEAM neighbours chose documentation over enforcement; R1 and R2 would both make B# the exception.

## Options

### R1 — a path segment named `Internal` limits importers to its parent's subtree

```csharp
// Shop/Internal/Cost/Cost.bs
module Shop.Internal.Cost
public int Cost(int n)

// Shop/Billing/Billing.bs   — compiles
using Shop.Internal.Cost
// Other/Other.bs            — refused: Shop.Internal.Cost is not nameable from Other
using Shop.Internal.Cost
```

Compiler delta: `visible_to(M, Self)` (about a dozen lines), called at `add_import` and filtered into
`add_namespace_import`'s children. Directory is module (F15), so the rule needs no grammar and no
declaration; moving a file out of the subtree already renames its module.

**Strongest counterargument.** A policy lives in a *spelling* — rename a directory and visibility
changes, with no diff in the file that was affected. The ticket's own warning is about borrowing a
word without its semantics; here the word is `Internal`, spelled as data, and a C# author will read
it as the `internal` keyword, whose scope is an assembly. It also cannot say "these two siblings
and no third".

### R2 — the callee lists who may name it

```csharp
module Shop.Internal.Cost
friend Shop.Billing
friend Shop.Reports
public int Cost(int n)
```

Compiler delta: lexer token, parser rule, a `friends` field on the world entry, the same check
at the same two sites.

**Strongest counterargument.** Adding a consumer means editing the callee, in another file. 18 §4
chose function-local analysis so that an agent's `write_scope` is one file; a visibility rule that
requires editing the *other* file when a caller appears is the blast radius that rule removed. It
also spends a reserved word on a feature with no demonstrated user.

### 0 — decide nothing yet

`private` and the directory layout already answer "what". The ticket's stated consumer — ticket
24 §2's `unclassified` helper, `RecomputeTotal/1` — is a *function* in a module, and neither R1
nor R2 touches it: both are module-to-module rules. I did not find, in the tickets or the
`examples/` corpus, a second consumer that a module-level rule serves (`Internal` appears in no
example). Both prototypes together are 40 + 92 diff lines and neither is far from a rebase, so
deferring costs only the open question.

## Recommendation

**Stay at 0 until a second consumer exists**, and when one does take **R1**, because it adds no
syntax and so cannot be wrong in a way that needs a migration: any program valid under R1 stays
valid if R2 is added later (an `Internal` module simply gets an implicit `friend` for its parent).
Take R2 first only if the requirement is already "a named set that is not a subtree".

What would make it owed: a test or an agent loop that must be kept off a helper *module* and cannot
be kept off by `private`. Ticket 24 §2's problem is a function-level one; if that is the real
consumer, this ticket is the wrong ticket for it.

## Reproduce

```
export BSC=<path to a bsc built from HEAD>
FX=artifacts/probes/60/fixture-R1 artifacts/probes/60/run.sh     # baseline: all compile but Other3
# variants: artifacts/probes/60/variant-vR1.diff, variant-vR2.diff
#   apply to a COPY of compiler/ with src/bs_parser.erl and src/bs_lexer.erl deleted first
BSC=<R1 build> FX=artifacts/probes/60/fixture-R1 artifacts/probes/60/run.sh
BSC=<R2 build> FX=artifacts/probes/60/fixture-R2 artifacts/probes/60/run.sh
# neighbours: cd artifacts/probes/60/neighbours/app && gleam build ; elixir neighbours/ex.exs
```

## Verifier result

(filled in below by the independent re-run)
