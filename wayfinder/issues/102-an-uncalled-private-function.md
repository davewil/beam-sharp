# 102 — Does B# warn on a private function nothing calls?

Type: grilling
Status: resolved 2026-09-25 — [ENG-465](https://linear.app/davewil/issue/ENG-465). Raised and
answered 2026-09-25 out of [ENG-359](https://linear.app/davewil/issue/ENG-359); one question,
one round
Blocked by: —

## Why this is raised

The 63d sweep (`wayfinder/prototypes/63d_erlc_leak_sweep/`) found one `erlc` diagnostic that
reaches the author unmediated after F41: a `private` function nothing calls. ENG-359 recorded
that whether B# warns there at all was a decision no ticket had made (grepped for unused /
never-called on 2026-09-11, and again 2026-09-25): Erlang warns, C# does not.

## The program

```csharp
module B03UnusedPrivate
private int Helper(int n)
Helper(n) -> n + 1
public int Check(int u)
Check(u) -> u
```

compiles at exit 0 and relays `compile: .../b03unusedprivate.bs:0: Warning: function 'Helper'/1 is
unused`: Erlang's notation, no tag, absent from `--diagnostics term`, and at line 0 because the
emitter attaches no position to the function form.

## Q1 — Warn in B#'s own voice, or say nothing?

**A1 (David, 2026-09-25):** *"Warn."*

## The compiler delta

- A pass in `bs_check` over the call graph F12 keeps for visibility: a `private` function with no
  caller in its module gets a warning at its signature's line and column.
- One `bs_diag` tag and its `message/1` clause, on the term channel like every other warning, so
  `--diagnostics term` and `--diagnostics json` carry it. The wording is the build's; the shape
  shown to David was `B03UnusedPrivate.bs:2:13: warning: Helper is private and nothing calls it`.
- `nowarn_unused_function` passed to `erlc`, so the warning is said once, in B#'s voice.
- LANGUAGE.md's diagnostics section gains a demonstration for the new tag.

## Not decided here

- Whether the other `erlc` warnings ENG-386 names (an arm after `_`) are silenced the same way.
  That is ENG-386's build, which stops if its fix would silence a warning `bs_check` does not give
  itself; this ticket gives it this one.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Does B# warn on a private function nothing calls?](issues/102-an-uncalled-private-function.md)
  — **yes, in B#'s own voice: `bs_check` warns at the function's line from F12's call graph, on
  the term channel, and Erlang's own warning is switched off.** Raised and resolved 2026-09-25 in
  one round on one question, out of [ENG-359](https://linear.app/davewil/issue/ENG-359), which
  the 63d leak sweep filed as the one `erlc` diagnostic still reaching the author unmediated after
  F41: Erlang's `'Helper'/1` notation, no tag, and line 0. Erlang warns and C# does not; B# warns.
  Unbuilt — ENG-359.
```
