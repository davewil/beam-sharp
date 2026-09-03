# 67 — Stdlib shape as a principle: what is in the standard environment versus a module you import

Type: grilling
Status: claimed — [ENG-281](https://linear.app/davewil/issue/ENG-281), 2026-09-03 by `/frontier`

Raised 2026-08-31 by the §19-as-queue rule. The history — two strata modelled on
`Kernel.SpecialForms`, the reopening on opaque refinements, ticket 27 moving the collection library,
the 2026-08-25 survey and David's two-axes model — is the fog body at
[`fog.md` § Stdlib shape as a principle](../fog.md) and is not repeated here. The census is
[`PRELUDE.md`](../../PRELUDE.md). Everything below was measured at `f310425` on 2026-09-03 against
a built `bsc`, not read off a summary.

## Question

**Is `List` a module the compiler ships, or an operation set the compiler knows — and what follows
for the standard environment's shape, its closedness, and the one function anyone has proposed
putting in it?**

The issue's title asks *"Erlang-ish flat modules, C#-ish namespaced statics, or Gleam-ish"*. Measured
(§6 below), B# already sits where none of the three sit, and every part of that placement is a
prior decision. What is open is narrower than the title, and the spec states it itself (§3).

## Premises measured

### 1. What ships is four types and no function

`bs_check:prelude/0` merges `stratum_one()` — `option<T>`, `result<T, E>`, `foreign_error` — with
`stratum_two()` — `ValidationError`. `builtin/1` has clauses for `int atom term bool binary string`.
`codegen_obligations()` names `ValidateAs`, `ParseAtom`, `ToExistingAtom`; only the first is built.

Nothing callable ships unqualified, and **the grammar has no call form for a lowercase name**.
`bs_parser.yrl:626-667` accepts exactly `Uident(...)`, `Uident<T>(...)`, `:atom.lident(...)` and
`Path.Uident(...)`. So `raise(:x)` is a syntax error today, not an unbuilt function — which bears on
round 1 Q3.

`PRELUDE.md` says `/` and `%` *"are decided and unbuilt. Neither is a token."* Both are terminals now
(`bs_parser.yrl:27`) and `check-division.sh` gates them. Stale, listed under chores.

### 2. What the corpus asks for

Every `.bs` file outside `handoff/` and outside `.claude/worktrees/` — the first sweep counted two
stale worktrees and tripled every number; the table is the corrected one.

| spelling | count | where |
|---|---|---|
| `:erlang.integer_to_binary` | 5 | 25a, 25e |
| `List.Sum` | 4 | `Shop/Reports/Totals.bs`, `LANGUAGE.md` §5 |
| `:maps.get` | 4 | 25c, 25d — standing in for `Map.Get`, decided by 48 and unbuilt |
| `:erlang.rem` | 4 | written before `%` landed; it has |
| `Binary.Append` | 2 | 25b — no module behind it; a target, per the exemplar README |
| `List.Fold`, `List.Length` | 1 each | 25b (target), `Totals.bs` |
| `:lists.sum`, `:lists.reverse` | 1 each | `Interop/interop.bs` — **the FFI is the collection library today** |

**One collection module exists, and a user wrote it.**
[`compiler/examples/Shop/Collections/List/List.bs`](../../compiler/examples/Shop/Collections/List/List.bs)
is F11's own example: `module Shop.Collections.List`, `Sum(list<int>, int)` and `Length(list<int>)`,
monomorphic, reached as `List.Length([n, n])` after `using Shop.Collections` and as
`Shop.Collections.List.Sum([n], 0)` in full. That is the lived shape: a PascalCase qualifier that is
the last path segment, resolved through the module table, **called**, not inlined.

### 3. `LANGUAGE.md` answers the question both ways

- `LANGUAGE.md:1384`, the dot-form table: `List.Map(x)` | **a B# module** | qualified call.
- `LANGUAGE.md:1178`, the pipe section: *"the collection prelude … `List.Map` and friends as
  **compiler-known functions** … The compiler inlines its own collection operations."*

Both are decided text, both cite tickets (41 §5 and 17 §2), and they describe two different
compilers. That contradiction is this ticket's question, and the spec states it.

### 4. Decided, and not reopenable here

- **Qualified, never method syntax.** `List.Sum(xs)`, not `xs.Sum()` — 17 §2, `LANGUAGE.md:1101`.
- **No function values.** `xs |> Sum` is a syntax error (`LANGUAGE.md:1098`); the lambda
  `(acc, c) => …` is 27 §(c), unbuilt. So `List.Map(f)` cannot be *called* with anything today; only
  an inlined form has a way to take `f` at all.
- **`Map.Get` is qualified under a reserved `Map`** — 48 Q9, 2026-08-25 — compiler-known, and
  `Map` is the first reserved name. The policy for the rest is [ticket 65](65-reserved-names-policy.md).
- **The compiler-known prelude is inlined, user code is called, precision follows the inlining** —
  17 §2, measured at 27a.
- **A codegen obligation takes a ground type argument** (27 §8), and the set is fixed at lex time (28).
- **Two axes, not two buckets** (David, 2026-08-25): *standard environment* — ships out of the box —
  crossed with *unqualified* — reachable with no prefix. "prelude" is retired in `CONTEXT.md`.
  `LANGUAGE.md` still says it 8 times and `PRELUDE.md` is still so named: chores, at the end.

### 5. Three falsified criteria, and the one the compiler has been using

`PRELUDE.md` § What is not decided, item 1, records three candidates for what separates stratum 1
from stratum 2, each falsified by a member: *could a user have written it* fails on `string`;
*requires a ground type argument* fails on `foreign_error`; *what the compiler draws inferences
from* is not a definition.

The compiler applies a fourth, and has since F1. `stratum_one()` is a map of **declarations in the
language's own alias shape** — its comment: *"spelled in the language's own alias mechanism rather
than as a special case in `resolve/2`"*. Stratum 2 is everything shipped **as a rule in the
compiler**: a `builtin/1` clause, a `codegen_obligations()` entry, a `compiler_known_redeclared/1`
refusal, a lowering. Against the three falsifiers: `string` is a `builtin/1` clause → stratum 2;
`foreign_error` is an alias-shaped declaration → stratum 1, **which is where the code stores it**
(`PRELUDE.md`'s table puts it in stratum 2 and is the drift); a user's opaque refinement is a *user*
declaration → not in the standard environment at all, and "compiler-generated" was never the test.
Round 1 Q2 puts it to David.

### 6. Where the three named shapes sit, and where B# already is

| | a list op is reached as | unqualified names | who owns the names |
|---|---|---|---|
| Erlang | `lists:map(F, Xs)` — qualified, no import | BIFs (`hd`, `length`) and guards | a flat global namespace, first come |
| C# | `xs.Select(f)` after `using System.Linq` — type-directed extension method | `predefined_type` keywords | `System.*`, unreserved by rule |
| Gleam | `list.map(xs, f)` after `import gleam/list` | types and constructors, **zero functions** | a package path |
| **B# today** | `List.Sum(xs)` — qualified, PascalCase segment; method syntax refused | four types, zero functions | `Map` reserved; nothing else |

Gleam-shaped in what is unqualified, Erlang-shaped in how a call reads, and the C# shape refused
outright. Every cell in the last row is a closed ticket, so *"which of three"* is answered; §3 is
what is left.

## Round 1 — put 2026-09-03

Each question is B# code plus what the compiler must gain. Q1 is the root; Q2–Q4 do not depend on
it or on each other.

---

❓ **Q1 — Is `List` a module the compiler ships, or an operation set the compiler knows?**

```csharp
module Shop.Reports.Totals

public int Total(list<int> xs)
Total(xs) -> xs |> List.Sum()                       // no `using`, as `Map.Get` needs none (48)

public list<int> Twice(list<int> xs)
Twice(xs) -> xs |> List.Reverse() |> List.Reverse()
```

**Build (a) — a shipped module.** `List.bs` lives in a source root the compiler owns and sits in
the module table beside `Shop.Collections.List`. Each site is **called**: the emitted form is
`'List':'Reverse'(Xs)`, so a `List.beam` must ship and be on the path — a runtime library with
`ERL_LIBS`, versioning, and 51's rebar3 neighbourhood. `Reverse<T>` and `Length<T>` are polymorphic
signatures — F6 §(c), ENG-295, unbuilt, and its ordering is the open half of ticket 37. The callee's
declared spec widens both sides of the emitted type (17 §2, 27a). Either `using List` is required or
`List` is special-cased into scope, which is (b) wearing (a)'s clothes.

**Build (b) — compiler-known.** A table beside `codegen_obligations()`: `{'List', 'Sum'}` → a
lowering. Each site is emitted **inline** with its own ground element type — a comprehension or a
local recursive fun — so no beam ships, no polymorphism machinery is needed, and no `using` is
written. `List` becomes the second reserved qualifier after `Map`. This is the rule 48 chose for
`Map.Get` and the sentence 17 §2 wrote. The user's `Shop.Collections.List` then short-qualifies to
the same word — that collision is round 2.

➡️ **(b).** Two closed tickets already chose it; nothing it needs is unbuilt; the set is closed by
construction, so ticket 65's *"is it closed by intent"* is answered for free and Elixir's
`defmodule Map` crash cannot occur. The cost, stated: `LANGUAGE.md:1384`'s "a B# module" row is
wrong and becomes "a reserved qualifier"; and a user cannot add `List.Foo` — they write
`Shop.Collections.List.Foo`, which is called rather than inlined, which is 17 §2's two tiers said
plainly.

---

❓ **Q2 — Is the stratum criterion "declared in the language" versus "a rule in the compiler"?**

```erlang
stratum_one() -> #{option => {parametric, ['T'], ...},     % an alias a `type` line could spell
                   result => ..., foreign_error => ...}.
builtin(string) -> bs_types:string().                      % a rule; no `type` line can spell it
codegen_obligations() -> ['ValidateAs', 'ParseAtom', 'ToExistingAtom'].
```

That is §5's fourth criterion, and it is what the checker does today. **Compiler delta: none.**
Doc delta: `PRELUDE.md`'s `foreign_error` row moves to stratum 1 (where `bs_check` has it), the
criterion sentence replaces item 1 of *What is not decided*, and `CONTEXT.md` gains the two terms —
it has no entry for "stratum" at all today. Proposed names: **declared entry** and
**compiler-known entry**, the second already in use.

➡️ **Yes**, and adopt those two names. Under Q1(b) the collection operations are compiler-known
entries, which is consistent with 17 §2 and retires 27's *"a user could have written it"* as a
criterion (it was an observation about *capability*, not about *how the thing ships*).

---

❓ **Q3 — Is `raise` grammar or a function?**

```csharp
Withdraw(acct, n) -> raise :insufficient      // 12 §5's own example, issues/12:180 — no parentheses
Withdraw(acct, n) -> Raise(:insufficient)     // the only call shape the grammar has for a name
```

**As grammar:** a fifteenth keyword, one production `expr -> 'raise' expr`, type `none` (12 §4;
`bs_types:none/0` exists), lowered to `erlang:error(E)`. ENG-293 builds exactly that.
**As a function:** `Raise` is the first and only function in the unqualified column, so it drags in
the shadowing rule 65 has not written — `compiler_known_redeclared/1` refuses *types* only, and a
user's `Raise/1` today would simply win. Ticket 15 wrote *"a prelude function taking any term"*;
ticket 12 §5 wrote it without parentheses; the 2026-08-25 review reopened it.

➡️ **Grammar.** It is how the decision's own example spells it, it keeps the unqualified column at
zero functions — Gleam's shape exactly — and it costs one keyword against a rule 65 would otherwise
owe. 15's line is corrected in place, dated.

---

❓ **Q4 — What does `ToExistingAtom` return?**

```csharp
ToExistingAtom(name)   // 10 §5 wrote `atom | :nothing`; F31 refuses that at the declaration
```

`option<atom>` collapses to `atom` (15 §1, built as F31). "An existing atom" has no success type
narrower than `atom`, so a narrower success member is not available. What survives is
`result<atom, E>` — *failure carries a reason*.

➡️ **`result<atom, string>`**, the reason being the name that resolved to nothing. One line in
`PRELUDE.md`; ENG-294 builds it.

---

**And one correction to confirm, not a question:** `bool` is decided as a prelude alias (10) and
built as `builtin(bool)`. Every other builtin type name is a rule, C#'s `bool` is a keyword
aliasing `System.Boolean`, and Q2's criterion says a builtin *is* stratum 2. Correct 10's line in
place to "builtin", dated, rather than rewriting the compiler to match a sentence.

## Waits on round 1

- **(Q1)** The collision: `using Shop.Collections` beside a reserved `List`. Refuse the `using`,
  refuse a module whose last segment is a reserved qualifier, or let the reserved qualifier win and
  the user's module stay reachable only in full. Elixir's answer is the one 48 measured as a crash.
- **(Q1)** The universal-order escape's name (16, `PRELUDE.md` item 5) — under (b), a third reserved
  qualifier, e.g. `Term.Compare(a, b)`; under (a), a function somewhere.
- **(Q1)** `hd`, `tl`, `length`, `elem` (item 7) — under (b) there are no lowercase callables; the
  pattern does `hd`/`tl`, `List.Length` does `length`, and `elem` has no proposed use.
- **(Q2)** How the two kinds of entry are documented differently (item 3).
- **Ticket 65** inherits Q1's answer on closedness; its policy stays its own to decide.

## Chores this ticket found, owed regardless of the answers

- Rename `PRELUDE.md` — ten citations, `check-links`, three compiler modules (already recorded on ENG-281).
- `LANGUAGE.md` says "prelude" 8 times after `CONTEXT.md` retired the word on 2026-08-25.
- `PRELUDE.md`: `/` and `%` *"neither is a token"* — both are; the `foreign_error` row's stratum.
- `LANGUAGE.md:1384` or `:1178` — whichever Q1 does not choose.
