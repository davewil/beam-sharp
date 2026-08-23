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
- **B#** — a signature with no clauses is a hard error, the same rule. And `Weigh(_) -> 0`, the
  clause a body-position marker would need, is **also** an error: *"discards cases the compiler can
  name"*.

So: every language makes a bodiless declaration a hard error (B# is in the majority, not the
outlier); the two with a real marker put it in **body** position; **nobody uses an attribute**; and
B# has already ruled out the catch-all clause that body position would require.

The full write-up, and what it does to ticket 22's four questions, is in
[`../../issues/22-how-opinionated.md`](../../issues/22-how-opinionated.md).

## Layout

| Path | What it is |
|---|---|
| `gleam_todo/` | Gleam project. `src/*.gleam.off` are the control and the no-body variant, swapped in by the runner |
| `csharp_unimpl/` | .NET project holding the cases that **compile** |
| `variants/` | the C# cases that must **fail**: the control, and `public partial` with no body |
| `bs/StubNone`, `bs/StubPartial`, `bs/StubCatchall` | B#. One directory per module — F15 makes a directory a module, so three `.bs` files in one directory are three names for one module |
