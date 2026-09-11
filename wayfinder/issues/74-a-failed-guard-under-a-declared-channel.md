# 74 — What does a failed boundary guard become under a declared `result<T, foreign_error>` channel?

Type: grilling
Status: open — [ENG-362](https://linear.app/davewil/issue/ENG-362). Raised 2026-09-11 by the F42
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

Crash — the same as the unchannelled call, 18 §1 rule C applied without regard to the channel,
on the reading that the channel was declared for *exceptions* and this is not one:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
crashed: case_clause (:ok, <<...>>)
```

The compiler delta is one line in `bs_emit`: `return_guard/3` wraps the `try` where today the
wrapped branch skips it, so the guard sees the `try`'s whole result, and the
`(:error, (Class, Reason))` the catch produces passes it because that tuple is in the declared
type.

Through the channel — the wrong value becomes the failure the author said they would handle:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
(:error, (:error, (:case_clause, (:ok, <<...>>))))
```

The delta is the other nesting: the guard's `case` inside the `try` body, so its `case_clause`
is caught as an `error`-class exception. The payload then reads as if the callee raised, when
nothing did — the class that dispatches `Diagnose((:error, (:error, _)))` in `examples/Foreign`
would see a compiler-raised reason beside `badarg`.

One question. Which nesting the emitter writes is the whole decision.

## Not decided here

Whether a channelled declaration whose members can never be produced by the wrapper — `binary`
beside a `foreign_error` arm over a function that returns tuples — should be refused at the
declaration instead. The compiler cannot know which foreign functions throw (ticket 56), so it
cannot know which never return a bare `binary` either; that is the same limit read the other
way, and it stays outside this ticket.
