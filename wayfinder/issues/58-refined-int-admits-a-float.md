# 58 — A refined `int` parameter admits a float

Status: resolved 2026-08-23, built as [F24](../../compiler/features/F24-boundary-kind.md) — [ENG-240](https://linear.app/davewil/issue/ENG-240)
Raised by: ticket 46, 2026-08-23, while resolving the boundary guard for a refined integer
Blocks: nothing. It makes ticket 46's guard sound rather than half-sound
Type: `wayfinder:defect` — decided and unbuilt, not undecided

## The measurement

`examples/Wire/wire.bs` declares `type Octet = int where value >= 0 and value <= 255` and
`public FrameType Classify(Octet)`. The emitted `-spec` says `0..255`.

```
$ bsc examples/Wire/wire.bs Classify 100.5
:reserved
$ bsc examples/Wire/wire.bs Classify 300.5
:reserved
$ bsc examples/Wire/wire.bs Band 100.5
:mid
```

A float reaches a parameter whose published type is a range of integers, and a value comes back.
No crash, ever — ticket 18's **outcome 3**, the one it calls *"the only outcome that makes the type
system a lie"*.

## Why this is a defect and not a question

**Ticket 18 §1 decided it on 2026-08-13, and §5 refused an opt-out.** Its rule C, case (b), is this
case with the refinement removed:

```csharp
int Add(int a, int b);
(a, b) -> a + b;
```

> `add(A, B) -> A + B.`  — what C refuses to ship, because `add(1.5, 2.5)` returns `4.0`
> `add(A, B) when is_integer(A), is_integer(B) -> A + B.`  — what C emits

A refined `int` is an `int` parameter, so nothing about the refinement changes which case applies.
The emitter does not emit the type test. **Nothing here needs deciding; the decision is not in the
compiler.**

Ticket 46 raised this rather than absorbing it because 46's own scope note — *"not `is_integer/1` in
general… 18's standing question about every parameter, deliberately not reopened"* — is correct.
This is not a general question. It is one resolved rule that is missing from `bs_emit`.

## Why ticket 46's guard does not cover it

**Comparison operators are not type tests.** Measured on OTP:

```erlang
100.5 >= 0 andalso 100.5 =< 255.   %% true
foo >= 0.                          %% true   — number < atom in term order
foo =< 255.                        %% false
```

So 46's **specified** `Bs@r1 >= 0 andalso Bs@r1 =< 255` narrows *within* the numeric tower and does
not close it. `Classify(100.5)` passes a range test written for `Octet` and is still not an `Octet`.

<!-- Corrected 2026-08-23 while resolving this ticket: "emitted" -> "specified". -->
**Ticket 46's guard is not emitted, and was not when this ticket was written.** Measured at
`2b97180`: the `Bs@r1 >= 4 andalso Bs@r1 =< 7` in `Wire`'s emitted heads is F2's **relational
pattern** (ticket 42's lowering, shipped 2026-08-15), and there is no `>= 0 andalso =< 255`
anywhere in the module. Ticket 46 is a decision resolved the same morning, with no feature file and
nothing built. The argument below is unaffected — a comparison would still not be a type test if it
were emitted — but this ticket was not adding a half beside an existing one. **Both halves were
unbuilt, and F24 built this one first.**

Where a wrong-kind term happens to be excluded today — an atom failing `=< 255` — it is BEAM term
order doing it, which is an accident of the ordering rather than a check. 18 §1 already refuses to
rest on that: outcome 3 is *"only where a wrong term traverses the entire body without meeting an
operation that objects"*, and a comparison does not object, it orders.

So the two are one guard in two halves, and 46's half is the second one: **`is_integer/1` first,
then the residual comparisons.** Emitting either alone leaves a channel open.

## What this owes

1. **Which parameters.** 18 §1 rule C with §4's function-local analysis already answers it, so this
   is a question of reading the rule onto the existing emitter rather than a new judgement. The
   census 18 measured is the cost bound.
2. **Whether the existing float behaviour is load-bearing anywhere.** `Fib` and the arithmetic
   examples pass integers; nothing in the corpus is known to depend on a float reaching an `int`
   parameter, but that is an assumption until the suite is run against the change.
3. **The gate.** Per the working rule, the failing test and the gate come before the
   implementation, and the gate must be seen to go red. The defect it names is exactly the run
   above: an exported function with a declared `int` parameter accepting a float.

## Cross-references

- **[Ticket 18](18-boundary-defence.md) §1(b)** — the decision, and §5 for no opt-out.
- **[Ticket 46](46-refined-parameter-at-the-boundary.md)** — the refinement half of the same guard,
  resolved 2026-08-23, whose soundness depends on this.
- **[Ticket 06]** — the origin of outcome 3 and of `add(1.5, 2.5)` returning `4.0`.
- **A correction 46 hands ticket 18**: its census counts a parameter defended if every clause
  *"constrains it structurally or mentions it in a guard"*. `Classify(>= 9)` does the latter and
  admits both `300` and `100.5`, so the census overstates how defended a relational pattern is.

---

# Resolved — 2026-08-23, built as [F24](../../compiler/features/F24-boundary-kind.md)

**`erlang:is_integer/1` is emitted in the clause head of an exported function, on every parameter
whose declared type is int-only, unless that clause's own pattern already pins the kind.**

```erlang
'Classify'(1) -> method;                                   % the literal pins it — nothing added
'Classify'(Bs@r1)
    when erlang:is_integer(Bs@r1) andalso                  % <- this
         Bs@r1 >= 4 andalso Bs@r1 =< 7 -> reserved;
'Classify'(Bs@r1) when erlang:is_integer(Bs@r1) andalso Bs@r1 >= 9 -> reserved.
```

```
$ bsc --src-root examples examples/Wire Classify 100.5
crashed: error:function_clause
$ bsc --src-root examples examples/Wire Classify 100
:reserved
```

Nothing was decided here. 18 §1 rule C case (b) is the rule, §4 scopes it to the exported function,
§5 refuses the opt-out, and 18 §1(a) is why a literal clause gets nothing. 492 tests, nineteen
gates, Dialyzer clean, and the corpus diff is 34 guard insertions across 9 of 15 modules and
nothing else.

## The one finding worth carrying forward

**A range subtraction does not fix this, and would have looked like it did.** `100.5` reaches the
`Classify(>= 9)` clause, so ticket 46's `P \ D` yields `=< 255` there — and `100.5 =< 255` is true.
A range-only fix crashes `300.5` and leaves `100.5` answering `:reserved`: the reported defect,
unmoved, with the *easier* half of it fixed. `300.5` is the value that reads like the natural probe
and it is the wrong one. `check-boundary-kind.sh` probes on `100.5`, and its self-test carries a
RANGE stub — 46's answer implemented exactly — that it must catch.

**A comparison proves ordering, not kind** is the sentence the whole feature reduces to.

## What is still open, and none of it is this ticket's

- **Ticket 46's range half is unbuilt.** `Classify(300)` — an out-of-range *integer* — still
  returns `:reserved`. 46's answer specifies it completely.
- **The other kind channels.** `atom`, `binary`, `tuple` and `list` are the same rule with a
  different test, owed rather than decided differently.
- **An `int` below the top of a parameter.** `handle_call({add, N}, _From, State)` guards `State`
  and not `N`, so a float reaches `State + N` one projection deep. 46 §4 already decided this
  should be reached.
- **The record tag guard is still emitted on private functions** while this one is exported-only,
  so `boundary_guards/5` now applies two rules with different scopes. 46 measured that and left it;
  it is worth a ticket and does not have one.
