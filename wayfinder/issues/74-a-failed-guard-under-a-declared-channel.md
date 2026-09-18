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
