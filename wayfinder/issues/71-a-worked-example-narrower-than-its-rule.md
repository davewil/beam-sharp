# 71 — A worked example narrower than the rule it illustrates

Type: spec shape
Status: claimed — [ENG-348](https://linear.app/davewil/issue/ENG-348). Raised 2026-09-10 by the
round 3 clean-room audition
Blocked by: —

## Why this is raised now

The [round 3 audition](../../handoff/audition-switch/evidence/2026-09-09-round3-nine-tags/NOTES.md)
ran five engines against the packet on 2026-09-09. Two of them — `github-copilot/claude-sonnet-5`
and `github-copilot/claude-haiku-4.5` — scored a **perfect 13/13 on the visible set** and then
failed `h11-vacuous-arm`, both answering *clean* where the compiler says `vacuous_arm`.

Several workers missing the same clause is the audition's own definition of a hole in the
specification rather than a weak worker. **This is the second instance of one shape**: round 1's
`c07` finding, where §5 illustrated a guarded arm with a form §2's rule forbade, and *"all three
candidates had §2's rule in front of them and reproduced the illustration"*. There the example
**contradicted** the rule. Here it is narrower than the rule, which is quieter and was not caught by
the fix for the first one.

## The compiler has no defect here — measured 2026-09-10 at `6fef958`, run rather than inferred

Vacuity fires identically whatever the subject's type is, and the message names the subject
correctly in every case:

```csharp
public atom Bucket(int n)
Bucket(n) -> n switch { :small => :s, _ => :other }      // vacuous_arm — "the subject's type is int"

public atom F(atom a)
F(a) -> a switch { 1 => :one, _ => :other }              // vacuous_arm — the converse also fires

public atom H(string s)
H(s) -> s switch { :nope => :n, _ => :other }            // vacuous_arm — "the subject's type is string"

type Verdict = :pass | :fail                             // §5's own example
public int Score(Verdict v)
Score(v) -> v switch { (:pass, n) => n, :pass => 1, :fail => 0 }
                                                          // vacuous_arm — "the subject's type is :fail | :pass"
```

Four subjects — a primitive `int`, the open `atom` universe, `string`, and a declared union — one
rule, one diagnostic, one message shape. **There is nothing to fix in `bs_check.erl` and no
compiler delta is proposed by this ticket.**

### One measured interaction, because it is a trap for whoever writes the example

A closed type does **not** reach the vacuity check at all:

```csharp
public atom G(bool b)
G(b) -> b switch { :maybe => :m, _ => :other }
```

→ `error: G discards cases the compiler can name … :false | :true`. The catch-all-over-closed
refusal fires first and the vacuous arm is never reported. So `bool` is the wrong subject for a
second demonstration, and choosing it would produce an example that silently teaches a different
rule. `int`, `string` and `atom` all work.

## What §5 actually shows

One worked example, and its subject is a **declared** union whose members are written three lines
above the switch:

```csharp
type Verdict = :pass | :fail

public int Score(Verdict v)

Score(v) -> v switch {
    (:pass, n) => n,
    ...
```

The prose is general and correct — *"the arm's pattern is not a member of the subject's type at
all"* — and goes on to explain the tagged-union reading error the example is built around. A reader
building a checker from this generalises from the executable half: they implement membership
against types the file declares, and never think to ask it of `int`. That is precisely what both
failing engines produced.

`h11-vacuous-arm` is `:small` against `int`, where nothing in the file enumerates the subject.

## Round 5, 2026-09-10 — a reader that reached the rule and still got it wrong

`h11` has now failed in **three consecutive rounds across four models**, and the
newest failure is a different mistake from the first three:

| round | model | answer on `h11` |
|---|---|---|
| 3 | Claude Sonnet 5 | `clean` |
| 3 | Claude Haiku 4.5 | `clean` |
| 4 | Claude Haiku 4.5 | `clean` |
| **5** | **`gpt-5.6-terra`** | **`unreachable_arm vacuous_arm`** |

The first three never reached the rule over a primitive subject at all. **`terra`
reached it** — it found the vacuous arm — **and could not tell the three dead-arm
diagnostics apart**, emitting a sibling rule's tag beside the right one. It was the
only held-out case `terra` missed, on a run where it otherwise scored 11/12.

**This adds a second axis to the question below.** §5 gives `unreachable_arm`,
`vacuous_arm` and `unsatisfiable_arm_guard` one worked example each and states in
prose that they are three different mistakes with three different repairs. A
capable reader still emitted two of them for one arm. So the deficiency may not be
that the examples are too few or too narrow, but that **three sibling rules are
each demonstrated alone and never against each other** — a reader is given three
positive instances and no contrast, and has to infer the boundaries.

That is a different repair from adding a primitive-subject example, and the two
may not both be needed. It is recorded here rather than acted on because this
ticket is the one that decides it.

**A cut worth knowing about.** A paragraph explaining the three dead-arm rules was
drafted for `PACKET.md`'s brief on 2026-09-09 and deliberately removed, on the
grounds that §5 already draws the distinction and coaching in the brief makes
rounds non-comparable. That decision stands, and `terra`'s answer is the evidence
it was cut against — a round that restores it would measure the coaching rather
than the specification.

## The question

**Does a diagnostic owe a worked example per type-shape it can fire over, or one per rule?**

The audition is now evidence on the question rather than an opinion about it: the rule was stated
generally, exercised narrowly, and two independent readers implemented the narrow version. The same
under-teaching would apply to any diagnostic whose §5 example happens to sit on a declared type —
this ticket asks the general question and `vacuous_arm` is the instance that raised it.

Answering *one per rule* is a real answer, and it costs nothing to hold: it makes the rule's wording
the contract and the example purely illustrative, and it accepts that a clean-room reader may
implement the narrow reading. Answering *one per shape* grows §5 and needs a stopping condition —
`vacuous_arm` alone would owe a primitive subject and a declared one, and possibly the `atom`
universe.

## What is not being asked

Whether `vacuous_arm` is the right diagnostic, or whether the compiler should fire it over
primitives. It does, consistently, and that is settled by the measurement above.

## What the failing checkers did — read 2026-09-17

The evidence directories keep each worker's `switchcheck`, so the two failure modes can be read in
code rather than inferred from answers.

**Haiku 4.5, round 3, answered `clean`.** Its vacuity check
(`evidence/2026-09-09-round3-nine-tags/copilot-haiku45/switchcheck:327`) opens:

```python
# Only check closed types
if not is_closed or cases is None:
    return

# Tuple pattern is vacuous if subject isn't a tuple type
if pattern.startswith('('):
    # Subjects are not tuple types in these examples
    # Actually, looking at c12: the subject is Verdict = :pass | :fail
```

It built the rule from `c12`, which is §5's `Score` example, and skipped any subject the file does
not enumerate. Sonnet 5's `switchcheck` is a three-line wrapper around a `switchcheck.py` that was
not kept, so only its answer is evidence.

**terra, round 5, answered `unreachable_arm vacuous_arm`.** Its checker branches on the subject's
type. In the `union` and finite branches the unreachability test is an `elif` after the vacuity
test, so a vacuous arm is never also unreachable. In the `int` branch
(`evidence/2026-09-10-round5-midtier-passes/codex-terra/switchcheck:559`) it is not:

```python
intervals = arm_intervals(pattern, guard)
if intervals == [] and not (guard and guard_intervals(guard) == []):
    tags.add("vacuous_arm")
    arm_blocking_error = True
if guard and guard_intervals(guard) == []:
    tags.add("unsatisfiable_arm_guard")
    arm_blocking_error = True
elif intervals is not None:
    if not interval_subtract(intervals, covered_intervals):
        tags.add("unreachable_arm")
```

`:small` against `int` gives `intervals == []`. The `elif` hangs off the guard test, not the
vacuity test, so it runs; `[]` is not `None`, and nothing minus the covered intervals is nothing.

An arm that matches no value is trivially covered by the arms before it. terra got that right
twice and wrong once, in the branch no visible case reached.

**What the compiler does.** `redundancy/4` in `bs_check.erl:4941` asks three questions in a fixed
order and reports the first failure: is the pattern in the subject's type (`vacuous_arm`), does
the guard admit a value (`unsatisfiable_arm_guard`), does an earlier arm already match everything
it matches (`unreachable_arm`). One arm, one tag. §5 describes all three and never says an arm
gets only one, or in what order they are asked.

So the ticket's two axes are two different gaps. Haiku's is an example gap: the rule is general,
the only example is over a declared type. terra's is a rule gap: the order is in the compiler and
not in the text.

## Round 1 — asked 2026-09-17

Both questions are measured at `46dddd8` with `bsc --diagnostics term`, the oracle's invocation.
Neither needs a compiler change; the delta for each is text in `LANGUAGE.md` §5, and `PACKET.md`
regenerated from it by `build-packet.py`.

**Q1.** Does §5's `vacuous_arm` paragraph gain a second example, over a built-in subject, placed
after the `Score` paragraph? The text that would land:

> The subject's type does not have to be one the file declares. A built-in type has members too,
> and a pattern outside them is the same dead arm:
>
> ```csharp
> public atom Route(string method)
>
> Route(method) -> method switch {
>     :get   => :read,
>     "POST" => :write,
>     _      => :reject
> }
> ```
>
> — *arm 1 of this switch in `Route` matches no value; the subject's type is `string`, and this
> arm's pattern is not a member of it.* An HTTP method arrives as a string. `:get` is how a
> router written against atoms spells it.

Measured: `vacuous_arm`, arm 1, `the subject's type is string`, exit 0 (a warning).

Why `string` and not `int`: `h11` is `:small` against `int`. An `int` example would put the
held-out case's exact shape in the packet, and `h11` would then test whether a reader recognises
the example. The held-out table's rule for `h08`–`h12` is "the same rule through a different
subject type"; `string` keeps `h11` different from both §5 examples. `bool` is ruled out by the
trap above.

What *yes* means as a general answer to the ticket's question: a rule about the subject's type
shows at least one subject the file does not declare. Measured against every `diagnoses:` fence
in `LANGUAGE.md` today, that reaches `vacuous_arm` and nothing else. `type_redeclared`,
`absorbed_member` and `indiscriminable_union` also use declared types, but their rules are about
declarations. So the stopping condition costs one fence.

Recommended: **yes.** Haiku's code shows the narrow reading came straight from the one example.

**Q2.** Does §5 state that a dead arm gets one of the three tags, and the order they are asked in?
The text that would land, after the `unsatisfiable_arm_guard` paragraph:

> An arm is reported for at most one of these three. The compiler asks, in order: is the pattern
> a member of the subject's type; does the guard admit any value; does an earlier arm already
> match everything this one matches. The first *no* is the diagnostic. An arm that matches no
> value is covered by every arm before it, trivially, so it is `vacuous_arm` and not also
> `unreachable_arm`.

Measured on the case the last sentence is about, a vacuous arm after `_`:

```csharp
public atom Route(string method)

Route(method) -> method switch {
    _    => :reject,
    :get => :read
}
```

→ `vacuous_arm` only, arm 2.

Recommended: **yes, as a sentence, not a fourth example.** terra had the precedence right in two
of three branches, so a reader needed the order stated, not more instances to infer it from. A
contrast example would also carry the `erlc` leak filed as
[ENG-386](https://linear.app/davewil/issue/ENG-386): this program, and §5's `Which` example
today, print `erlc`'s *"this clause cannot match"* warning beside B#'s.

## What follows the answers, and is not asked in this round

- **The audition's comparability.** Changing §5 changes the packet, so a round 6 on `h11` is
  not comparable to rounds 3–5. That is what it would measure: whether the text fixed the hole.
  The 2026-09-09 cut of the brief's coaching paragraph is untouched.
- **`h11` itself** stays as it is under both answers.
- **ENG-386** is a compiler defect and does not wait on this ticket.

## Decisions entry

<!-- filled when answered -->
