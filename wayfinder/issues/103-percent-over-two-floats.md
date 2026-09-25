# 103 — `%` over two floats

Type: grilling
Status: resolved 2026-09-25 — [ENG-466](https://linear.app/davewil/issue/ENG-466). Raised and
answered 2026-09-25 out of [ENG-385](https://linear.app/davewil/issue/ENG-385); one question, one
round
Blocked by: —

## Why this is raised

[38](38-division-and-modulo.md) decided `%` over two `int`s: the remainder, signed by the dividend,
lowered to `rem`. Nothing decided it over two floats. F51's first cut typed `x % 2.0` as `int` and
emitted `rem`, which crashed with `badarith`; F51 now refuses it at the operator
(`float_remainder`), which kept the question open rather than answering it. ENG-385 asked for a
program that wants a float remainder before deciding.

## The program

```csharp
public float Wrap(float angle)
Wrap(a) -> a % 360.0
```

Refused at `057fec6`: `float_remainder`, *"`%` in Wrap has a `float` on both sides — the remainder
over two floats has no meaning the language has decided"*.

## Q1 — Allow it with C#'s meaning, or keep refusing and close the ticket?

C#'s `%` over `double` is the truncated remainder, signed by the dividend. The BEAM's only float
remainder is `math:fmod/2`, which is the same: `math:fmod(-30.0, 360.0)` is `-30.0` (measured on
OTP 28, 2026-09-25).

**A1 (David, 2026-09-25):** *"Allow it."*

## The compiler delta

- `bs_check:op_result/5`: the `{float, float}` clause for `'%'` stops raising `float_remainder`
  and returns `bs_types:float_top()` with a mark, `{fmod, L, float}`, beside F51's `{fdiv, L,
  float}` for `/`.
- `bs_emit`: the module map carries the marks (`fmods`, as it carries `fdivs`), and `expr/2` emits
  a marked `e_op '%'` as `{call, L, {remote, L, {atom, L, math}, {atom, L, fmod}}, [A, B]}`. It is
  a call, not an operator, so it goes in `expr/2` and not `erl_op/3`. An unmarked `%` stays `rem`,
  so a missed mark crashes with `badarith` rather than returning a wrong number, which is the
  same fail-closed choice `erl_op('/', L, C)` makes.
- `divisor_diags/4` already refuses a divisor that is provably `0.0` or `-0.0` for `%`: nothing to
  add.
- `float_remainder` leaves `bs_diag` (descriptor and message) and `float_tests`' assertion that
  pins it becomes the run-time assertion that `Wrap(-30.0)` is `-30.0`.
- `LANGUAGE.md`'s float section says what `%` means over floats.

## Not decided here

- `%` over `int | float`: ticket [83](83-a-union-operand-at-an-operator.md) already refuses a
  numeric union at any operator, `%` included; nothing changes.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [`%` over two floats](issues/103-percent-over-two-floats.md) — **allowed, with C#'s meaning:
  the truncated remainder signed by the dividend, lowered to `math:fmod/2`; `-30.0 % 360.0` is
  `-30.0`.** Raised and resolved 2026-09-25 in one round on one question, out of
  [ENG-385](https://linear.app/davewil/issue/ENG-385), which F51 filed when it refused the form
  (`float_remainder`) rather than keep emitting `rem` over floats, which crashed. The mechanism is
  F51's own for `/`: the checker marks the float pair at `op_result/5` and the emitter reads the
  mark, emitting a call because `fmod` is a function and not an operator; an unmarked `%` stays
  `rem`. A `0.0` divisor is already refused by `divisor_diags/4`. `float_remainder` is retired.
  Unbuilt — ENG-385.
```
