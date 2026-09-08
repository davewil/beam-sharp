# F37 — a refined `int` parameter is inside its refinement, at the exported boundary

**Status**      **done 2026-09-08** — 10 new tests, 689 in the suite, up from 679.
                One new gate, `compiler/bin/check-boundary-range.sh`, with four
                stubs in its `--self-test`; `check-boundary-kind.sh` stands
                unchanged beside it, and the two are deliberately separate
                because each one's stub set is the other's blind spot
**Implements**  [ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md),
                resolved 2026-08-23 and never built. Through it,
                [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §1
                rule C case (b), §4 (exported only) and §5 (no opt-out)
**Closes**      [ENG-292](https://linear.app/davewil/issue/ENG-292/ticket-46s-range-half-classify300-on-an-octet-parameter-is-still)
**Decides**     nothing about the language. 46 §1–§4 settled emission, scope,
                failure mode and depth. **Two implementation choices are named
                here rather than left implicit**, because 46 did not reach them:
                a refinement with MORE THAN ONE range lowers to a disjunction of
                range tests rather than to its hull (§F37.8), and a clause that
                matches only integers outside the declared type — a vacuous
                clause, which the checker warns about and still compiles —
                carries every finite bound of the declared type, which is false
                for everything it can reach (§F37.8)
**Depends on**  F24, which built the *kind* half at this same site and whose
                `is_integer/1` this feature's comparisons stand behind; F2,
                which made a refinement spellable; F3's `boundary_guards/4`, the
                machinery, written for the record tag; F12 (`is_public/1`)

## The measurement

Before, on `examples/Wire`, whose three exported functions all declare `Octet`
and publish `-spec … (0..255)`:

```
$ bsc --src-root examples examples/Wire Classify 300   ->  :reserved
$ bsc --src-root examples examples/Wire Band -5        ->  :low
$ bsc --src-root examples examples/Wire Sizing 300     ->  :high
```

After:

```
$ bsc --src-root examples examples/Wire Classify 300   ->  crashed: error:function_clause
$ bsc --src-root examples examples/Wire Band -5        ->  crashed: error:function_clause
$ bsc --src-root examples examples/Wire Sizing 300     ->  crashed: error:function_clause
$ bsc --src-root examples examples/Wire Classify 255   ->  :reserved
$ bsc --src-root examples examples/Wire Band 0         ->  :low
$ bsc --src-root examples examples/Wire Classify 100.5 ->  crashed: error:function_clause
```

The last two lines are the ones that make the first three a measurement. `255`
and `0` are the inclusive edges of `Octet`, and `100.5` is F24's case: this
feature adds a bound, it does not replace the type test.

## What was actually missing

`300` is an integer, so F24's `is_integer/1` passed it. Nothing then asked
whether it was inside the domain the `-spec` advertises. The rule to ask that
was decided on 2026-08-23, written out clause by clause with a measured table,
and never reached the emitter — the same shape as F24, which found ticket 18's
rule decided ten days before it was built.

## F37.1 — the reported escape, above the domain

`Classify(>= 9)` accepts `int >= 9`. Subtracting `Octet` leaves `int >= 256`, so
the clause carries `=< 255` and nothing else:

```erlang
'Classify'(1)      -> method;
'Classify'(Bs@r1) when Bs@r1 >= 4 andalso Bs@r1 =< 7   -> reserved;
'Classify'(Bs@r1) when erlang:is_integer(Bs@r1)
                       andalso Bs@r1 >= 9
                       andalso Bs@r1 =< 255            -> reserved.
%%                                     ^^^^^^^^^^^^ this, and only this
```

The `>= 4 andalso =< 7` above it is F2's **relational pattern** — ticket 42's
lowering of `Classify(>= 4 and <= 7)` — and not a boundary guard. The
distinction matters to the gate, which counts comparisons and would otherwise
grade itself green on F2's work; `count_cmp` pins the right operand to the
domain bound for exactly that reason.

## F37.2 — the escape below the domain, which the ticket's own framing missed

46 §2: *"`Band(n) when n <= 64` emits the **lower** bound and is what catches
`Band(-5)`, which returns `:low` today: the ticket framed the question entirely
around values above the domain, and half the escapes are below it."*

Asserted separately from F37.1, and given its own gate probe, so that a fix
emitting only upper bounds — the shape 46's prose suggests before §2 corrects
it — is visible as a partial fix rather than as a pass.

## F37.3 — subtraction, and why it is asserted as a count

**This is the assertion behaviour cannot make.** A naive
two-comparisons-on-every-clause emission crashes on exactly the same inputs as
the decided one. Every behavioural probe passes under it. What separates them is
what the compiler *wrote*.

46 §2's table, rebuilt by this feature and asserted in both registers:

| Clause | accepts | escapes `Octet` | emitted |
|---|---|---|---|
| `Classify(1)` … `Classify(0)` (5 clauses) | `1`, `2`, `3`, `8`, `0` | — | nothing |
| `Classify(>= 4 and <= 7)` | `4..7` | — | nothing |
| `Classify(>= 9)` | `int >= 9` | `int >= 256` | `=< 255` |
| `Band(n) when n > 128` | `int >= 129` | `int >= 256` | `=< 255` |
| `Band(n) when n > 64` | `int >= 65` | `int >= 256` | `=< 255` |
| `Band(n) when n <= 64` | `int <= 64` | `int <= -1` | `>= 0` |
| `Sizing(n)` | `int` | `int <= -1 \| int >= 256` | `>= 0`, `=< 255` |

Six of eleven clauses carry nothing; the other five carry **six comparisons**
between them, against twenty-two for naive emission. Counting the emitted form
is a boundary assertion and not an implementation one: the emitted form is what
`--api` and the `-spec` are read at, and it is what the handoff ships.

**The emitter subtracts rather than testing a flag,** which is 46 §2's result
and the reason this is not a one-line addition beside `constrains_kind/1`. That
predicate is a boolean because a tag either is or is not constrained. A bound
can be **half** proved.

## F37.4 — `Possible`, not `Certain` — and what the measurement corrected

The checker computes two bounds per clause. `Certain` is what the clause
definitely matches; `Possible` is an upper bound on it. A guard the checker
cannot read credits `Certain = none`, deliberately, because crediting an unread
guard is what let `F(n) when Weird(n)` report as exhaustive (ticket 08). An
emitter subtracting the declared type from `none` finds nothing to emit, so the
clause loses its boundary guard entirely — the one direction a boundary must
never fail in. `Possible` over-approximates, so subtracting from it emits at
worst a redundant comparison and never a missing one.

The clause that puts the two apart is a guard the checker cannot read —
`bs_check:comparison/1` translates a variable against an integer **literal** and
nothing else, so `n > m` falls through to `unknown`:

```csharp
public int Foo(Octet n, Octet m)

Foo(n, m) when n > m -> 1
Foo(n, m)            -> 0
```

**This section first claimed that swapping `Possible` for `Certain` would let
`Foo(300, 1)` answer `1`, and that claim was reasoned rather than run. Measured
2026-09-08 by making the swap and rebuilding, it is false**: all ten tests and
all six gate probes stay green. `apply_guard/3` answers `{Ty, Ty}` or
`{Refined, Refined}` where it can read the guard and `{none, Ty}` where it
cannot, so `Certain` is either `none` or **identical** to `Possible` — never
something narrower in between — and `positions/2` answers `term` for an
uninhabited type. The unreadable clause comes out **over-guarded, not
unguarded**.

So the honest statement is two-part, and either half alone reads as a reason
while only the pair is one:

- `Possible` is the bound to name, because it is the one that is actually an
  upper bound on what the clause matches, and it does not depend on a fallback
  to be right.
- **`positions/2` mapping an uninhabited type to `term` is what carries the
  safety**, and it is now commented as a decision rather than left as the
  incidental behaviour of an empty product list.

The gate's `CERTAIN` stub stays, and what it checks is now stated accurately: it
is a check on an emitter **this compiler does not have** — one that reads
`none`'s empty integer part and concludes nothing is owed. That emitter is one
edit away, in `positions/2`, which is exactly the kind of edit a later reader
makes while tidying a fallback that looks incidental.

## F37.5 — exported only, and the asymmetry with the record tag

46 §1, on 18 §4: rule C *"looks at the exported function's own clause heads and
body, and no further"*. A private function's every call site is a checked B#
call site, so site 1 has already refused the out-of-domain argument.

This matches F24's `is_integer` and deliberately **not** the record tag test,
which is emitted on private functions too — an asymmetry 46's *Corrections*
recorded as measured (`boundary_guards/4`'s comment says exported-only and
nothing consults `is_public/1`). That asymmetry is
[ticket 59](../../wayfinder/issues/59-boundary-guard-scope-asymmetry.md) /
[ENG-241](https://linear.app/davewil/issue/ENG-241)'s question, and this feature
neither settles nor worsens it.

## F37.6 — a plain `int` owes nothing

`int` is unrefined: its bounds are `neg_inf` and `pos_inf`, so there is no
comparison to make and F24's type test is the whole of the boundary. Asserted
because a guard that fired on every `int` parameter would pass every probe above
while putting two dead comparisons on every exported call in the corpus.

## F37.7 — a union parameter carries nothing, and the reason is term order

`Octet | :none` is not int-only, so no range guard is emitted — the same gate
F24 puts on `is_integer`.

**This is not merely consistency.** Erlang's term order puts atoms above every
number, so `none =< 255` is **false**. A comparison emitted without the int-only
gate would refuse a legitimate `:none` caller at a parameter that declares it.
The guard is admissible only where the declared type has no other kind in it,
and the reason is recorded here rather than inferred from F24's precedent.

## F37.8 — two ranges, and the two implementation choices this feature names

`int where value < 0 or value > 10` resolves to **two** ranges, and the language
admits it today — measured, not assumed:

```
{type,0,union,[{type,0,neg_integer,[]},{type,0,integer,[]}]}
```

Ticket 20 §5 puts a guard-decidable refinement in the O(1) tier, and this one
still is: a disjunction of range tests decides it in constant time. So it is
inside 46's scope rather than beside it, and it lowers to
`(V >= a andalso V =< b) orelse (V >= c andalso V =< d)` rather than to its
hull. Collapsing to the hull would admit every value in the hole between the
ranges, which is the whole content of such a refinement.

**Interior bounds are never dropped.** Only the lowest range's lower bound and
the highest range's upper bound may be, and only where the clause head admits no
integer on that side. That is what keeps `wire.bs` at six comparisons while
leaving this shape correct.

**A vacuous clause carries every finite bound.** `Grab(>= 300)` on an `Octet`
parameter matches no value of its input; the checker says so as a **warning**
and the module still compiles. Its intersection with the declared type is empty,
so there is nothing to subtract from — and the emitter writes the declared
type's own bounds, which are false for every integer that clause can reach. The
clause is dead for valid input and the guard says so, rather than the clause
becoming the one unguarded door in the module.

## F37.9 — the switch subject is guarded at the head, not in the arms

`Sizing(300)` returned `:high`. The escape is at the **clause head**, whose
pattern is a bare variable declared `Octet`; by the time the subject reaches an
arm the head has proved it is an `Octet`. Nothing in `arm/2` changed, and this
section exists so a later reader does not go looking for a second emission site
there — ENG-330 amended `arm/2` for its own reason and this is not it.

## The compiler delta

- **`bs_check:clause_accepts/2`**, exported beside `resolve/2`. One call into
  the existing `clause_type/2`, returning `Possible` split per parameter
  position. `positions/2` unions across products where an `or` guard produced
  several, which drops the correlation between positions and so can only widen
  a position — a comparison added, never one removed.
- **`bs_emit:owed_arms/3`**, beside `constrains_kind/1` as 46 predicted, plus
  `trim/2`, `bounds/3`, `has_below/2`, `has_above/2` and `range_test/3`.
  Everything it needs already existed: `bs_types:subtract/2`, `intersect/2`,
  `range/2` and `is_none/1`.
- **`int_guard/6`** now decides two things where it decided one, and emits the
  type test **before** the comparisons. The order is load-bearing rather than
  tidy: a comparison against a non-number is not an error in Erlang, it is a
  silently wrong answer, so a range test is only meaningful once the type test
  standing before it has short-circuited.

## Done when

- [x] `Classify(300)`, `Band(-5)` and `Sizing(300)` are refused at the boundary
- [x] `Classify(255)`, `Band(0)` and `Sizing(0)` — the inclusive edges — answer
- [x] `Classify(100.5)` is still refused, so F24 is intact
- [x] six comparisons over `wire.bs`, not twenty-two, asserted as a count
- [x] a clause whose guard the checker cannot read is guarded anyway
- [x] a private function carries none
- [x] `check-boundary-range.sh` seen red first, and its `--self-test` catches
      a silent emitter, the naive form, an upper-bounds-only fix and the
      `Certain` reading, each on a different probe

## What this does not build

**Not the projection cases.** 46 §4 guards a refined `int` wherever a **fixed
number of projections** reaches it — a whole parameter, a tuple element, a
record field. This feature builds the **whole parameter** only, which is what
closes all three measured escapes and is F24's scope at the same site. The
record-field case attaches where the tag test already emits its `map_get` at
that depth (26 §7); the tuple-element case attaches where the clause pattern
already binds the element. Both are owed, and neither is a decision — 46 §4
settled them.

**Not `atom` or `binary` kinds.** F24's *"Only `int` so far"* is unchanged.

**Not the O(n) tier.** `binary where valid_utf8` is 20 §5's second tier, barred
from a foreign declaration by F9.11, and a `list<Octet>` is O(n) in a length the
foreign caller chooses — ticket 11's refusal at a third site, and 46 §4's
explicit exclusion.

**Not inspectability.** Failure is `function_clause`, matching the record tag
test, per 46 §3. A `function_clause` on `Classify/1` does not say *"300 is not an
`Octet`"*; that is ticket 23's question, handed to it by 18 §7, and this feature
adds a second instance to it rather than inventing an error channel beside it.
