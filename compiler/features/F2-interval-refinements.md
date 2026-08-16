# F2 — Interval refinements, and the interval patterns that must land with them

**Status**      **done 2026-08-16** — all five scenarios pass, 249 tests, 8 gates green
**Implements**  tickets 20 §5, 12 §2, 04, 42, 43, **44** — decides nothing
**Unblocks**    `bs_emit:int_part/1`'s bounded branches; wire dispatch in 25b and 25c
**Depends on**  F1 only. 42 and 44 answered 2026-08-15, **43 answered 2026-08-16**
**Raises**      [ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md) ·
                [ENG-218](https://linear.app/davewil/issue/ENG-218) — a refined parameter is not
                checked at the exported boundary

## What building it found

**Ticket 12 §2 reaches further than its own examples suggest, and that is the finding.** §2
illustrates a closed residual with a declared union of atoms — `type Event = :placed | :shipped |
:cancelled` with two handled. Its **operative** definition is different and wider: *contains an
unbounded top*. After two guards over a bare `int` the residual can be `0..0` — one integer, no
top, **closed** — so `_ => :zero` is now an error where `0 => :zero` is not. The rule was
therefore reachable before this feature and nothing had asked. Two switch tests moved; the shipped
corpus has **zero** all-wildcard clauses and lost nothing.

**What counts as a catch-all had to be pinned, and `_` is it.** 12 §2 says *"`_` here is an error:
name the case"*, and taking that literally is what keeps the rule usable: `_` discards the value,
while a named binder buys almost nothing over a closed union, because projecting a field off it is
site 3 and is refused until you have discriminated. The alternative — treating a bare name as a
catch-all — makes every single-clause function over a record type an error.

**The grammar gives nested relational patterns away for free.** `pat_field -> uident ':' pattern`
and `pattern -> '(' pattern_list ')'` both admit one a level down, and the algebra handles it
correctly. Out of scope below says F2 ships the parameter position only, so it is **refused with a
message that names it as a scope call** rather than left to work by accident. Shipping a capability
nothing tests because two productions happened to compose is how a language acquires behaviour
nobody decided on.

**Ticket 43's head-counting half was needed immediately, not after 23 §2.** §3's table puts it in
the future tense — *"after §2 it enumerates one head line per case"* — and §3's own justification
for having that half is what makes it reachable today: *"a residual over a two-argument function is
a product, so the head count is the product of the parts."* `heads/2` has always printed one line
per product, so a second argument is the whole trigger. Measured: forty singleton clauses over
`(int, atom)` printed **41 head lines**, one of them itself truncated. Both units are live at once
now, which is what *"at most three of whatever it is enumerating"* means when the printer
enumerates two things at two depths. §2 will change what fills the sequence and nothing else.

**`25c_residual_probe.sh` had been dead since the `;` terminator was dropped**, so F2's own *Done
when* named an artefact that could not run. Repaired, and given the two probes this feature makes
writable — plus one correction: its probe 3 wrote `Classify(t)`, a bare **name**, and asked whether
a catch-all was refused. It never was and should not have been.

**The editor token gate was red on `var`**, which F8 shipped without a rule in either grammar;
`and`, `or` and `where` "passed" only by matching prose inside the JSON. All four now have real
keyword rules. `editor/bin/check-corpus.sh` is still red on `label.bs` — the tree-sitter grammar
has no string-literal rule and F9 shipped strings. Neither editor gate is in CI. That is F9's debt
and it is named rather than absorbed.

**The header said `not started` until 2026-08-15 while the README's table said `blocked`.** Two
files disagreed about whether this feature was takeable, and the table was the one that was right —
a session picked the feature up on the header's word and had to be turned round. The status line of
a feature file is the thing an agent reads first, so it is the thing that must not lie.

## Why this one now

The skeleton's README names it: *"a parameter declared `int` emits `integer()` whatever its clauses
test. The surface owes ticket 20 §5's `type Positive = int where value > 0;`. **That is the next
slice increment.**"* Intervals are already in the algebra and the checker already uses them — this
feature is surface and emission, not new theory, which makes it the cheapest real increment
available.

## The coupling that makes this one feature and not two

**Recorded in 25c and in neither ticket.** Today a parameter declared `int` has an **open**
residual, so a wire-format dispatch gets its catch-all for free. Measured against the skeleton by
[`25c_residual_probe.sh`](../../wayfinder/prototypes/25c_residual_probe.sh):

- four named frame types over a bare `int` → residual `int <= 0 | 4..7 | int >= 9` — **open**;
- the same plus a guard bounding the octet to `0..255` → residual `int <= -1 | int >= 256`,
  **values the wire cannot produce**, still open.

The moment `type Octet = int where value >= 0 && value <= 255;` lands, every wire dispatch acquires
a **closed** residual — 252 unnamed values for an AMQP frame type, ~2³² for a class/method pair —
and ticket 12 §2 makes a catch-all over a closed residual an **error**. So refinements *without*
interval patterns turn working programs into rejected ones.

**Therefore both halves ship together or neither does.** This is the feature-file rule from the
features README, and it is here because it was learned rather than assumed.

## Scenarios

### F2.1 — a refined type is declared and narrows the emitted spec

Input:

```csharp
module Wire

type Octet = int where value >= 0 && value <= 255

Octet Clamp(Octet)

Clamp(n) -> n
```

Expect: compiles, exit `0`, and the emitted `-spec` says `0..255` rather than `integer()`. This is
the scenario that makes `bs_emit:int_part/1`'s bounded branches reachable — currently dead code
that the unit suite cannot cover.

### F2.2 — a refinement closes the residual, and an unnamed case is an error

Input: a function over `Octet` naming four values with a `_` catch-all.

Expect: **error**, exit non-zero, ticket 12 §2's closed-residual rule firing. This is the scenario
that would silently break 25c if F2.3 did not exist — worth running *before* F2.3 to see the
failure it prevents.

### F2.3 — an interval pattern names a span of cases in one clause

Input:

```csharp
FrameType Classify(Octet)

Classify(1)              -> :method
Classify(2)              -> :header
Classify(3)              -> :body
Classify(8)              -> :heartbeat
Classify(0)              -> :reserved
Classify(>= 4 and <= 7)  -> :reserved
Classify(>= 9)           -> :reserved
```

Expect: exhaustive, exit `0`, emitting `classify(N) when N >= 4, N =< 7 -> reserved;`.

**The spelling is settled — [ticket 42](../../wayfinder/issues/42-interval-pattern-spelling.md),
resolved 2026-08-15.** It is a **relational pattern**, and `4..7` was refused. C#'s `..` builds a
half-open slice over *indices*, is not enumerable, and in pattern position already means "the rest"
— which this language took in 28 §5 and runs today as `Reverse([x, ..rest], acc)`. So the range
spelling was never the tier-1 borrow it looked like, and the inclusive/half-open question it seemed
to pose does not exist.

**This scenario gained a sibling obligation.** F7 recorded `{ Total: > 100 }` as *"a C# relational
pattern, which this grammar does not have"*; this is that construct. Whether it nests inside record
patterns immediately is a **scope call for this feature**, not a further decision — see Out of
scope.

### F2.4 — the residual stays legible at width

25c measured that 40 singleton clauses produce a residual of **41 disjoint intervals on one line**.
Re-measured 2026-08-16 by [`43a`](../../wayfinder/prototypes/43a_residual_at_width.escript): it is
**453 characters**, and it is **one** head rather than 41 — `heads/2` splits on the tuple part, so a
union of intervals stays inside one argument.

**Settled by [ticket 43](../../wayfinder/issues/43-residual-summarised-form.md), 2026-08-16.** The
prose prints the exact residual **truncated at three of whatever it is enumerating**, then
`... (K more)`. It is not a second format, so at three items or fewer it prints byte-identically to
today — no threshold to tune, no switch to explain. Nothing else summarises: not the term (ticket 23
§4's descriptor is unchanged), not the synthesised head, and no complement is computed.

**The unit is stage-dependent and this feature is on the first stage.** Before 23 §2's lowering the
printer enumerates **intervals inside one argument of one head line**, so that is what three counts
here. After §2 it enumerates **head lines**, and three counts those. 43 §3 carries the table and the
reason the distinction is not pedantic.

Input: 40 clauses naming `10, 20, … 400` over a bare `int`.

Expect: **error**, exit non-zero, and the head line exactly

```
    Classify(int <= 9 | 11..19 | 21..29 | ... (38 more)) -> ...
```

**The unit switches to heads once 23 §2 lands, and that half outlives this feature**: a residual
over two arguments is a product, so an interval rule would print an unbounded number of lines the
moment a second argument had a residual too. Implement the truncation over the *rendered sequence*
rather than over intervals specifically, and §2 costs nothing here.

**The one thing 43 defaulted rather than settled**, recorded here because F2 is what creates the
case: over a **closed** residual, ticket 12 §2 bars the catch-all, so every truncated head is a
clause somebody must still write. 43 truncates anyway — the term keeps all of them and 23 §10's
`bsc --api` is the full-fidelity channel. If that flips, the delta is one argument to `heads/2` and
**nothing in this feature changes**.

### F2.5 — a guard refinement and a type refinement agree

A function whose parameter is `Octet` and whose clause also guards `when n > 128` must not
double-count: the residual after that clause is `0..128`, not `int <= 128`.

## Out of scope

**Opaque (O(n)) refinements.** Ticket 20 §5 as amended by ticket 29 permits users to declare them
but **bars them from clause heads and foreign declarations**, so they need a check site the surface
does not yet have — and ticket 29 left three things owed on exactly that (whether the compiler may
call user code at a boundary, a spelling for the check site, what happens when the predicate
raises). Guard refinements only, here.

Also out: `string`'s UTF-8 refinement, which is the compiler-known opaque one and belongs with
binaries (F6).

**Relational patterns nested inside record patterns are OUT, and this is a scope call rather than a
decision.** Ticket 42 supplies the construct F7 wanted for `{ Total: > 100, Status: :open }`, and it
is tempting to take both positions at once. F2 ships it in the **parameter position only** — a
relational pattern where a whole argument goes. Nesting it inside a record pattern multiplies the
check sites F5 enumerated and is not needed by any exemplar, so it is a later feature that will cost
one grammar rule and no new theory. Recorded here so the omission reads as chosen rather than
forgotten.

## Two decisions this feature needed before it could be built

Both were tickets, not features. **All three are answered and the feature is built.**

1. ~~**The spelling of an interval pattern** (F2.3)~~ → **ANSWERED 2026-08-15**, a relational
   pattern: [ticket 42](../../wayfinder/issues/42-interval-pattern-spelling.md) ·
   [ENG-212](https://linear.app/davewil/issue/ENG-212)
2. ~~**The residual's summarised form at width** (F2.4)~~ → **ANSWERED 2026-08-16**, the exact form
   truncated at three cases: [ticket 43](../../wayfinder/issues/43-residual-summarised-form.md) ·
   [ENG-213](https://linear.app/davewil/issue/ENG-213)
3. ~~**And a third arrived with the first one's answer.**~~ → **ANSWERED 2026-08-15**, and it
   flipped the spelling: [ticket 44](../../wayfinder/issues/44-conjunction-spelling.md) ·
   [ENG-215](https://linear.app/davewil/issue/ENG-215). **One conjunction, `and`/`or`, in every
   position — `&&`/`||` are removed, not kept as synonyms.**

   **So this feature inherits a migration it did not have yesterday, and it must run in a specific
   order.** `LANGUAGE.md` is gated *bidirectionally*, and the compiler does not lex `and` today, so
   editing the doc first turns the gate red. **Lexer, then parser, then the doc and `math.bs`, in
   one change.** The keywords are already this feature's obligation — ticket 42 makes it reserve
   `and`/`or` for the pattern combinator regardless — so 44 adds a parser rule and three call sites,
   and *removes* two lexer rules. Every scenario in this file is written with `&&` and must be
   rewritten before it is implemented.

**Raised 2026-08-15, and they should have been raised when this file was written.** F2.3 already
said *"raise a ticket before writing this scenario's implementation"* and F2.4 said *"also a ticket,
not a feature"* — but neither was raised, so for a day this file recorded two blockers that existed
nowhere a query could find them. The feature itself is now
[ENG-214](https://linear.app/davewil/issue/ENG-214), blocked by both, so the frontier renders in
Linear rather than only in prose here.

## Done when

`bs_emit:int_part/1`'s bounded branches are reachable from a `.bs` file and covered by a boundary
test; a closed residual over a refined integer type is an error; an interval pattern discharges
one; and `25c_residual_probe.sh` reports a **closed** residual that the exemplar can name.

**All four met, 2026-08-16.** The spec for `Clamp(Octet)` says `0..255` and no longer says
`integer()`; `compiler/test/intervals_tests.erl` carries all five scenarios plus the rejections;
`examples/wire.bs` is the runnable version and works at the `ibs` prompt as well as through `bsc`;
and the probe's new 2c reports `Classify(0 | 4..7 | 9..255) -> ...` where 3b, the same program with
the span pattern, compiles clean.

**And the one thing it does not do**, which is why it raises a ticket rather than deciding: nothing
checks a refined parameter at the **exported boundary**. `Classify(300)` called from Erlang — or
from the `ibs` prompt — matches `>= 9` and returns `:reserved`, outside the `Octet` its signature
declares. Internal call sites are checked at site 1, so this is not a hole in the language; it is
the *"forging the tag is caught, forging the payload is not"* limit ticket 18 already measured,
arriving on a new shape. 18 calls emitting the check at the boundary *"genuinely optional"* — a
decision — and 20 §5 makes this refinement O(1) guard-decidable, so the check is cheap and the
question is real. [Ticket 46](../../wayfinder/issues/46-refined-parameter-at-the-boundary.md).
