# Decision brief — ticket 62 (ENG-252): the outbound ABI — function-name casing

**Status: OPEN. Nothing is resolved.** Prepared autonomously 2026-10-13. Probes:
[`probes/62/`](probes/62/). The verifier section at the end records which a second agent re-ran.

## The one question

**Does an Elixir caller of a B# module need a snake_case name to exist, or only a way to spell the
PascalCase one?** The ticket treats the casing as the whole remaining decision and offers three
answers, one of which ("Elixir callers use `apply/3`") is the baseline. The baseline is wrong, and
that changes the price of the other two.

## The correction that comes first

Ticket 62 §1 and `LANGUAGE.md` §12 (line 3274 onward) both say the way
into a PascalCase export from Elixir is `apply(:Shop, :New, [1])`. **It is not the only way.**
Elixir accepts a quoted function name after a remote dot (`probes/62/run.sh`, P1, executed against
the real `Shop` beam):

| spelling | result |
|---|---|
| `:Shop.New(1)` | `SyntaxError` |
| `:Shop."New"(1)` | **runs**, returns `%{Kind: :"Shop.Order", Total: 0, Id: 1}` |
| `:"Shop"."New"(1)` | runs |
| `(&:Shop."New"/1).(1)` | runs — a capture works |
| `mod = :Shop; mod."New"(1)` | runs |
| `apply(:Shop, :New, [1])` | runs |
| `:Shop.new(1)` | `UndefinedFunctionError` (no such export) |

So the cost to an Elixir caller is **two quote marks**, not a loss of call syntax. The ticket's
Candidate 1 ("accept it: `apply/3`") understates how livable acceptance is, and §12 of
`LANGUAGE.md` should say so whatever is decided; I have not edited it because that is a doc change
on a ticket I was told to leave open.

## What the Gleam precedent actually is

Ticket 62 cites ticket 10 §7: "Gleam downcases when it emits to the BEAM — PascalCase becomes
snake_case", as precedent for aliases. Executed (`probes/62`, P2, Gleam 1.19.0):

- Gleam's **function** names are never PascalCase: `pub fn Make() -> Int { 1 }` is a `Syntax error`.
  There is nothing to downcase.
- What Gleam snake-cases is **constructor tags**: `MyCircle(3)` is `{my_circle,3}`; `HTTPServer` is
  the atom `h_t_t_p_server`.

So the precedent is for data, and its rule is the naive one that mangles acronyms. Any alias scheme
must pick an acronym-aware rule (`Macro.underscore`, `elixir/lib/elixir/lib/macro.ex:2194`, gives
`http_server`, `parse_url`, `from_json`) and cannot copy Gleam's.

## Evidence for the two ways to fix it

**P3 — the derived name, over the corpus** (`derive.exs`; it reported 128 public functions / 100 names, but the verifier found 7 exemplar directories that are not modules inflated that — the true corpus is **100 functions, 84 distinct names**):
**0 collisions** and 0 odd segments under either rule. That is weaker than it sounds: the corpus
has no acronym-bearing names. `ParseURL` and `ParseUrl` both become `parse_url` under
`Macro.underscore`, so a real implementation needs a compile-time collision error; `Sha256Hash` and
`Sha256hash` stay distinct (`sha256_hash`, `sha256hash`).

**P4 — aliases inside the module** (`alias_cost.escript`; the `.abstr` forms plus one forwarding
wrapper per export, recompiled; the Elixir call `:Shop.new(7)` then runs):

| | |
|---|---|
| exports | 8 |
| bytes, recompiled from forms | 1252 → 1528 (**+276, 34.5 B per alias, +22%**) |
| bytes with `debug_info`, as the real build compiles | **+404 B, about +16%** (verifier-measured); with specs on the aliases **+496 B, about +20%**. My first figure (+10.6%) was arithmetic on file sizes, not a measurement, and the aliases in the probe carry no specs |
| `ExpT` (export table) chunk | 136 → 232 B |
| Erlang callers | unchanged: `'Shop':'New'(1)` still works |

**P5 — a generated facade** (`facade.escript`): a second module `'Elixir.Shop'` of snake_case
forwarders to `'Shop':'New'` etc.

| | |
|---|---|
| bytes | **832 B for 8 functions**; the B# module is untouched |
| what Elixir writes | `Shop.new(7)` — plain, no colon, no quotes — returned the record; `Shop.total(4)` → `5` |

The facade also fixes the *module* spelling (`Shop` rather than `:Shop`), which no alias inside the
module can.

## Options

### 1 — accept it and document the quoted call (nothing built)

```elixir
:Shop."New"(1)          # the supported spelling; mix format keeps the quotes
```

Compiler delta: none. Doc delta: correct `LANGUAGE.md` §12 to show the quoted form beside `apply/3`.

**Strongest counterargument.** It is a tax on exactly the audience the ticket worries about — the
Elixir codebase trying B# *incrementally* — and every call site wears it. Quote marks on every call
read as a signal that the callee is foreign, which is the impression an adoption path wants to avoid.
`Code.format_string!/1` keeps the quotes (verifier-tested); `mix format` itself was not run.

### 2 — emit a snake_case alias beside each export

```csharp
public Order New(int id)      // exports 'New'/1 and new/1
```

Compiler delta: a derive function (the five lines in `alias_cost.escript`), one forwarding clause
and one export per function, and a **collision diagnostic** for two distinct names mapping to one
alias, plus a rule for a name that already exists in snake_case (a B# function is PascalCase by
convention but I did not find a rule that forbids `new`; check before building).

**Strongest counterargument.** It doubles every export forever, in the export table and in every
tool that lists it (`--api`, docs, Dialyzer, `module_info`), to fix a spelling problem that two
quote marks also fix. +34.5 B each is small; the second name in the ABI is the cost that does not
shrink. It also makes the *alias* part of the published contract, so changing the derivation rule
later (say, for digits) is a breaking change.

### 3 — a generated Elixir-facing facade, off by default

```
bsc --elixir-facade Shop      # writes Elixir.Shop.beam beside Shop.beam
```

```elixir
Shop.new(7)                   # no colon, no quotes
```

Compiler delta: a second emitter target reading the same export list `--api` already reads; the
facade is forwarders only (832 B for the 8-function `Shop`) (built here without specs).
The B# module is unchanged, so Erlang callers and the clean-room spec's ABI are untouched.

**Strongest counterargument.** `Elixir.Shop` is in the *caller's* atom namespace. An application
that already has its own `Shop` module collides, and nothing in the build knows to warn; the
collision is not always silent: Elixir warns "redefining module" when it compiles its own `Shop` after the facade is loaded, and is silent only when the facade loads second (verifier-tested). It is also a second artifact to version, ship
and keep in step with the first, which is exactly the kind of apparatus the repo has been cutting.

## Recommendation

**Option 1 now, and keep Option 3 as the named upgrade.** The correction removes the case for
changing the ABI in order to rescue syntax; what remains is ergonomics, and ergonomics is better
served by a facade that is opt-in and removable (Option 3) than by a second name in every export
table, which can never be taken back (Option 2). If David decides adoption friction is already the
priority, Option 3 is the one to build, with a collision check against loaded modules as its first
test.

Two small things that follow regardless of the choice:

1. `LANGUAGE.md` §12 should show `:Shop."New"(1)`.
2. The ticket's "Gleam downcases" line should say *constructor tags*.

## Not measured

- Gleam *calling* a B# function: `@external(erlang, "Shop", "New")` compiled **and ran**
  (`probes/62/gl`) — the ticket said "compiles; the call was not run". It returned the record.
- Elm: not run; `package.elm-lang.org` is unreachable from this sandbox.
- Whether `mix format` or `credo` keep or strip the quotes in `:Shop."New"`.

## Reproduce

```
export BSC=compiler/_build/default/bin/bsc
artifacts/probes/62/run.sh          # P1 spellings, P2 Gleam, P3 derive, P4 alias bytes, P5 facade
```

## Verifier result

(filled in below by the independent re-run)
