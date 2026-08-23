# 22a — where does an "incomplete" marker go?

Ticket 22's residue is the spelling of the incomplete marker that ticket 23 §7 asked for and
deliberately did not spell. The ticket enumerated **attribute / keyword / convention**, and every
one of those puts the marker on the **declaration**. This probe asks whether any other language
does that.

Run them:

```sh
bash run_gleam.sh     # Gleam 1.18.1
bash run_csharp.sh    # .NET 9.0.306
bash run_erlang.sh    # Erlang/OTP 28
bash run_bs.sh        # B# itself — needs `cd compiler && rebar3 escriptize` first
```

Every probe carries a **control** — a known-bad input the harness must be seen rejecting — because
a clean result from a harness that is not looking is indistinguishable from a clean result from one
that is. That rule cost a session on ticket 45.

## What they measured, 2026-08-23

- **Gleam** — `todo` is a keyword in **body** position. It **compiles**, warns *"This code is
  incomplete"*, names the inferred type, and `--warnings-as-errors` turns it into the release gate.
- **C#** — the idiom is `throw new NotImplementedException()` in **body** position, and the compiler
  is **completely silent** about it. The declaration-position forms all fail or mislead: a
  `public partial` member with no body is hard error **CS8795**, and an old-style private
  `partial void` is legal but silently **erases every call to it**.
- **Erlang** — a `-spec` with no function is a hard error, *"spec for undefined function"*.
- **B#** — a signature with no clauses is a hard error, the same rule. `Weigh(_) -> 0` is *also* an
  error, *"discards cases the compiler can name"* — but that is a rule about `_` over an enumerable
  residual, **not** about total clauses. `Weigh(f) -> 0` and `Apply(o, c) -> 0` both compile clean
  (`StubBound`, `StubRecord`), and they compile **silently**: the total clause consumes the residual,
  so the compiler stops naming what is still owed.

So: every language makes a bodiless declaration a hard error (B# is in the majority, not the
outlier); the two with a real marker put it in **body** position; and **nobody uses an attribute**.

> **Corrected 2026-08-23, hours after this file was first written.** The first version claimed B#
> *refused* the clause a body-position marker needs, on the strength of the `Weigh(_)` result alone.
> `StubBound` and `StubRecord` were added to check that and falsify it — the probe had picked the
> one parameter type that trips the `_` check and generalised from it. The argument against body
> position survives, but it is about the **diagnostic** (a total clause leaves no residual to
> report, and 23 §7 wants one marker per declaration rather than per hole), not about legality.
> Commit `14e7b5e`'s message still carries the wrong version; it is fixed here and in the ticket.

The full write-up, and what it does to ticket 22's four questions, is in
[`../../issues/22-how-opinionated.md`](../../issues/22-how-opinionated.md).

## Layout

| Path | What it is |
|---|---|
| `gleam_todo/` | Gleam project. `src/*.gleam.off` are the control and the no-body variant, swapped in by the runner |
| `csharp_unimpl/` | .NET project holding the cases that **compile** |
| `variants/` | the C# cases that must **fail**: the control, and `public partial` with no body |
| `bs/StubNone`, `StubPartial`, `StubCatchall`, `StubBound`, `StubRecord` | B#. One directory per module — F15 makes a directory a module, so five `.bs` files in one directory would be five names for one module, and the compiler says exactly that |
