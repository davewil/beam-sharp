# F20 — List length: the cons cell decomposes, and length falls out

**Status**      **done 2026-08-21**
**Implements**  [ticket 54](../../wayfinder/issues/54-list-length-in-the-algebra.md), resolved
                2026-08-21 — which also amends
                [ticket 08](../../wayfinder/issues/08-head-and-guard-syntax.md) (the rest becomes a
                marker) and answers
                [ticket 53](../../wayfinder/issues/53-a-route-table-needs-a-closed-list-pattern.md)
                (the route table's spelling)
**Unblocks**    exemplar 25a's route table, which was exhaustive only by virtue of its
                catch-all and is now checked — and it is written `["orders", id]` again, which is
                what that file said before ticket 53 sent it to `..[]` and back
**Depends on**  F2 (interval refinements — the same "a pattern subtracts a set" discipline), F3
                (records, whose sub-position machinery this reuses nothing of), and the tuple part
                of the algebra, whose `product_minus/2` is the rule this feature applies to a
                constructor it was never applied to

## Why this one now

It is a **soundness** defect, not a gap. `Shape([])` beside `Shape([a, b, ..t])` is proved
exhaustive and crashes on `[7]`, and the four-line repro is reachable by following the compiler's
own advice — write `[a, b]`, be told to write `[a, b, ..t]`, get a wider program and a false proof.
Everything else in the queue is a feature; this one is the compiler being wrong.

## What the ticket decided, in one paragraph

The algebra models **no length at all**. A non-empty list is a product of an element and a tail,
subtracted by the rule that already subtracts tuples exactly, and length falls out of the
recursion. The rest position stops being an ordinary pattern and becomes a **marker**, so `[a, b]`
means exactly two, `[a, b, ..]` and `[a, b, ..t]` mean two or more, and `..[]` is retired. That
bound is what makes the recursion terminate.

## The representation

This is the part the ticket left to the build, and it is the whole of the design.

### Today

```erlang
-type elem() :: none | any | ty().
-type list_part() :: {boolean(), elem()}.     %% {contains [], element type}
```

One bit and one element type. A prefix length has nowhere to go, which is the defect.

### After

```erlang
%% A SPINE describes a set of lists by a prefix of element types plus what
%% follows the prefix.
%%
%%   {P, closed}      length is exactly length(P); element i is in P_i
%%   {P, {open, T}}   length is at least length(P); element i is in P_i for
%%                    i =< length(P), and every LATER element is in T
%%
%% The list part is a union of spines. `[]` is {[], closed}. `none` is [].
-type spine()     :: {[ty()], closed | {open, elem()}}.
-type list_part() :: [spine()].
```

The constructors become:

| | before | after |
|---|---|---|
| `nil()` | `{true, none}` | `[{[], closed}]` |
| `cons(T)` | `{false, T}` | `[{[T], {open, T}}]` |
| `list(T)` | `{true, T}` | `[{[], closed}, {[T], {open, T}}]` |
| `term()`'s lists | `{true, any}` | `[{[], {open, any}}]` |

Note the last row: `{[], {open, any}}` is *every* list including the empty one, so `term()` needs
one spine rather than two. `nil()` still needs `{[], closed}` because it is that one value alone.

### The one new operation: unfold

An open spine unfolds one step, exactly:

```
{P, {open, T}}  ==  {P, closed}  ∪  {P ++ [T], {open, T}}
```

A list of length >= n either has length exactly n, or has length >= n+1 with element n+1 in T.
Unfolding to depth L gives the closed spines at lengths n..L-1 plus one open spine at L.

**This is where termination lives.** Nothing unfolds on its own; unfolding is driven by the
*subtrahend*, whose prefix length is a syntactic property of a pattern someone wrote. So the depth
is bounded by the longest prefix in the clause set — and the bound is **per nesting level**, since
`list<list<int>>` has an outer depth and an inner depth that are independent and each follow their
own element type down.

### Subtraction

`A \ B` where `B` has prefix length L:

1. Unfold `A` to depth L.
2. Every closed spine shorter than L is disjoint from `B` — different lengths — so it survives whole.
3. The spine now at length L aligns with `B`. Subtract componentwise, which is `product_minus/2`
   over the prefixes (already written, already exact) plus the tail case:

| `A`'s rest | `B`'s rest | `A \ B` at that length |
|---|---|---|
| `closed` | `closed` | empty |
| `closed` | `{open, _}` | empty — an open spine at L includes length exactly L |
| `{open, TA}` | `closed` | unfold once and drop the closed part: `{P ++ [TA], {open, TA}}` |
| `{open, TA}` | `{open, TB}` | empty if `TB` covers `TA`; **otherwise keep `A`** |

That last fallback is the only inexactness, and it is deliberately in the **safe** direction. Every
spine a *pattern* produces has rest `closed` or `{open, any}`, because the marker binds without
constraining — so the fallback is unreachable from source and only a declared-type-minus-declared-type
comparison with incomparable element types can hit it. Under-subtracting makes a residual too
*large*, which reports a false "not exhaustive". Over-subtracting is what this feature exists to
delete.

### Rendering

`l_str/1` prints a spine as a writable clause head, which is the property that makes a residual
something you can paste:

| spine | prints |
|---|---|
| `{[], closed}` | `[]` |
| `{[int], closed}` | `[int]` |
| `{[int, int], {open, int}}` | `[int, int, ..]` |
| `{[], {open, any}}` | `list<term>` |
| `{[T], {open, T}}` | `list<T>` |

The last two are the folded forms, kept because `list<int>` should not print as `[] | [int, ..]`.

### Openness

`l_open/1` is true when any spine has an `{open, T}` rest with `T` inhabited. A union of purely
closed spines is closed — which is what makes the catch-all rule reach lists: over `list<bool>`, a
residual of `[{[bool], closed}]` is two values, closed, and `_` over it becomes an error naming
`[true]` and `[false]`.

## The gate comes first

`compiler/bin/check-list-length.sh`, written and **seen to fail** before any of the above is built.

Three probes, asserted on the diagnostic rather than the exit code, because `bsc` exits 0 on a
warning-only module — which is also why this is a gate and not a `<!-- check: -->` block in
LANGUAGE.md, since no doc block can assert the *absence* of a warning.

| probe | must produce | covers |
|---|---|---|
| `[]` + `[a, b, ..]` | inexhaustive, residual names `[int]` | over-subtraction — the crash |
| `[]` + `[a]` + `[a, b, ..]` | exhaustive and **silent** | composition — the under-subtraction |
| `[]` + `[a, b, ..]` + `[a, ..]` | **no** unreachable warning | symptom five |

**`--self-test` builds four controls.** Two of them are the defects: a checker crediting every cons
as all-non-empty fails probes 1 and 3 and passes 2; a checker crediting nothing for a cons fails
probe 2 and passes 1. **Each must be caught on a probe the other passes**, so no probe can be a
fires-on-everything check — one stub proves only that the gate sees one direction, and ticket 54's
standing warning is that the two directions have one root and get fixed independently. The third
control is the decided behaviour, which must pass. The fourth is a run that never compiled, and it
is there because the gate failed it — see item 5 below.

## What changes

1. **`bs_types`** — the spine, `unfold`, and the twelve touchpoints: `none/0`, `term/0`, `nil/0`,
   `cons/1`, `list/1`, `is_none/1`, `l_open/1`, `l_union/2`, `l_intersect/2`, `l_subtract/2`,
   `l_str/1`, and the two tag-discriminator clauses that pattern-match the old shape.
2. **`bs_parser.yrl`** — `plist_items -> '..' | '..' '_' | '..' lident`, the two fix-it error
   productions for the retired forms, and **the same restriction inside `to_match`**, which
   converts an expression list into a pattern for a destructuring bind and would otherwise leave
   `var [a, ..[]] = xs` legal where nobody looks.
3. **`bs_check`** — delete the `list_pattern_needs_rest` raise; `Rest = nil` now means *closed*.
   `pattern_type` for `p_list` credits per-prefix rather than `cons(term())`.
4. **`bs_diag`** — the residual prints as writable heads; the orphaned `list_pattern_needs_rest`
   message clause goes with its tag. **Ticket 54 said `check-diagnostics.sh` could not see this and
   was wrong** — measured here: its third section reports *"message/1 renders tags descriptor/2
   never mints"* and carries a control that builds that defect. The tag and its message have to go
   together, and the gate enforces it.
5. **tree-sitter** — `rest_pattern` becomes a marker, and `grammar.json`, `node-types.json` and
   `parser.c` are **regenerated**; they are committed, and editing `grammar.js` alone leaves three
   stale artifacts.
6. **The corpus** — `examples/exemplars/25a-http-api-server/route.bs` loses its four `..[]`
   clauses, and LANGUAGE.md's `Dispatch` block goes with them.
7. **A stale comment** — `test/lists_tests.erl:12-13` asserts *"Ticket 08 settled prefix-plus-rest
   only"*, now false. No gate reads a comment.

## Measured before this file was written

Recorded in ticket 54 and not repeated here, except for the two that set this feature's scope:

- **`yecc:file/2` reports 0 conflicts** on the current grammar, on the marker grammar, and on the
  marker grammar with the fix-it productions — against a control that reports 1 reduce/reduce, so
  the zeros carry information.
- **`[a, b]` already parses.** `plist_items -> pattern` yields `Rest = nil`; the refusal is one
  `erlang:error` in `bs_check`. Half of change 3 is a deletion.

## Measured during the build, not before it

Five things the decision did not know, each found by writing the code rather than by reading it.

**1. The list part was not private.** Ticket 54 scoped this as a change to `bs_types`. It is not:
`bs_check` and `bs_emit` pattern-matched the `{boolean(), elem()}` shape at **eight sites** —
`elem_of/1`, `opaque_refinement/1`, the emitter's spec writer, its validator walker, its runtime
clause generator, and two "holds no list at all" discriminators. They now ask `bs_types` for what
they wanted (`list_elem/1`, `has_lists/1`, `has_nil/1`, `has_cons/1`), which is the encapsulation
the old shape never had.

**2. THE `-spec` WIDENS, AND IT IS THE FIRST PLACE ANYTHING IN THIS COMPILER DOES.** Erlang's type
grammar has `nil`, `nonempty_list(T)` and `list(T)` and **no fixed-length list at all**, so a
residual the checker knows exactly — `[int]`, exactly one — leaves as `nonempty_list()` on the way
into a spec. Ticket 20's no-widening rule governs the **algebra**, which still does not widen; this
is the boundary where the algebra meets a target grammar that cannot say what it knows. Dialyzer
reads a spec as an upper bound, so a wider one is honest and a narrower one would be a lie.

**3. Ticket 54's claim about `check-diagnostics.sh` was false.** It said deleting
`list_pattern_needs_rest` would orphan its `message/1` clause where no gate could see it. The gate
checks **both** directions — *"message/1 renders tags descriptor/2 never mints"* — and carries a
control that builds that exact defect. The claim came from a summary rather than from the file, and
is corrected in the ticket.

**4. The tree-sitter grammar needed a new declared conflict.** Making `rest_pattern` a marker put
it in the same pattern-versus-expression overlap the grammar already declares for
`[$.list_pattern, $.list]`: `[.._]` is a pattern rest or an expression rest depending on where it
sits. One line, and the generator refuses any conflict it does not need — so the declaration is
itself a measurement.

**5. THE GATE'S OWN THIRD PROBE PASSED VACUOUSLY ON ITS FIRST REAL RUN.** Probe 3 asserts the
*absence* of an `unreachable` warning. Before the marker grammar existed, `[a, b, ..]` did not
parse — so there was no warning to find, and the probe reported green over a module that had never
been checked. That is `check-no-silent-skip.sh`'s failure one level up, in a gate written to be
careful. The fix is that an absence is now asserted against a **clean compile**, and the self-test
gained a fourth control that feeds it a run which never compiled and requires all three probes to
fire. **A gate is not believed until it has been seen to fail — and this one had to be seen failing
for the right reason, not merely failing.**

## Measured after the build, because a reviewer asked the right questions

**6. The switch arm shares the pattern grammar, and it was worth checking rather than assuming.**
Every probe and every test above goes through a function head — `walk/5`. Switch arms are a
*separate* residual loop, `arms/8`, and TOUR chapter 8 states the premise this feature depends on:
*"a switch arm is the clause head's own pattern grammar, one level down"*. Measured, and it holds:

```csharp
F(xs) -> xs switch { [] => :e, [a] => :one, [a, b, ..] => :m }    // exhaustive, silent
F(xs) -> xs switch { [] => :e, [a, b, ..] => :m }
//   error: this switch in F is not exhaustive
//     no arm matches:
//       [int] => ...
```

The arm names `[int]`, exactly as the head does, because `arm_type` routes through `pattern_type`.
**A compiler that proved length in heads and not in arms would be worse than one that proved it
nowhere**, because nobody would expect the asymmetry — so this is now covered by tests rather than
by the inference that it must work.

**7. TICKET 54'S PREDICTED COST DID NOT MATERIALISE, AND THE REASON IS THE REPRESENTATION.**
Decision 5 warned that the closed-residual rule *"multiplies against ticket 43's `?RESIDUAL_CASES`
cap: a four-atom union at length two is sixteen heads, so the cap starts doing real work rather
than being a formality"*. Measured over `type Q = :a | :b | :c | :d`, with clauses `[]` and
`[x, y, z, ..]`:

```
no clause matches:
  F([:a | :b | :c | :d] | [:a | :b | :c | :d, :a | :b | :c | :d]) -> ...
```

**Two spines, not sixteen products.** A spine holds a union *at each position* rather than
enumerating the cross-product, so the residual grows with the number of missing **lengths**, not
with the number of missing value combinations. The cap is untouched and the residual is still a
clause you can paste. The prediction was wrong in the harmless direction, and it is corrected here
rather than left standing.

**8. A destructuring bind refuses with the complement, and the complement is legible.** `[a, b]`
used to be a grammar error, so this path went from *refused outright* to *type-checked* with no
test on the way through:

```
error: this bind in F can fail
  the pattern does not match:
    [] | [int] | [int, int, int, ..]
```

Three spines: shorter, shorter, longer. That is the exact complement of exactly-two, and it reads
as one.
