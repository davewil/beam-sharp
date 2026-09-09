# 71 — A worked example narrower than the rule it illustrates

Type: spec shape
Status: open — [ENG-348](https://linear.app/davewil/issue/ENG-348). Raised 2026-09-10 by the
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

## Decisions entry

<!-- filled when answered -->
