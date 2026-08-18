# F14 — The pipe and the valve: `|>` and `|?>`

**Status**      done · [ENG-223](https://linear.app/davewil/issue/ENG-223)
**Implements**  [ticket 17](../../wayfinder/issues/17-pipeline-and-comprehension.md) §1 and §4,
                resolved — decides nothing
**Unblocks**    25a's admission chain and the decode pipelines in 25b and 25c; and it hands
                [ticket 31](../../wayfinder/issues/31-composable-middleware.md) the thing it needs
                to be answered by **measurement** rather than by argument
**Depends on**  F6 (parametric aliases — see the measurement below), F7 (`switch`, which the valve
                lowers to), F11 (qualified names at a call site)

## Why this one now

It is the only takeable feature with a file-shaped job left. F13 waits on ticket 30, which is open;
F12 closed the last whole-corpus rewrite. Both operators were decided on 2026-08-13 and neither
exists in the lexer.

**And it is the feature that lets a ticket be closed by measuring.** Ticket 31 asks whether `|?>`
already expresses composable middleware — Plug's `halt/1`, structurally — and it cannot be answered
today because the operator it is asking about has never been run. This project's habit is to resolve
by measuring rather than by choosing (43, 41, 28), and 31 is currently the largest question that a
single afternoon of building would settle. That is a reason to build it, not merely to schedule it.

## Measured before this file was written, not assumed

**`Result<T, E>` can already be declared, and the checker already dispatches on its error member.**
This looked like a prerequisite and is not:

```csharp
module R

type Result<T, E> = T | (:error, E)

public atom Check(Result<int, atom> r)
Check((:error, e))   -> e
Check(n) when n > 0  -> :ok
Check(n) when n <= 0 -> :nonpositive
```

```
$ bsc --src-root . R Check 5                 -> :ok
$ bsc --src-root . R Check "(:error, :boom)" -> :boom
```

F6's parametric aliases plus ticket 15's **untagged** `result` deliver it between them, and nobody
had noticed because no `.bs` file had ever written one. So **F14 needs no new type machinery** — the
valve's whole job is control flow over a union that already type-checks.

**The lowercase spelling does not parse.** `type result<T, E> = …` is `syntax error before: result`,
because `type_decl` takes a `uident`. That is ticket 17's own examples written in a case the grammar
does not have, and it is worth knowing before the exemplars are believed literally.

**Neither operator lexes.** `|>` and `|?>` appear nowhere in `bs_lexer.xrl`.

## What is being built

**The pipe is a rewrite and nothing else** (17 §1):

```csharp
xs |> List.Filter(p)          ==   List.Filter(xs, p)
o  |> Orders.Apply(e)         ==   Orders.Apply(o, e)
```

The piped value becomes the **first** argument. Names are qualified — 17 §1 killed the dot as a call
on a mechanism (`xs.Filter(f)` needs type-directed resolution of an unqualified name, closed by 08
and 16), so the pipe is what survived that argument rather than a second spelling beside it.

**The valve short-circuits on the error member** (17 §4):

```csharp
public Result<Order, Error> Place(Request r)
Place(r) -> Validate(r) |?> CheckStock() |?> Charge() |?> Confirm()
```

If `Validate` yields `(:error, :bad_request)`, nothing downstream runs and `Place` returns that error
unchanged. **The escape hatch is the operator's absence**: write `|>` and handle `(:error, _)` in
your own clause when a stage wants to inspect the failure.

**It is called the valve** (David): a valve is the thing in a pipe that stops the flow. `|?>` keeps
the `|>` silhouette with the `?` inside it, so it reads as a variant rather than a new token, and
`?` is free because ticket 10 dropped the ternary.

## The four things this feature decides, all mechanism

Ticket 17 settled both operators and their meaning. It left four questions of *implementation*, and
each is settled below the way F12's three were — the ticket named the behaviour, the feature names
the mechanism.

### 1. The right operand is a CALL in the grammar, not an expression

17 §1 is explicit that the pipe **never passes a bare function value** — that was the whole reason
`Result.Then` lost to the valve, since it is "the only candidate that forces this ticket to spell
*function as a value*". So the rule is

```
pipe -> expr '|>' call
```

rather than `expr '|>' expr` with a check afterwards. Two things follow, and both are why it is worth
writing down: `x |> F` is a **syntax error** rather than a type error, which is the right layer for
it; and the right operand needs no precedence of its own, because it is not an expression.

### 2. The pipe desugars in the PARSER; the valve desugars to a `switch`

The pipe is a pure syntactic rewrite, so the parser can emit the call node directly and **no checker
or emitter change is needed at all** — exhaustiveness, the residual, the five check sites and the
`-spec` all see `F(x, a)` because that is what exists.

The valve cannot be a call: 17 §7 already states that "a `|?>` chain emits a `case` per stage". It
lowers to a two-armed `switch` over the left operand:

```csharp
a |?> F()     ==     a switch {
                       (:error, e) => (:error, e),
                       v           => F(v)
                     }
```

**Lowering to `switch` rather than to a bespoke node is the whole trick**, and it is what makes the
valve nearly free: F7 built `switch`, F2 built interval and union subtraction, and F5 built the body
check — so the `v` arm's parameter type is *already* the residual after `(:error, E)` is subtracted,
and each stage in a chain is type-checked against the narrowed type without this feature writing a
line of type code. A bespoke node would have had to re-derive all of it.

### 3. A diagnostic reports at the pipe's LINE — and that is all it can do

The cost of §2's rewrite is that an error inside `x |> F(a)` reports against `F/2`. That is the same
shape ticket 40 §2 complained about — *"the defect is the diagnosis, not the outcome"* — so the
rewritten node carries the pipe's own line rather than the call's.

**AMENDED WHILE BUILDING.** This section originally also said "the reports say `|>` where the author
wrote `|>`", and that half was withdrawn, because it contradicts §2. Naming the operator in the
message would require `bs_check` to know which calls came from a pipe — and §2's whole claim is that
**no checker change is needed at all**, which is the property that made this feature cheap. A marker
on the call node would also mean widening `{e_call, …}`, which is the one AST change this repo has
measured as failing silently.

So the line is what is delivered, and the concrete cost is worth writing down, because a reader will
meet it:

```
Run(n) -> n |>
  Twice(:oops)
```
```
L.bs:5: error: Run hands Twice an argument it does not accept
  argument 2 is not covered by Twice's declared type
```

Line 5 is the pipe (the call is on line 6), and `:oops` — the first argument the author *wrote* — is
reported as **argument 2**, because after the rewrite it is. Both are consequences of §2 rather than
defects, and the second is the one that would surprise somebody.

### 4. A valve over a value that cannot fail is an error, not a dead arm

If the left operand's type has no `(:error, _)` member, the generated first arm is unreachable and
the checker would report an unreachable clause — a remark about generated code the author never
wrote, which is F7's costume for the third time. It raises `{valve_on_infallible, Type, Line}`
instead: the fix is to write `|>`, and the message says so.

### 5. The pipe sits at 350 — tighter than comparison, looser than arithmetic

Not in this file when the work started, and it should have been: the scenarios bound the precedence
on **one** side only. F14.5 wants `a + b |> F()` to read as `(a + b) |> F()`, which puts it looser
than `+` (400). The other bound is not in any scenario — `var x = a |> F()` needs it tighter than
`=` (50), or the binding reduces before the operator shifts. So the window is **51..399** and nothing
in the feature discriminates inside it.

Settled by the borrow heuristic rather than by taste: **Elixir** puts `|>` tighter than comparison
and looser than arithmetic, so `a |> F() == b` is `(a |> F()) == b`. That is 350 in this table, and
it is what both grammars now say. `Left`, because a chain is left-associative — `a |> F() |> G()` is
`G(F(a))`, the only reading in which a pipeline runs in the order it is read. Both operators share
the level, so `a |?> F() |> G()` needs no bracket. Pinned by two tests, one per bound.

### 6. `x |> F` gets yecc's own message, and the nicer one was measured and dropped

§1 asks that a bare name after the pipe be a **syntax** error rather than a type error, and the
grammar delivers that on its own. This repo's habit is then to name a known-shape refusal — the
record's `Id:int` and `Notes?: int` productions both do — so two `expr '|>' modpath` productions were
written, with a message saying to add `()`.

They were removed. They buy a better sentence and cost **2 shift/reduce conflicts** against a grammar
that has held 0, and a conflict is the one thing yecc reports as a warning while still emitting a
parser that looks like it works. Recorded here rather than left out, so the next person to want the
message knows it was tried. The zero-conflict grammar was judged worth more than the sentence.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F14.1 | `Double(n) -> n \|> Add(n)` over `Add(int, int)` | `bsc … Double 4` | `8` | 0 |
| F14.2 | a three-stage chain of ordinary calls | `bsc …` | the value of the nested call | 0 |
| F14.3 | `n \|> Shop.Collections.List.Sum(0)` | `bsc --src-root examples …` | qualified and namespace-short both pipe | 0 |
| F14.4 | `x \|> F` — no argument list | `bsc` it | a **syntax** error, not a type error | 1 |
| F14.5 | `a + b \|> F()` | the parse | `(a + b) \|> F()` — the pipe binds looser than arithmetic | 0 |
| F14.6 | a valve chain whose first stage yields `(:error, :bad)` | `bsc …` | `(:error, :bad)`, and no later stage runs | 0 |
| F14.7 | the same chain with a success | `bsc …` | the final stage's value | 0 |
| F14.8 | a stage declared over the **narrowed** type (`CheckStock(Valid v)`, not `Result<…>`) | `bsc …` | compiles — the `switch` residual is what makes the signature honest | 0 |
| F14.9 | `\|?>` over a type with no `(:error, _)` member | `bsc` it | `{valve_on_infallible, …}`, naming `\|>` as the fix | 1 |
| F14.10 | an error inside a piped call | `bsc` it | the diagnostic names the pipe's line | 1 |
| F14.11 | `examples/` gains a pipeline example; both operators get probe rows | `rebar3 eunit`, `editor/bin/check-corpus.sh` | green | 0 |

## Out of scope

- **The collection prelude.** 17 §2's inlining rule, the two-tier emitted boundary, `List.Filter`
  and friends as compiler-known functions — a separate capability with codegen consequences that
  ticket 18 is still arguing over. The pipe needs none of it: it rewrites to whatever call you wrote.
- **Lambdas.** `xs |> List.Filter(o => o.Status == :open)` is 17's illustration and **the arrow does
  not exist** — ticket 27 measured that there is no lambda and no arrow in the algebra. F14 pipes
  into ordinary named calls, which is every example the exemplars actually need.
- **`cond`** — deferred by 17 §6 until ticket 25 reports whether the shape occurs.
- **Laziness and `stream<T>`** — deferred by 17, and cheap to add later *because* names are qualified.
- **Whether `|?>` is enough for composable middleware** — that is [ticket 31](../../wayfinder/issues/31-composable-middleware.md),
  and it is **downstream of this feature rather than blocking it**. F14 gives 31 a running operator
  to measure; 31 decides whether anything more is owed. A feature may not decide, and this one does
  not.
- **`Result<T, E>` as a builtin.** It is declarable today (measured above) and F14 uses the
  declaration. Whether the prelude should ship one is the prelude-stratum question 17 §7 left open.

## Done when

`Validate(r) |?> CheckStock() |?> Charge()` runs, short-circuits on the error member and returns it
unchanged; `xs |> List.Sum(0)` rewrites and runs; all eleven scenarios hold; `examples/` demonstrates
both operators and the probe roster has a row for each; and all ten CI gates are green.

## Done — what it took, and the three things that were not in the plan

All eleven scenarios hold. `compiler/examples/Pipeline/pipeline.bs` runs both operators, `LANGUAGE.md`
§8 is two compiling blocks instead of two `not-yet` ones, and `test/pipe_tests.erl` carries the
thirteen assertions — including F14.4 and F14.9, which `examples/` can never hold because both are
refusals.

**A new module, `bs_lower`, and a pass between parse and check.** §2 said the pipe desugars in the
parser, and it does. The valve cannot: it needs two synthesised binders per stage, unique across the
**file** rather than per line. `a |?> F() |?> G()` is one line and two valves, and `a |?> F(b |?> G())`
nests one inside the other's value arm — Erlang's scoping is flat within a clause, so a repeated name
stops being a fresh binding and silently becomes a **match** against the enclosing stage's value. A
yecc action cannot carry a counter, so the numbering is a walk after the parse. `bs_lower` also owns
`pipe_into/3`, which the parser calls directly, so the rewrite has one definition rather than two.

**The lowered switch stays wrapped in a marker.** Emitting a bare `e_switch` was the obvious move and
is wrong twice over: the checker would report `unreachable_arm` for the generated `(:error, e)` arm
when the subject cannot fail — which is exactly the message §4 exists to replace — and ticket 12 §2's
rule against a catch-all over a closed residual would fire on the value arm, which is a catch-all by
construction, **every time**. So `{e_valve, L, Switch}` reaches `bs_check`, which passes `generated`
to the arm walk, and `bs_emit`, which unwraps it. Every other site is one line of delegation.

**Two gates were lying by omission, and both are fixed here.** `bs_test_support:check_only/1` called
`bs_parser:parse` directly and would have skipped the lowering entirely — an unlowered `e_valve`
falls through `type_of/3`'s catch-all to `term()` with no diagnostics, so every valve assertion about
clean source would have passed while nothing was checked. And `editor/bin/check-tokens.sh` checked
"keywords and the two arrows", a hardcoded pair, so it could not see `|>` or `|?>` at all; it now
checks a named list of multi-character operators and was measured failing before being believed.
