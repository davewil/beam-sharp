# F45 — a polymorphic function signature

**Status**      **done 2026-09-12** — 22 tests in `poly_signature_tests`; 859 in the suite, up
                from 837. No new gate: the ticket's program is `examples/Shop/Rows/`, which
                `check-examples.sh` refused at the `<` after the function name before the
                build and compiles after it, `editor/bin/check-corpus.sh` reported an ERROR
                node on the same token before the grammar change and parses it after, and
                the corpus roster gained *a polymorphic signature*. Three `diagnoses:` blocks
                in `LANGUAGE.md` §9 seen red on the tree first. `./bin/verify.sh` green
                **twice from a clean clone**
**Implements**  [ticket 27 §(c)](../../wayfinder/issues/27-parametric-polymorphism.md) — a
                variable quantified in a value-level signature, instantiated at each call —
                with the algorithm of [ticket 37](../../wayfinder/issues/37-instantiation-by-matching.md),
                resolved 2026-08-28 and sequenced 2026-09-12 as the first feature inside
                [ticket 75](../../wayfinder/issues/75-a-function-as-a-value.md)'s increment;
                27 §2's opacity in clause heads; [ticket 28 §6](../../wayfinder/issues/28-generic-bracket-parsing.md)'s
                rule that every variable appears in a parameter
**Closes**      [ENG-295](https://linear.app/davewil/issue/ENG-295); unblocks
                [ENG-365](https://linear.app/davewil/issue/ENG-365), the arrow
**Decides**     nothing. Two things the ticket left to the build are taken as its own words
                have them: the variables are declared after the name in C#'s convention,
                and a declaration is checked with each variable **opaque** — an atom no
                source can spell bare — because 27 §2 says a variable has no shape until a
                caller chooses one, and an algebra with no variable node (37's cost) has
                exactly one thing contained in nothing but itself
**Depends on**  F6 (the parametric alias, whose `type_params` this reuses and whose
                `{parametric, Params, Body}` templates this expands), F11 (the world, for the
                template to cross `using`), F17 (`--api` as a declaration pass), F25 (the
                corrected signature, which now prints `<T>`), F28 (`unfold/1`, which
                `tuple_comp/3` calls first)

## What was there

F6 built 27's §(a) and §(b): a bracket applied to ground arguments and a parametric alias.
Both are substitution — *"the variable is gone before the algebra sees it"* — and F6's table
recorded the third row as not built. Ticket 37 then priced the third row and found the
corpus paying for its absence: 25d's `rows.bs` wrote `Prepend` at one element type, and 25e
needed `Reverse` at two and was refused the second copy under the first's name. The one
corpus shape left after ENG-321 inlined `List.Reverse` is `Prepend`, and it is the program.

At `515525d`, `T Pick<T>(T a, T b)` was a syntax error at the `<`: `signature` had no
`type_params`, so a variable could not be declared, and had one been declared nothing would
have solved it — `ty()` has six parts and none is a variable, and `call/6` handed back a
declared return with nothing substituted.

## The program

25d's traverse, at two element types in one module. From `examples/Shop/Rows/Rows.bs`:

```csharp
module Shop.Rows

record OrderRow { Id: int, Status: atom }
type FetchError = (:unknown_status, atom)

public result<list<OrderRow>, FetchError> Rowed(list<(int, atom)> rows)
Rowed([])          -> []
Rowed([w, ..rest]) -> Build(w) switch {
    (:error, e) => (:error, e),
    row         => Prepend(row, Rowed(rest))
}

public result<list<int>, FetchError> Ids(list<(int, atom)> rows)
Ids([])                -> []
Ids([(id, _), ..rest]) -> Prepend(id, Ids(rest))

private result<OrderRow, FetchError> Build((int, atom) w)
Build((id, :placed))  -> OrderRow{ Id = id, Status = :placed }
Build((id, :shipped)) -> OrderRow{ Id = id, Status = :shipped }
Build((_, s))         -> (:error, (:unknown_status, s))

private result<list<T>, E> Prepend<T, E>(T row, result<list<T>, E> rest)
Prepend(row, (:error, e)) -> (:error, e)
Prepend(row, rows)        -> [row, ..rows]
```

```
$ bsc --src-root examples examples/Shop/Rows/Rows.bs Rowed "[(1, :placed), (2, :shipped)]"
[OrderRow{ Id = 1, Status = :placed }, OrderRow{ Id = 2, Status = :shipped }]
$ bsc --src-root examples examples/Shop/Rows/Rows.bs Ids "[(1, :placed), (2, :lost)]"
[1, 2]
$ bsc --src-root examples examples/Shop/Rows/Rows.bs Rowed "[(1, :placed), (2, :lost)]"
(:error, (:unknown_status, :lost))
```

`Rowed`'s arm `row => Prepend(row, Rowed(rest))` is the test of the solve and not of the
containment: the call is accepted either way, but the arm's body must be contained in
`Rowed`'s declared return, and at the extent alone `Prepend` returns
`list<term> | (:error, term)`, which it is not. It compiles because `T` is solved to
`OrderRow` from the first argument and from the list part of the second, joined, and `E`
to `FetchError` from the tuple's second component, and the declared return is rewritten with
both. `Ids` solves the same signature to `int` two lines down.

The four refusals, each read from `bsc` rather than written from memory:

```
$ … public int Both(int n) / Both(n) -> Pick(n, :a)
error: Both returns outside its signature …
  int | :a Both(int n)
$ … public term Bad(int n) / Bad(n) -> Prepend(n, n)
error: argument 2 of Prepend is not accepted …
$ … public T Pick<T>(T a, T b) / Pick(1, _) -> 1
error: Pick inspects a value whose type is the variable `T`
  the pattern in argument 1 tests a runtime shape, and `T` has no shape until a caller chooses one
  hint: a bare type variable admits one clause, so bind it — or take a union parameter instead of a type variable to dispatch on shape
$ … public list<T> Empty<T>()
error: Empty's type variable `T` appears in no parameter
  instantiation is matching: a caller's arguments choose `T`, and a variable only in the return type has nothing to be matched against
  hint: write the type the function actually returns, or take a parameter whose type mentions `T`
```

```
$ bsc --src-root examples --api examples/Shop/Rows/Rows.bs
module Shop.Rows
(:error, (:unknown_status, atom)) | list<int> Ids(list<(int, atom)>)
(:error, (:unknown_status, atom)) | list<{ Kind: :'Shop.Rows.OrderRow', Id: int, Status: atom }> Rowed(list<(int, atom)>)
$ bsc --src-root … --api Pick/Pick.bs
module Pick
:a | int Both(int)
T Pick<T>(T, T)
```

`--api` prints the resolved type for a ground signature, as F17 always has, and the
**written** one for a polymorphic signature: its resolved form is the extent,
`term Pick(term, term)`, true of the function and useless to a caller. The term channel
carries `type_variables => ['T']` on that operation and nothing new on any other.

## What shipped

**The grammar.** `signature` gains `uident '<' type_params '>'` in both its forms — the
nonterminal a parametric alias already binds, so a variable is a `uident` like any user type
name and the list alone tells the two apart. `yecc:file/2` with `{report, true}` measured
**0 conflicts before and 0 after**: nothing but `(` or this `<` can follow `type_expr uident`.
The signature tuple gains a seventh element, the variable list, and every one of its
sixteen consumers in `bs_check` and `bs_api` was rewritten in one sweep, because a
comprehension over a six-tuple yields nothing on a seven-tuple and reports no error — the
`--api` filter at `bs_api.erl:179` would have printed *exports nothing*. `#fn` gains `tvars`
**last**, because the emitter reads the record by element position.

**Two bindings, for two readers.** `erased_env/2` puts every variable at `term`; `opaque_env/2`
puts each at `bs_types:atom_lit(V)`, a singleton atom the source can only spell quoted. The
callee table, `exports_of/2` and the emitter's `-spec` use the erased one: ticket 37 measured
(M4, H2) that an argument is refused **exactly** when it escapes the parameter's maximal
extent, so `arg_diags/7`'s containment against the extent is the whole of the argument check
unchanged, and the emitted spec reads `any()`, which 27b measured as inert. `check_fn/2` and
`collapse_decl/2` use the opaque one: `[row, ..rows]` over `list<'T'>` is contained in
`list<'T'> | (:error, 'E')`, `5` over `'T'` is refused as a return outside the signature, and
`list<'T'>` is still `[] | ['T', ..]`, so exhaustiveness is decided once at the declaration
and holds for every instantiation — 27 §2's *"exhaustive at the definition"*, executable.

**The template.** `template/4` resolves every ground part of a signature under the declaring
module's environment and leaves only the variables standing, expanding a parametric alias
through F6's `{parametric, Params, Body}` and `subst/2` so `result<list<T>, E>` arrives as
`list<T> | (:error, E)` with `list<T>` already `{t_generic, list, [{t_ref, 'T'}]}`. What
survives is closed — a resolved map, `{t_ref, V}`, `list<_>`, a tuple, a union — the four
positions ticket 37's algorithm reads a share from, and it crosses `using` as a value with
no producer alias in it, which is F44's rule applied to a template.

**The solve, at `call/6`.** `instantiate/2` is the probe `37a` over the template: a bare
variable takes the whole argument; `list<_>` takes `list_elem/1`; a tuple component takes
`bs_types:tuple_comp/3`, the one export the algebra gained, which unfolds first as every
reader of a part does; inside a union a member's share is the argument minus every other
member's extent, the subtraction 63 proved exact. A variable met twice is joined by union,
licensed by 27 §2's opacity. The declared return is then rewritten with the solution and is
what the call has as its type. The argument diagnostics are `arg_diags/7`'s, unchanged.

**Erasure, recorded.** A variable under a map field, a refinement, or a parametric alias
unfolding onto itself is resolved at its extent in the template, and the variable is recorded
so the call solves it to `term` rather than to its other occurrences alone: a value could
reach the body through the erased position, and a return narrower than `term` there would be
a lie. A variable no parameter mentions stays at its extent for the same reason — and is
refused anyway, below.

**Three refusals ticket 27 and ticket 28 had already written.** `pattern_on_type_variable`:
a parameter declared over a bare variable admits one clause, a binder; `Pick(1, _)` is
refused at the declaration, before the walk, with 27 §2's own wording. Without it the
opaque atom would have reported the clause as vacuous — a true sentence about the compiler
and a false one about the language. `unrecoverable_type_variable`: a variable in no parameter
position is refused, 28 §6's rule that *"instantiation is matching"* is a true sentence only
under. `obligation_over_type_variable`: `ValidateAs<T>` and `ParseAtom<T>` inside a
polymorphic function are refused where they are written — ticket 27's *"an error rather than
a generic call"* — and this one was found by a probe rather than read from a ticket: under the
opaque binding the checker accepted the call and the **emitter crashed** building the
validator table, since the erased environment it resolves under has no `T`. All three carry a
`message/1` clause, all three are demonstrated in `LANGUAGE.md` §9 under `diagnoses:`, and
all three reach past ENG-295's priced *"no new diagnostic"* line — that line priced the
algorithm, and these are rules the tickets that own the feature had decided.

**The corrected signature prints the declaration.** `line_of/2` writes `<T, E>` after the
name, so `T | int Pick<T>(T a, T b)` pastes back and parses.

**The world carries `polys`.** `bsc:build/4` stores `polys_of/2` beside `exports`;
`import_env/4` keys the templates as `qual_table/1` keys the signatures, so an imported call
resolves to `{q, M, N, A}` once and finds both. A world handed in with `exports` alone — the
tests' shape — has no `polys` and nothing is polymorphic there.

**The editor grammar.** `signature` in `grammar.js` gains the alias's own
`'<' type_parameter… '>'` after the name. `check-corpus.sh` reported an ERROR node on
`Rows.bs` before and parses it after.

**The record.** `LANGUAGE.md` §9's *Polymorphic function signatures* block promotes from
`not-yet` prose to a shipped `Prepend` with the two `diagnoses:` blocks beside it, and the
`Map<T, U>` block stays `not-yet` at the arrow, which is ENG-365's; `TOUR.md` §9 shows
`Prepend` from the corpus and the appendix gains the row; the *Decided but not built* table's
row moves from the signature to the arrow; F6's table row is amended; `generics_tests.erl`'s
header no longer says §(c) is a cut; the compiler README's table names `examples/Shop/Rows/`.

## Four things the build found

1. **The definition-site check is where opacity earns its keep, and 37's *"no variable
   node"* cost had nothing to say about it.** Checking the body at the extent lets
   `T Id<T>(T x); Id(x) -> 5` through, and a caller then trusts `T = :a` from its argument
   while the runtime hands back `5`. The opaque atom closes that without a node: it is the
   smallest type contained in nothing but itself, and every existing operation — subtract,
   the residual printer, exhaustiveness — reads it as the ordinary atom it is. The one place
   it must not leak is the emitted spec, which reads the erased binding instead.
2. **The two tickets that own this feature had each written a refusal the pricing did not
   count.** 27 §2's diagnostic text was on the record since 2026-08-13, and 28 §6 made the
   recoverability rule a spec obligation on 2026-08-14. Neither is a decision this feature
   made; both were a `message/1` clause and a `diagnoses:` block away, and a build that
   shipped the solve without them would have shipped a signature that lies to its reviewer,
   27's own phrase.
3. **The corrected-signature printer was already polymorphism-ready.** It concatenates the
   written return with the residual rather than re-rendering the declared type, so `int | :a
   Both(int n)` came out right first time; only the `<T>` after the name was missing.
4. **A binding that makes a variable resolvable makes every obligation over it generable.**
   Before F45 `ValidateAs<T>` in a signature-less world was refused by accident, as an unknown
   type; the opaque binding turned that accident into a checker that accepted the call and an
   emitter that crashed on it. The rule ticket 27 stated — ground, or refused — had to be
   written down as a check the moment the accident stopped enforcing it.

## What is asserted, and where

`poly_signature_tests.erl`, callers only — the solve is observable in what a call returns
and nowhere else:

| Id | Asserts |
|---|---|
| F45.1 | one `Prepend`, two element types: `Ids` and `Names` compile and run against the instantiated return; the corpus program runs at both types through the CLI |
| F45.2 | `Pick<T>(T, T)` with an `int` and an atom returns `int \| :a`; declared narrower, refused with `int \| :a Both(int n)` in the correction; two arguments of one type collapse |
| F45.3 | `option<T> First<T>(option<T>)` handed `:nothing` returns exactly `:nothing`; declared `int`, refused |
| F45.4 | `Prepend(n, n)` is refused at argument 2, the one outside the extent; a bare `T` handed a list and a tuple rejects nothing |
| F45.5 | `Prepend` short of its error clause is inexhaustive at the declaration; a body returning `(:error, row)` from `list<T>` is refused at the declaration |
| F45.6 | `Pick(1, _)` is refused as `pattern_on_type_variable` at argument 1; `[]` / `[h, ..]` over `list<T>` is exhaustive |
| F45.7 | `--api` prints `T Pick<T>(T, T)` and `:a \| int Both(int)` |
| F45.8 | a dependent instantiates `Lib.First<T>` at `int` through `using` and runs; declared narrower, it is refused with the instantiated correction |
| F45.9 | the emitted spec erases the variables and the module loads and answers |
| F45.10 | `list<T> Empty<T>()` is refused as `unrecoverable_type_variable`; `list<T> Rest<T>(list<T>)` stands |
| F45.11 | `ValidateAs<T>` and `ParseAtom<T>` inside a polymorphic function are refused as `obligation_over_type_variable`; `ValidateAs<int>` inside one stands |

`corpus_tests.erl`: the roster row. `check-examples.sh` and `editor/bin/check-corpus.sh`:
`examples/Shop/Rows/`. `check-language.sh`: the §9 blocks, two of them `diagnoses:`.

## Out of scope, and what is owed

- **The guard half of 27 §2.** A comparison between two values of one variable is permitted
  (27's 2026-08-18 amendment, 16 §5); a comparison of a bare-variable value against a literal,
  `Pick(x, _) when x > 3`, is neither that nor a pattern, and this build does not refuse it.
  It is checked against the opaque atom and reads as an unreadable guard, so the clause is
  credited nothing — over-guarded, never under. Owed: a refusal in 27 §2's voice —
  [ENG-366](https://linear.app/davewil/issue/ENG-366).
- **A bare variable as a direct union member rejects nothing.** Ticket 37 M6: `T`,
  `option<T>` and `result<T, E>` in parameter position have maximal extent `term`, while
  `option<int>` and `result<list<T>, E>` do not — a property of the alias shape, not of the
  algorithm, carried here as ENG-295 asked. F45.4's second test records it. A ticket only
  if building meets a program where it matters.

  | Parameter | Extent is `term` | Rejects |
  |---|---|---|
  | `T` | yes | nothing |
  | `option<T>` | yes | nothing |
  | `result<T, E>` | yes | nothing |
  | `list<T>` | no | a non-list |
  | `result<list<T>, E>` | no | `Prepend(n, n)` |
  | `option<int>` | no | an atom that is not `:nothing` |
- **A variable under a map field or a refinement** is solved at its extent, above. No corpus
  program writes one; the first that does raises the question of a map-field projection in
  `bs_types`, which is one export beside `tuple_comp/3`.
- **The arrow, the lambda, and a name in value position** — ENG-365, now unblocked. `Map<T, U>`
  stays `not-yet` in §9 at the `fn`.
