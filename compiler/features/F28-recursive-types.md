# F28 — recursive types: the binder ticket 09 decided and nothing built

**Status**      **not started** — spec written 2026-08-26 ·
                [ENG-260](https://linear.app/davewil/issue/ENG-260)
**Implements**  [09](../../wayfinder/issues/09-union-representation.md) (equirecursive, contractive,
                subtyping decided coinductively) — decides nothing new
**Unblocks**    exemplar **25e** (its front wall *is* this), `iodata` as a declarable type, and
                F18's owed validator obligation
**Depends on**  F6 (the cycle guard and the contractive/non-contractive split already exist),
                F18 (the validator generator this must not break)

## Why this one now

**Because an exemplar stopped on it, and it is the first wall in the set that the checker raised
rather than the parser.**

Ticket 09 decided recursion on 2026-08-12 — equirecursive, contractive, subtyping decided
coinductively. Four separate places have since written "when it lands" and routed to nobody:

| Where | What it says |
|---|---|
| `LANGUAGE.md` | recursive types are refused **by name**; the algebra cannot hold one |
| [F6](F6-angle-brackets.md) out-of-scope | *"Implementing them is 09's equirecursive machinery arriving for real"* |
| [F18](F18-validate-as.md) out-of-scope | already states the obligation: the generator needs **a name assigned before the body is built** |
| `bs_check.erl:855` | the two refusals are distinguished in the source, with the contractive one called *"a feature, not a defect"* |

**F6 did not merely document it — it shipped a stopwatch.** A cyclic alias did not error on master,
it **hung**, and the guard arrived with the feature that made recursive aliases the natural thing to
write rather than with the one that implements them. That is the shape of this feature's risk, and
§"The gate" below is built on it: *a hang is invisible to a green suite.*

**What makes it now rather than earlier**: [25e](../../wayfinder/prototypes/25e-dynamic-web-page.md)
put a real program behind the abstract case. `iodata` — `binary | list(iodata)`, what every BEAM web
stack passes to the socket — is the type of every value a server-rendered page produces, and the
whole module is otherwise written in a language this compiler already has. Measured: with a `term`
stand-in for the recursive type, **exactly one** genuine error remains in five files. This is not a
program blocked on a dozen missing things.

And the algebra already computes the type it cannot be told. Nest a fragment one level and the
residual comes back exact:

```
not covered by the declared return type:
    [list<string>, ..] | [string, ..]
```

**So the work is a binder, not a lattice.**

## Where it starts

Measured 2026-08-26 at `caa3c52`, all six with a 20-second watchdog and **none of them hung** —
F6's guard holds. Five reach one refusal and the sixth reaches the other:

| Shape | Today |
|---|---|
| `type Tree = :leaf \| (:node, Tree, Tree)` | `error: Tree is a recursive type, and those are not built yet` |
| `type Iodata = binary \| list<Iodata>` | same — this is 25e's front wall, and `FRONTIER`'s fifth record |
| `record Node { Value: int, Kids: list<Node> }` | same |
| `type A = :nil \| (:a, B)` / `type B = :nil \| (:b, A)` (mutual) | same, reported against `A` |
| `type Tree<T> = (T, list<Tree<T>>)` | same |
| `type X = X \| int` | **a different message**, and a correct one: *"the recursion does not pass through a constructor … that is not a missing feature"* |

That last row is the one to keep. The contractive/non-contractive split is already implemented and
already worded; F28 must move the first five and **leave the sixth exactly where it is**.

## Scenarios

Each is input, command, expected output, exit code.

**F28.1 — a recursive type resolves, and a function over it is exhaustive with no catch-all.**

```csharp
type Tree = :leaf | (:node, Tree, Tree)

public int Size(Tree t)

Size(:leaf)         -> 0
Size((:node, l, r)) -> 1 + Size(l) + Size(r)
```

`bsc … Size '{node,leaf,{node,leaf,leaf}}'` → `2`, exit 0. **Two clauses, no catch-all**: `:leaf`
and the node tuple partition `Tree`, and if they did not this feature would have bought a type the
exhaustiveness checker cannot see through.

**F28.2 — the iodata shape, which is 25e's wall.**

```csharp
type Iodata = binary | list<Iodata>

public Iodata Page(string title)

Page(t) -> ["<html>", ["<h1>", t, "</h1>"], "</html>"]
```

exit 0. A **nested** literal, because a flat one already compiles as `list<binary>` and would prove
nothing.

**F28.3 — recursion through a record field**, `record Node { Value: int, Kids: list<Node> }`.
A field is a constructor crossing and the resolver already records it as one; this scenario is here
because it is the crossing kind with the least in common with the other two.

**F28.4 — mutual recursion.** `type A = :nil | (:a, B)` beside `type B = :nil | (:b, A)`. Neither
name alone is a cycle; the pair is. A binder that keys on the name being resolved handles F28.1 and
fails this, which is why it is separate.

**F28.5 — recursion under a type parameter.** `type Tree<T> = (T, list<Tree<T>>)`, used at
`Tree<int>` and at `Tree<string>` in the same module. F6's own note names this as *"the first thing
anyone tries"*. Polymorphic recursion is **permitted** — ticket 09's generics answer says so
explicitly, because ticket 04 already paid for it with mandatory signatures and the undecidability
is about inference.

**F28.6 — the non-contractive refusal is unchanged.** `type X = X | int` still fails with the
*current* wording, byte for byte. **This is the control scenario and the feature is unsound without
it**: an implementation that simply stopped refusing would pass F28.1–F28.5 and admit a type
describing no values.

**F28.7 — equirecursive means two spellings are one type.**

```csharp
type L1 = :nil | (:cons, int, L1)
type L2 = :nil | (:cons, int, :nil | (:cons, int, L2))
```

A value of `L1` is accepted where `L2` is declared and the reverse, with no conversion — ticket 09's
*"two names over the same set are the same type"* reaching the case that needs coinduction to
decide. If this fails, what shipped is isorecursive and 09 was not implemented.

**F28.8 — exhaustiveness terminates, and the residual is finite.** Delete `Size(:leaf)` from F28.1
and the diagnostic must name `:leaf` and **return**. The subtraction that computes a residual walks
the type; over a regular tree it must memoise or it unfolds forever. Asserted with a clock (see the
gate), not only with a message.

**F28.9 — `ValidateAs<Tree>` generates a terminating validator.** F18's owed obligation, already
written down there: the memo table must hold the function name for a type **while that type is
still being generated**, or the generator recurses into itself. `bsc … ` over a well-formed term
returns it; over a malformed one the pathed error names the position inside the tree.

**F28.10 — the emitted `-spec` survives Dialyzer.** `bin/spec-check.sh` (stage 28) runs Dialyzer on
emitted specs; a recursive `-type` is ordinary Erlang and must be emitted as one rather than
flattened to `any()`. A spec that widens to `any()` passes Dialyzer and is the failure this
scenario exists to catch, so it asserts the **text** of the emitted type, not only that Dialyzer is
quiet.

**F28.11 — `FRONTIER`'s fifth record moves.** 25e stops somewhere new, and
`check-exemplar-frontier.sh --update` says which capability moved it. The gate is red until the
record is re-measured, which is the point of it.

## The gate

**A stopwatch, not a rejection test** — and this is the one design decision in the file.

Every other gate in `compiler/bin/` asserts that some input produces some output. The characteristic
failure of recursive types produces *no* output: the checker walks a regular tree forever. F6
learned this the expensive way — *"a cyclic alias did not error on master, it hung"* — and its own
note says the mutation *"had to be measured by a clock, not by a red test"*.

`compiler/bin/check-recursive-types.sh` therefore:

1. Compiles each of F28.1–F28.5 and F28.7–F28.9 **under a wall-clock budget**, and is red if any
   exceeds it. A budget, not a hang detector: a memoised walk is fast and an unmemoised one is not
   slow, it is infinite, so any budget discriminates and a generous one is fine.
2. Asserts F28.6's refusal text unchanged.
3. `--self-test` builds **both** defects and requires a red on each:
   - **the non-terminating one** — a build with the memo table disabled, which must blow the budget.
     Without this the gate is a clock that has never been shown to fire.
   - **the over-permissive one** — a build that accepts `type X = X | int`. A gate that only timed
     things would pass over an implementation that admits a meaningless type.
   and a green on the correct form standing beside both, per `spec-check.sh`'s rule from ticket 15.

`timeout(1)` is not on macOS. `perl -e 'alarm N; exec @ARGV'` is, and is what this session used to
measure the table above.

## Out of scope

- **Deciding anything.** Ticket 09 settled equirecursive, contractive, and coinductive subtyping on
  2026-08-12. If building it turns up a case 09 did not cover, that is a ticket, not a judgement
  call inside a feature — the rule the features README states and F6 followed.
- **A surface change of any kind.** `type X = …` already parses recursive definitions; they are
  refused *after* parsing. F28 adds no token, no keyword and no grammar rule, and a diff touching
  `bs_lexer.xrl` or `bs_parser.yrl` is a sign something has gone wrong.
- **`iodata` in the prelude.** Making `Iodata` *expressible* is this feature. Whether the prelude
  should **ship** one, spelled how, is a decision nobody has taken — 25e declares its own. → a
  ticket, and it should wait until at least one more program has wanted it.
- **Binary construction.** 25e's other finding, and unrelated: it is a surface and codegen question
  with no decision behind it (F13 says so). Landing F28 leaves 25e's escaper exactly as awkward.
- **The relational-pattern binder.** 25e's third finding (`Pence(<= 9)` binds no name). Also
  unrelated, and it is 25c's `p_alias` hole seen a second time.
- **Row polymorphism, variance, bounds.** Refused outright by 27 §3, §5 and §7; nothing here
  reopens them, and `with`/spread already covers the case that would want a row variable.
- **Recursion through a function arrow.** There is no arrow in the algebra at all —
  [ticket 37](../../wayfinder/issues/37-instantiation-by-matching.md) is where that lives, and
  `ty()` having no arrow part was re-measured on 2026-08-26.

## Done when

`type Iodata = binary | list<Iodata>` resolves, `25e-dynamic-web-page` stops somewhere new,
`FRONTIER` records where, `type X = X | int` still fails with today's wording, and
`check-recursive-types.sh --self-test` has been seen to go red on **both** a disabled memo table and
an implementation that accepts the non-contractive form.
