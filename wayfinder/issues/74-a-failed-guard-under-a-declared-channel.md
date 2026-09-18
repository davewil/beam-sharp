# 74 — What does a failed boundary guard become under a declared `result<T, foreign_error>` channel?

Type: grilling
Status: claimed — [ENG-362](https://linear.app/davewil/issue/ENG-362). Raised 2026-09-11 by the F42
build ([ENG-357](https://linear.app/davewil/issue/ENG-357))
Blocked by: —

## Why this is raised now

[F42](../../compiler/features/F42-foreign-return-guard.md) emits ticket 18 §2's boundary guard on
every foreign return whose declaration names **no** failure channel. It leaves the channelled
return unguarded, because the guard's failure there is a question 18 did not answer and ENG-357
named as the one open question in its build: `foreign_error` is
`(:error, term) | (:throw, term) | (:exit, term)`, three exception classes, and a wrong-typed value
is not an exception. A feature that needs a decision raises a ticket rather than making one, so
the arm is unbuilt and this is the ticket.

## The program

```csharp
module Reader

using :file {
    result<binary, foreign_error> read_file(binary path)
}

public result<binary, foreign_error> Slurp(binary path)

Slurp(path) -> :file.read_file(path)
```

`file:read_file/1` never throws. It returns `(:ok, binary)` or `(:error, atom)`, and neither
inhabits `binary | (:error, foreign_error)`. The declaration is wrong. LANGUAGE.md §11 measured
this on 2026-08-22, when F23 made the value-returned shape declarable, and recorded that *"a wrong
channel is now a wrong declaration like any other, and the boundary guard is what will catch it"*.

Today, and after F42:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
(:ok, <<...>>)
```

A value from outside broke the type, silently — ticket 06's outcome 3. Beside it, the unchannelled
form is caught since F42:

```csharp
using :file {
    binary read_file(binary path)
}
```

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
crashed: case_clause (:ok, <<...>>)
```

## Round 1

**Q1. When the guard refuses the value on a channelled call, does the program crash, or does the
wrong value arrive through the channel?**

Both arms below were **measured, not predicted**. Each is a one-line change to `bs_emit`'s
`e_foreign_call` clause, escriptized against the program above and run at `152a905`; both were
reverted and the tree carries neither. (The first attempt reported a crash under *both* arms —
`rebar3` had skipped the second rebuild because the patch landed in the same second as the first,
so the run graded the previous escript. The arms below were each re-measured from a rebuild seen
to succeed.)

**Crash** — the guard wraps the wrapper, `return_guard(L, foreign_wrapper(L, Call), Ty)`:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
crashed: case_clause (:ok, "##\n# Host Database\n...")
```

F19's existing behaviour is untouched under the same patch, measured on `examples/Foreign`:

```
$ bsc examples/Foreign Parse '<<"notanumber">>'
(:error, (:error, :badarg))
$ bsc examples/Foreign Parse '<<"41">>'
41
```

The catch's `(:error, (Class, Reason))` passes the guard because that tuple is in the declared
type, so only a value that is neither the success member nor a `foreign_error` reaches the
`case`'s missing arm.

**Through the channel** — the guard sits inside the wrapper,
`foreign_wrapper(L, return_guard(L, Call, Ty))`:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
(:error, (:error, (:case_clause, (:ok, "##\n# Host Database\n..."))))
```

And this is what that costs, measured on the committed example rather than argued:

```
$ bsc examples/Foreign Diagnose '(:error, (:error, :badarg))'
:not_a_number
$ bsc examples/Foreign Diagnose '(:error, (:error, (:case_clause, (:ok, <<"contents">>))))'
:not_a_number
```

`Diagnose` is the example's own clause-head dispatch over the class, the shape F19 was built to
make ordinary. It cannot tell a callee that raised `badarg` from a callee that raised nothing and
returned the wrong shape. Under the crash arm there is nothing for it to mistake.

**Through the channel, tagged apart** — the arm this ticket had not priced, and the shape OTP
itself chose. The refusal arrives as a value, as above, but carries a reason the callee cannot
produce, so a clause head can separate them. Measured on OTP 28.5, `kernel-10.6.3`:

```
erpc:call(node(), erlang, binary_to_integer, [<<"x">>])   raised error:{exception, badarg, [...]}
erpc:call('nope@nohost', erlang, node, [])                raised error:{erpc, noconnection}
rpc:call(node(), erlang, binary_to_integer, [<<"x">>])    returned {badrpc, {'EXIT', {badarg, ...}}}
rpc:call('nope@nohost', erlang, node, [])                 returned {badrpc, nodedown}
```

`erpc` puts the callee's failure and the mechanism's **own** failure in the same `error` class and
separates them by the reason's shape — `{erpc, _}` beside `{exception, _, _}`. `rpc`, the
value-returning predecessor, is the untagged arm, and OTP's own `-moduledoc` calls its ambiguity
unrepairable rather than unnoticed: *"make it difficult to distinguish between successful results,
raised exceptions, and other errors. This behavior cannot be changed for compatibility reasons."*

**In B# this arm costs a fourth member of `foreign_error`, and without one it is worse than the
untagged arm.** Measured:

```
$ bsc examples/Foreign Diagnose '(:error, (:invalid, (:ok, <<"contents">>)))'
:parsed
```

A refusal tagged with anything that is not a declared member falls past all three class clauses
into `Diagnose`'s catch-all and is reported as a **successful parse** — outcome 3 again, one site
over. So the tag has to be a member: `foreign_error` gains a fourth arm, `CONTEXT.md`'s entry is
rewritten, and every exhaustive match over the type in every program changes.

### How the three arms line up

The arms differ on one axis before they differ on value-versus-crash: **is the guard's refusal
distinguishable from the callee's own failure?**

| | refusal is | distinguishable from a callee failure | costs |
| -- | -- | -- | -- |
| Crash | a dead process | yes, maximally — it never reaches the channel | one line in `bs_emit` |
| Through the channel | `(:error, (:error, (:case_clause, _)))` | **no** — `Diagnose` answers `:not_a_number` for both | one line in `bs_emit` |
| Tagged apart | `(:error, (:invalid, _))` | yes, once `:invalid` is a member | a fourth member of `foreign_error`, the glossary entry, and every match over it |

### What the record already says, and why none of it decides this

- **18 §1 rule C** — *"A wrong term from outside will crash — not always at the call site, but
  never silently"*, and the decisions entry's guarantee is *"outcome 1-or-2, never outcome 3"*.
  The channel arm returns a visible value, so it is not outcome 3 either. **Rule C does not reach
  this case**, which is what ENG-357 meant by leaving it open.
- **`CONTEXT.md` on `foreign_error`** — *"The `E` produced by a compiler-emitted foreign wrapper,
  preserving* which *of the BEAM's three exception classes fired."* Under the channel arm the class
  that fired is generated code's own `case_clause`, raised *about* the callee rather than *by* it.
  The word doing the work is **foreign**, and that glossary entry would need rewording. Under the
  crash arm it stands unchanged.
- **12 §5, carried into 15 §5** — `raise` lowers to the `error` class and not to `throw` *because*
  the BEAM's `throw` is the catchable class, so *"a BEAM reader would read recoverable where the
  language means fatal"*. The channel arm is that shape one step over: a compiler-originated
  failure made recoverable by a compiler-emitted `try`. A precedent about a spelling, so evidence
  and not an answer.

### Prior art, surveyed 2026-09-19

[`research/74-foreign-guard-failure-prior-art.md`](../research/74-foreign-guard-failure-prior-art.md).
The headline is an empty result and it is the useful kind: **no BEAM language generates a
foreign-return check at all**, so none has faced this fork as posed. Gleam has the declaration
construct and emits a bare forwarding remote call — no `try`, no guard — and its own
`gleam_erlang` docs tell you to hand-write an Erlang wrapper instead. LFE's `defspec` compiles to
a `-spec` attribute and nothing more; that gap had never been surveyed here and is now closed.
Erlang is static-only. Elixir has no such construct.

So **this is an invention, not a borrow**, and the borrow heuristic puts invention last — which
raises the bar on the answer rather than settling it.

Two things the survey did settle:

- **The narrow-catch escape is already closed.** Gleam's hand-written FFI narrows its catch
  (`catch error:badarg -> {error, nil}`), which would let a guard's `case_clause` escape a wide
  wrapper and give the crash arm's outcome from the channel arm's construction. Ticket 15 already
  rejected narrowing on measured grounds: `gen_server:call` to a dead process raises
  `exit({noproc, …})` *in the caller's own process*, so *"an error-only wrapper would fail to
  catch the commonest foreign failure on the platform"*. The catch stays wide.
- **Elm refuses the question rather than answering it.** A channelled port declaration is refused
  at the declaration outright, and the one admissible type with an absence member throws rather
  than delivering the absence — but the throw lands on the JavaScript supplier's side where Elm
  code cannot observe it. Precedent for *"a generated check's failure is not a channel value"*,
  not for *"crash the receiver"*.

### Downstream of the answer, not in this round

Under the crash arm the guard tests the whole declared type and there is nothing further to
choose. Under the channel arm a second question opens: whether the guard tests the whole declared
type or only the success member, because a callee that *returns* `(:error, :enoent)` as an
ordinary value — the `Contents` shape ticket 56 made declarable — would otherwise come back as
`(:error, (:error, (:case_clause, (:error, :enoent))))`. That question exists under one answer
only, so it waits on this one.

## Not decided here

Whether a channelled declaration whose members can never be produced by the wrapper — `binary`
beside a `foreign_error` arm over a function that returns tuples — should be refused at the
declaration instead. The compiler cannot know which foreign functions throw (ticket 56), so it
cannot know which never return a bare `binary` either; that is the same limit read the other
way, and it stays outside this ticket.

The sibling question at the other site is [ticket 82](82-a-failed-encode-at-run-time.md) /
[ENG-382](https://linear.app/davewil/issue/ENG-382): what a failed guard becomes at a *codegen
obligation*, where F50 shipped a crash carrying a `ValidationError` provisionally. Same family,
different site, and 82 records its own reason for the crash it chose — *"there is no* `try` *in
the surface language, so a crash is not recoverable inside B#"*. That reason is exactly what the
channel arm here would make untrue at one site, so an answer to Q1 is worth reading beside 82
rather than inside it.
