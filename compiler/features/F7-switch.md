# F7 — `switch`: the clause head's pattern grammar, one level in

**Status**      **done 2026-08-15**
**Implements**  [ticket 17](../../wayfinder/issues/17-pipeline-and-comprehension.md) §6,
                [ticket 12](../../wayfinder/issues/12-totality-vs-let-it-crash.md) §2 (inherited,
                and inherited *unenforced* — see out of scope) — decides nothing
**Unblocks**    the **branching** in all three exemplars. Not a compiles claim, and not even a
                parses claim — see the build note; `disposition.bs` still fails on a clause-head
                spelling these prototypes use and the grammar does not have
**Depends on**  F1, F3, F5, F6

## Why this one now

The ordering rule, and for once without an argument to have: `switch` is the only branching
construct the language has, and until it parses there is no way to branch on anything that is not a
parameter. Every exemplar in `examples/exemplars/` reaches for it, and `LANGUAGE.md` §5 has carried
two `not-yet` blocks since the reference was written.

It is also the capability that makes the language's own thesis reusable rather than special.
Ticket 01 moved C#'s pattern grammar *out* of `switch` and into the parameter position; §6 puts the
same grammar back into expression position, so the construct inherits the whole story — ticket 12
makes exhaustiveness a hard error rather than C#'s warning, and ticket 04 makes the residual the
missing **arm**.

## What is being built

```csharp
Verdict Describe(Order o)
Describe(o) -> o.Status switch {
    :placed  => :new,
    :shipped => :gone,
    _        => :unknown
}
```

Postfix, C#'s spelling, `=>` per arm — the arrow ticket 08 reserved and which nothing has used until
now. `->` is still a clause and `=>` is still not one; two arrows, two jobs, and F7 is where the
second one starts having a job at all.

**An arm takes a guard.** `p when n > 0 => e` is legal, and this is a decision the feature had to
make rather than inherit, so the reason is here. Ticket 17 §6's own example is
`{ Total: > 100, Status: :open }` — a C# *relational pattern*, which this grammar does not have and
which is F2's, and F2 is blocked on two decisions. Without a guard there would be no way at all to
branch on a numeric comparison inside a switch, and the construct that is supposed to be the clause
head one level down would be strictly weaker than the clause head. The machinery is already
there: `apply_guard/3` and the `Certain`/`Possible` split are what a clause head goes through, and an
arm is a one-column clause row.

**An arm body is a single expression.** Not a decision about what a body should be — a grammar
fact. Arms are comma-separated and a body is *bindings then an expression* with no terminator, so
`p => x = 1, x + 2` cannot be told from two arms with one token of lookahead. Ticket 34's binding is
a body form and the body form here is one expression. Named in out of scope, not discovered later.

## What a switch is checked against, and where it differs from a clause row

The subject is an ordinary expression, so its type is **synthesised** — F5's site machinery, which
is why this feature depends on F5 and not merely on F1. A clause head's domain is a *product* of
declared parameter types and its variable paths start at `[I]`; a switch's domain is one synthesised
type and its paths start at `[]`.

That difference has one concrete consequence and it is a crash, not an imprecision. `at_path/2` has
an empty-path clause (`at_path(Ty, []) -> Ty`) and its refining twin `refine_at/3` does **not** —
nothing had ever asked it to refine a whole value, because a clause-head path always begins with a
parameter index. So `n switch { n when n > 0 => … }` calls `refine_at(Ty, [], C)` and leaves the
checker through a `function_clause`. F7 adds the clause.

The alternative — wrapping the subject in a one-component tuple so paths start at `[1]` and nothing
else changes — was rejected on the *diagnostic*: the residual would then print as `(:cancelled)`,
with parentheses, which is not the arm anybody writes.

## The name rules, and the one that is not merely consistency

An arm pattern's names are readable in that arm and nowhere else — its own guard, its own body. So
`expr_vars/1` must subtract each arm's pattern variables from **that arm's** free names, not from the
switch's.

**An arm may not rebind a name already in scope**, and this is stronger than ticket 34's
no-shadowing rule being applied evenly. In Erlang, a `case` arm pattern naming an already-bound
variable is not a binding at all — it is an **equality test against the existing value**. Accepting
it would emit a silent semantic change from a program that reads like a fresh binding, with no
diagnostic anywhere. The rebinding error is what stops that, and 34's rule happens to already say so.

## Scenarios

Each runs through the harness the README describes: `bsc FILE.bs [FUNCTION] [ARG...]`.

### F7.1 — a switch dispatches, and runs

```csharp
module Traffic
type Verdict = :new | :gone | :unknown

Verdict Describe(atom status)
Describe(s) -> s switch {
    :placed  => :new,
    :shipped => :gone,
    _        => :unknown
}
```

`bsc traffic.bs Describe :placed` → `:new`; `:frozen` → `:unknown`. This is `LANGUAGE.md` §5's own
first block, which the reference has been calling `not-yet` since it was written.

### F7.2 — the tuple subject, at the width 25c measured

```csharp
Disposition Decide(bool ok, bool permanent, bool redelivered)
Decide(o, p, r) -> (o, p, r) switch {
    (true,  _,     _)     => :ack,
    (false, true,  _)     => :dead_letter,
    (false, false, false) => :requeue,
    (false, false, true)  => :requeue
}
```

Runs, and is exhaustive with **no catch-all** — which is the property that matters, because it is
what says the three-wide product is genuinely covered rather than swept up by a `_`. The map's
`cond` question is not reopened by this scenario and is not answered by it: this is width three, and
the readability cliff 25a and 25c located sits between four and five.

### F7.3 — an inexhaustive switch is a hard error, and the residual is the arm to write

```csharp
type Event = :placed | :shipped | :cancelled

atom Which(Event e)
Which(e) -> e switch {
    :placed  => :new,
    :shipped => :gone
}
```

→ **error** naming `:cancelled => ...`. Not routed through `heads/2`, which prints
`Which(:cancelled) -> ...`: a switch has no function name and its arrow is `=>`. A tuple subject
renders `(false, false, true) => ...` and a union of records renders `{ Kind: :'Shop.Invoice' } => ...`,
both free, because `to_pattern/1` was already the printer for exactly this shape.

### F7.4 — an arm guard refines, and this is the scenario that crashes without the empty-path clause

```csharp
atom Sign(int n)
Sign(n) -> n switch {
    m when m > 0 => :positive,
    m when m < 0 => :negative,
    _            => :zero
}
```

Runs, and `bsc … Sign 0` → `:zero`. Exhaustive **because the guards are credited**: two intervals
plus a catch-all, which is `math.bs` one level down. Deleting the third arm must report the residual
`0 => ...` rather than reporting nothing — that is what says the interval refinement reached the
arm rather than the arm being covered by accident.

### F7.5 — an untranslatable guard credits nothing, and this asserts what a wrong build OMITS

```csharp
bool Big(int n)

atom Check(int n)
Check(n) -> n switch {
    m when Big(m) => :big
}
```

→ **error**: inexhaustive, residual `int => ...`. A guard the checker cannot read might always fail,
so the arm is guaranteed to match nothing.

**This scenario does NOT guard the `Certain`/`Possible` trap**, and saying so is the point. The
residual above is computed from `Certain` either way, so this arm of F7.5 stays green under that
mutation. F7.14 is what catches it, and the reason it is a separate id rather than a sentence here
is that a scenario which cannot fail under the mutation it is credited with is worse than no
scenario at all.

### F7.6 — an unreachable arm is a warning, and it names an arm

```csharp
atom Which(Event e)
Which(e) -> e switch {
    _        => :other,
    :placed  => :new
}
```

→ **warning**: arm 2 is unreachable. Arm, not clause — the existing message says "clause N of Fn",
and pasting that word into a construct that has no clauses is how a diagnostic stops being read.

### F7.7 — an arm's names are its own, in both directions

The mirror pair, because either half alone is unfalsifiable:

- `e switch { (:ok, v) => v }` — `v` is read in its own arm body and is **not** reported unbound.
- `e switch { (:ok, v) => w }` — `w` is reported unbound, from inside an arm body, by `bsc` and
  not by `erlc` against a file the author did not write.

A build whose `expr_vars/1` returns `[]` for a switch passes the first and fails the second, which
is why the second exists.

### F7.8 — an arm may not rebind a name the clause head bound

```csharp
atom Pick(int n, term e)
Pick(n, e) -> e switch {
    n => :same,
    _ => :other
}
```

→ **error**: `Pick` binds `n` twice. Erlang would have compiled this into an equality test against
the first `n`, silently, which is a different program from the one that was written.

### F7.9 — a parameter used only inside an arm body is not underscored

```csharp
atom Report(int n, atom tag)
Report(n, tag) -> tag switch {
    :show => :seen,
    _     => :hidden
}
```

...and the variant where the arm body reads `n`. F1 found this by running the emitter rather than
reading it: a name the emitter thinks is unused lowers to `_N`, and a body that then reads `N` is
not a warning but a **compile error** in the emitted Erlang. `used_vars/2` must descend into a
switch's arms, and a build where it does not fails here rather than at a user's desk.

### F7.10 — the switch's type is the union of its arms, and site 4 checks it

```csharp
Verdict Describe(atom s)
Describe(s) -> s switch {
    :placed => :new,
    _       => :missing
}
```

→ **error** at the clause return: `:missing` is not covered by `Verdict`. A switch synthesises, it
does not declare, so it opens no sixth site — ticket 33 enumerated five and F7 adds none. What it
does is make site 4 reachable from a place it could not previously be reached from.

### F7.11 — braces nest, three ways

A record construction as an arm body, a property pattern as an arm pattern, and a switch inside a
switch. Cheap, and aimed at the one thing a new brace-delimited construct plausibly breaks: the
grammar already spends `{` on record declarations, anonymous map types, property patterns, record
construction and `with`. Asserted by **parse**, not by conflict count — F6.9's note stands, yecc
resolves shift/reduce silently through the precedence table and every one of 28a's four variants
reported zero conflicts including the wrong one.

### F7.12 — a switch in a guard is refused by name

`F(x) when x switch { … } -> …` parses, because a guard shares the whole expression grammar. It
would reach `erlc` as *illegal guard expression* against the emitted `.abstr`. Refused by `bsc`
instead — the same hole F5 found when `_` became an expression, and the same rule: F4.7's, that the
author meets the error against the file they wrote.

### F7.13 — the corpus is unchanged, and `LANGUAGE.md` §5 is promoted

Every `.bs` in `examples/` compiles and runs, all 126 tests pass, and `bin/check-language.sh` is
green **with §5's two blocks re-tagged from `not-yet` to must-compile**. That re-tagging is not
bookkeeping: the gate reports `PROMOTED` and fails until it is done, which is the half of the
bidirectional check that pays.

**F7 edits the lexer**, which is upstream of every byte of the corpus — a wider blast radius than
F6's `resolve/2`, which was one shared funnel. So all three gates run after the grammar lands and
**before** the first new test is written, not after the feature is finished.

### F7.14 — an arm body under an unreadable guard is still checked

```csharp
atom Tag(atom a)

atom Check(int n)
Check(n) -> n switch {
    m when Big(m) => Tag(m),
    _             => :small
}
```

→ **error** at site 1: `Tag` does not accept an `int`.

**This is the scenario that guards the `Certain`/`Possible` trap, and F7.5 is not.** Build the arm's
body domain from `Certain` instead of `Possible` and the compiler does not break — it goes *quiet*.
`Certain` is `none` under an untranslatable guard, `m` is then `none`, `subtract(none, atom)` is
empty, and the call is accepted in silence.

F5.7 established that a check which fails by going quiet cannot be caught by a passing test. What is
new here is that it cannot be caught by the **adjacent** test either: F7.5 asserts the residual, the
residual comes from `Certain` either way, and F7.5 therefore stays green under exactly the mutation
its own prose sounds like it covers. Numbered last because it was written last — after the mutation
run showed F7.5 surviving.

### F7.15 — a binding, then a switch on the name it bound

```csharp
Verdict Grade(Order o)
Grade(o) ->
    total = o.Total
    total switch {
        n when n > 100 => :large,
        n when n <= 100 => :small
    }
```

Runs. This is ticket 17 §6's own stated reason for the construct — *"you can branch on an
intermediate without inventing a parameter to dispatch on"*, which is 01b's friction — and it is the
first shape that puts F4 and F7 through the same clause. Four paths meet here and every one of them
is new or changed by F7: `check_scope/5` → `name_diags/5` → `rebinds/3` in the scope pass,
`bind_step/3` → `type_of/3` for the switch's subject, and `binds/3` → `expr/2` in the emitter.
None of the scenarios above crosses that seam, and `examples/Queue/queue.bs` contains no bindings at all.

And the arm that rebinds the bound name — `total => …` — must report rebinding, which is F7.8's rule
reached from the other side: there the name came from a clause head, here from a binding.

### F7.16 — a switch in tail position keeps the tail call

```csharp
int Down(int n, int acc)
Down(n, acc) -> n switch {
    m when m <= 0 => acc,
    m when m > 0  => Down(m - 1, acc + m)
}
```

Asserted on the **emitted bytecode**, like `recursion_is_a_tail_call_test`: a `call` or `call_ext`
op means a stack frame was built. `bs_emit`'s header says the body is kept a flat list rather than a
`begin` block precisely so the last expression stays in tail position — and F7 makes a switch the
ordinary thing to put there, since a process loop branches on a message and recurses in one arm.
Erlang's `case` preserves it and nothing had asserted that. This is the one property an OTP loop
silently depends on, so it is pinned before F8 rather than after somebody's `handle_info` grows a
stack.

- **Ticket 12 §2 — the catch-all rule — is inherited unenforced, and this is a cost taken
  deliberately.** §2 says a `_` is legal only over an *open* residual: where the residual is closed
  and the compiler knows the missing case by name, `_` should be an error telling you to name it.
  **Measured on master before a line was changed**: it is not enforced at the clause head either —
  `Which(:placed) -> :new` / `Which(_) -> :other` over `type Event = :placed | :shipped | :cancelled`
  compiles clean. So F7 does not create the gap, it reaches it from a second direction. Not raised
  as a ticket, because the rule is decided; what is open is only §2's own hand-off to ticket 25 —
  whether a *marked spelling* for a deliberate close is worth inventing — and that is already parked
  there. It is a feature nobody has written, and it should be written for both sites at once.
- **`cond`.** Still unpaid-for, and F7 supplies no new evidence: the map's question is whether the
  positional encoding is the right shape at any width, and F7.2 is width three, below the cliff both
  prototypes located. Building the construct is what will produce the evidence, from someone writing
  a real ladder rather than from a feature file.
- **Relational and interval patterns** — `{ Total: > 100 }`, ticket 17 §6's own example. F2's, and
  F2 is blocked on two decisions. A guard is what stands in for them, which is why arms have one.
- **Bindings in an arm body.** The grammar reason is above — and it is a restriction of *this*
  grammar rather than a permanent one, which is worth recording so nobody re-derives it as a law.
  A braced block expression (`expr -> '{' body '}'`) was measured against F7's own grammar while
  this feature was being built: yecc reports no conflicts, a block parses as an arm body, and a
  property pattern left of `=>` with a block right of it parses too. **It is not free**, and the
  first measurement saying it was is corrected here: a block reaching `expr_vars/1` as an ordinary
  expression subtracts nothing, so every name the block binds is reported unbound — real scope work
  in `bs_check`, plus F7's own `rebinds/3` walk, neither of which was measured. It also makes F5's
  parked map destructuring bind harder to un-defer, degrading its error from `before: '{'` to
  `before: ':'`. **Ticket 22's question about what a body *is*, not a feature's**, and the argument
  against it is about reading rather than mechanism — which is the map's own line about refusing
  only on mechanism, pointing the other way.
- **`switch` as a statement.** There are no statements.
- **A trailing comma after the last arm.** C# allows one; nothing else in this grammar does — not
  a tuple, not a record, not a field list — and inventing it for one construct is a spelling
  decision nobody has made.
- **Duplicate names within a single arm pattern** — `(a, a) => …` — which Erlang also turns into an
  equality test. Not F7's to fix: a clause head has the identical hole today
  (`F(a, a) -> …` is accepted), so closing it in one place and not the other would be worse than
  leaving it named. Stated rather than found.

## Done when

`o.Status switch { … }` and `(a, b, c) switch { … }` both parse, check and run; an inexhaustive
switch names the arm to write and a redundant one warns about an arm; an arm guard is credited and
an unreadable one credits nothing; an arm's names are scoped to it and may not rebind; a switch in a
guard is a `bsc` error. `rebar3 eunit` is green, `bin/check-language.sh` is green with §5 promoted,
and every `.bs` in `examples/` still compiles and runs.

---

## Built 2026-08-15

**All sixteen scenarios pass.** 145 tests, up from 126. `LANGUAGE.md` §5's two blocks are promoted
from `not-yet` to must-compile, and `examples/Queue/queue.bs` is new and runnable:
`bsc examples/Queue/queue.bs Decide false true false` → `:dead_letter`.

**Three of the sixteen were written after the mutation run and a review, not before**, and they are
named rather than folded in: F7.14 because F7.5 turned out not to guard what its prose implied,
F7.15 because nothing anywhere crossed the F4/F7 seam, and F7.16 because a switch in tail position
is the one property an OTP loop depends on and nothing asserted it. Scenarios 1–13 were written
before the first line of the implementation, which is what this file is for; the last three are what
the discipline caught, and hiding that would make the count look tidier than the process was.

### Which gates ran

`rebar3 eunit`, `bin/check-language.sh`, and every `.bs` in `examples/` compiled and run.
**`bin/spec-check.sh` was not run** — it is red independently of F7 and has been since F3: `counter.bs`
declares `behaviour GenServer` without defining its callbacks, so Dialyzer reports three undefined
callbacks. F6 skipped it for the same reason. Stated so the omission is a decision rather than a gap.

### The defect this feature found was not in this feature

`LANGUAGE.md` §4 said **`true` and `false` are the only keyword atoms** and marked it **shipped**.
The lexer had `:true` and `:false` and no bare rule, so a bare `true` lexed as an ordinary lowercase
identifier — which in pattern position is a **variable**.

```
Decide(true,  p) -> :ack        // binds a variable named `true`. Matches everything.
Decide(false, p) -> :requeue    // dead
```

Measured on master: `Decide(false, p)` returned **`:ack`**. The program compiled and meant something
else, and the only trace was an unreachable-clause warning that reads like a remark about the code
rather than a report of a misparse.

**Three things about it are worth more than the fix**, which is two lexer rules.

1. **It has nothing to do with `switch`** — the clause head had it too, and the test asserts it
   there rather than at the arm that found it. F7 is where it surfaced because ticket 17 §6's
   motivating example is `(true, _, _)` and nobody had run one.
2. **`bin/check-language.sh` could not have caught it.** The claim is prose, not a fenced block, and
   the gate distinguishes *compiles* from *does not*, never *means what it says*.
3. **Every tuple-subject ladder in `examples/exemplars/` is written in bare `true`/`false`** — 25a's
   five-wide and 25c's four-wide both. So the defect sat directly under the feature that had not
   been built, waiting for it. **A capability's own motivating example is a probe**, and running one
   before writing the feature is cheaper than trusting a status column.

### Four mutations, and two of them a green suite would have shipped

The gate discipline F5.7 and F6.8 established, run rather than assumed:

| Mutation | Result |
|---|---|
| arm domain from `Certain` instead of `Possible` | **1 test red** — `an_arm_body_under_an_unreadable_guard_is_still_checked_test`, and *only* that one |
| `arm_free_vars/1` subtracts nothing | **6 tests red** — every arm-bound name reported unbound |
| `arm_free_vars/1` subtracts everything | **1 test red** — the mirror, `an_unbound_name_in_an_arm_body_is_reported_test` |
| `used_vars/2` does not descend into arms | **2 tests red**, and not on an assertion: `erlc` says `variable 'N' is unbound`, an **error**, not a warning |
| `refine_at/3` without its empty-path clause | **3 tests red** with `function_clause` out of the checker |

**The first row is the one that justifies its test existing.** F7.5 asserts the *residual* under an
unreadable guard, and the residual is computed from `Certain` either way — so F7.5 stays **green**
under that mutation and says nothing at all about the domain the body is typed against. A separate
scenario, aimed at an arm body handing an `int` to a function declared over `atom`, is what goes red:
built with `Certain` the variable is `none`, `subtract(none, atom)` is empty, and the call is
accepted in silence. **A check that fails by going quiet cannot be caught by a passing test**, and it
cannot be caught by the *adjacent* test either — which is the sharper half of F5.7's lesson and is
new here.

**And the mirror pair is genuinely a pair.** Six red one way, exactly one red the other, with no
overlap: either test alone leaves half the rule unasserted.

### What running it found that reading it would not

- **`refine_at/3` had no empty-path clause**, and the crash was predicted before the first line was
  written rather than discovered. `at_path/2` has had one since F5 and its refining twin never
  needed it, because a clause-head path always begins with a parameter index. A switch subject is
  one value, so `n switch { m when m > 0 => … }` is the first thing ever to ask.
- **The `ibs` prompt did not know the keyword atoms.** `Decide(false, true, false)` answered
  *"false is not bound"*, because a bare word resolves from the REPL's environment before anything
  tries to read it. **F7 is the third feature in a row to find a hole there** — F4 a stale
  diagnostic, F5 a broken destructuring bind — and `bs_repl` still appears **zero times** in the
  suite. Each feature has fixed what it tripped over; none has closed the gap, which is a pattern
  now and not three incidents. Recorded in `features/README.md` rather than fixed here.

### The unblocks line was wrong once, and measuring it is what caught it

This file's first draft said F7 unblocks *the branching in all three exemplars*, and the exemplar
README's first draft said every tuple-subject ladder in those files now parses. **Neither survived
running one.** `examples/exemplars/25c-event-queue-consumer/disposition.bs` still fails at line 12,
and not on the switch — on `(o, r, n) -> …`, a clause head written **without repeating the function
name**, which these prototypes use and ticket 01's Variant A does not have. That is drift between
the prototypes and the shipped grammar, it is nobody's feature, and it was invisible from the switch
row of the capability table.

F6 wrote *"a bracket claim is not a compiles claim"* and was right; the narrower correction is that
a capability claim is not a **parses** claim either, and the only way to tell is to run the file the
claim is about.

### The gate ran first, and the reason is not F6's

F6 ran the corpus gate first because it edited `resolve/2`, one shared funnel. **F7 edits the
lexer**, which is upstream of every byte of every `.bs` file, every `LANGUAGE.md` block and every
exemplar. All three gates ran after the grammar landed and before the first new test: 126 tests,
21 blocks, 7 examples, all green and **zero** unintended changes — as expected rather than as luck,
since nothing in the corpus contained `=>` or the word `switch`.

The keyword-atom fix is the one that could have moved the corpus, and it is worth stating what it
did and did not touch: no `examples/*.bs` used `true` or `false` as an identifier, so nothing lost a
variable; and it changed the meaning of source only where that meaning was already wrong.

### What it ships without, named rather than discovered

- **Ticket 12 §2's catch-all rule**, inherited unenforced from the clause head and measured as such
  before anything was changed. Out of scope above, with why it is a feature and not a ticket.
- **Bindings in an arm body**, with a measured route out that belongs to ticket 22.
- **`cond`**, on which F7 supplies no evidence: F7.2 is width three and the cliff both prototypes
  located is between four and five. The evidence will come from someone writing a real ladder now
  that they can.
- **Duplicate names inside one arm pattern** — `(a, a) => …`, which Erlang turns into an equality
  test. The clause head has the identical hole (`F(a, a) -> …` is accepted today), so it is stated
  rather than half-closed.
- **Relational patterns** — `{ Total: > 100 }`, ticket 17 §6's own spelling. F2's, and blocked.
  A guard is what stands in for them, which is why arms have one.
- **`Route` in `examples/Queue/queue.bs` cannot be run from the command line**, and the header says so
  rather than pretending otherwise. `bs_run`'s argument reader has no spelling for a record, so
  `#{Kind => :'Queue.Message', …}` is refused as unreadable — measured. It is covered by a test and
  compiles, but it is the one demonstration in `examples/` that nobody can watch work, which is a
  gap in the harness rather than in the language. Named because `examples/` exists so that a
  capability is lookable-at, and a projection subject is the half of ticket 17 §6 that answers 01b.
