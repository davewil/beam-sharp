# 49a — what arm would the valve have to emit?

Measured 2026-08-28 for [ticket 49](../../issues/49-what-the-valve-keys-on.md) (ENG-231), which
asks whether `|?>` should key on the atom `(:error, _)` or on the stage's **declared parameter
type** ([31c](../31c-middleware-on-the-page.md)'s shape B).

The ticket names its own first measurement: 31c claims shape B needs *"nothing the compiler does
not already have"*, and *"that claim is unverified"*. This is the verification.

## Files

| | |
|---|---|
| `algebra.erl` | six rows through `bs_types` — what the residual is per subject/parameter pair, how many arms it takes, and whether F29 can spell it |
| `guard.erl` | **expected to fail `erlc`** — asks the platform whether the one unspellable residual has a guard behind it anyway |
| `Narrow/narrow.bs` | the unspellable residual in a program someone would write |
| `Collapse/collapse.bs` | `option<atom>` at an ordinary declaration — ticket 15 §1 says this is an error, and it compiles |

Run `algebra.erl` from the **repo root**; a bare `erl` inside `compiler/` picks up `C.beam` and
dies. Each `.bs` directory is one module, run with `compiler/_build/default/bin/bsc <dir>`.

## What it found

**1. The arm is a function of the callee's signature, and emit cannot see signatures.**
`bs_lower:valves/1` runs inside `parse_string`, before any type exists, and `bs_emit`'s context
carries `env` (the type environment) but not `callees` (the signature table, which lives only in
`bs_check`'s `#ctx`). So shape B's arm must be computed at check time and carried to emit.

**That much 31c is right about**: the channel exists three times over — F18's `validators`, F19's
`foreigns` (*"decided in `bs_check`, where the declaration is; looked up here and nowhere else"*)
and 41 §2's resolved `imports`. Shape B is a fourth entry in an established mechanism, not a new
pass. Pass order is not the obstacle.

**2. The valve stops being two-armed** (row 3). A residual can span more than one member, so a
chain's type becomes a union of per-stage residuals. 17 §7's *"a `|?>` chain emits a `case` per
stage"* survives; the case's **width** becomes a function of the subject.

**3. The residual is not always testable, and this is the finding.** Row 4: `binary \ string` is
non-empty, F29's head channel yields **zero** parts for it, and `erlc` rejects the only stdlib test
as `illegal guard expression`. Inverting the polarity does not help — validity is a linear scan
either way.

So ticket 09's *"discriminable by one BEAM guard in O(1)"*, which 31c leans on, **does not hold in
general**. `Narrow/narrow.bs` puts it in an ordinary program: `string` is B#'s refinement of
`binary` (F10), and declaring a stage over the narrower of the two is the ordinary reason to narrow.
Today that program is **refused honestly** —

```
error: this |?> in Run is over a value that cannot fail
  binary has no (:error, _) member, so the valve would never stop.
```

— and under shape B it would be **accepted** and then fail to lower. Shape B therefore needs a
refusal that does not exist: *this stage narrows to a type the valve cannot test*.

**4. A fixed short-circuit set (shape C) was never costed, and it is not free either.** Keying on
`(:error, _) | :nothing` — a constant, not a signature — closes the `option<T>` gap, keeps the arm a
literal in `bs_lower`, never reaches row 4, and is arguably *closer* to the C#/TS borrow than shape
B, since `?.` keys on a fixed sentinel rather than on the callee's parameter type. Its cost is two
preconditions:

- **Row 5.** `option<atom>` normalises to bare `atom`, so a fixed set would stop on a legitimate
  success. Ticket 15 §1 refuses this *at the declaration* — **decided, and measured unbuilt**:
  `Collapse/collapse.bs` compiles clean, exit 0. F18 built the collapse check only at the
  `ValidateAs<T>` obligation site. Filed as [ENG-272](https://linear.app/davewil/issue/ENG-272).
- **Row 6.** `:found | :nothing` does **not** collapse, so 15 §1 passes it even once built — yet a
  fixed set still short-circuits on `:nothing`, and `valve_on_infallible` does not fire because the
  meet is non-empty. Shape A has no analogue: `(:error, _)` is a tuple with a tag nobody writes by
  accident, where `:nothing` is a bare atom in the ordinary namespace. **This one has no decision
  behind it at all.**
