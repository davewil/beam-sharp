# F51 — `float`, the eighth part

**Status**      **done 2026-09-16** · [ENG-378](https://linear.app/davewil/issue/ENG-378) — 36 tests
                in `float_tests`, 1008 in the suite, up from 972; new gate `check-float.sh`,
                seen red on the tree before the build, with four stubs in its `--self-test`;
                `examples/Stats/stats.bs` and two roster rows; the clean-pair evidence is the
                dated line at the end of this file
**Implements**  [ticket 69](../../wayfinder/issues/69-does-the-language-have-float.md) (`float` is a
                type), [ticket 80](../../wayfinder/issues/80-does-an-int-flow-where-a-float-is-expected.md)
                (nothing flows between the parts) and
                [ticket 81](../../wayfinder/issues/81-how-is-an-int-converted-to-a-float.md)
                (`Float.FromInt`). It **decides nothing**
**Depends on**  F2 (the interval part this one sits beside), F24 (the boundary kind test),
                F26 (`/` as `div`, whose door 38 §4 held open), F32 (the reserved qualifiers
                and their inlining), F42 (the foreign-return guard read part by part)
**Leaves**      `Int.FromFloat`, named by 81 and not decided; `%` over two floats, refused and
                [ENG-385](https://linear.app/davewil/issue/ENG-385); float intervals, so a
                float guard credits nothing; a float refinement, refused as opaque; the
                runner's `crashed: error:function_clause` for a float reaching an `int`
                parameter

## What ships

```csharp
module Stats

public float Mean(list<int> samples)

Mean([]) -> 0.0
Mean(xs) -> Float.FromInt(List.Sum(xs)) / Float.FromInt(List.Length(xs))

public atom Verdict(float mean)

Verdict(0.0) -> :empty
Verdict(_)   -> :some
```

```
$ bsc --src-root examples examples/Stats Mean '[2, 4]'
3.0
$ bsc --src-root examples examples/Stats Check '[]'
:empty
```

Before this feature the program was refused four times over, in this order: `0.0` did not lex
(`syntax error before: '.'`), `float` was not a builtin type, `Float` was not a reserved
qualifier, and `/` lowered to `div` unconditionally. Measured 2026-09-16 on `cf23d2d` before a
line was written.

## The compiler delta

1. **`bs_types`** — an eighth part, `floats`, a finite or cofinite set of literals: the atom
   part's shape, so `Verdict(0.0)` is exact under `=:=` and `float \ 0.0` is open. `term()`
   holds `{cofinite, []}`, `none()` holds `{finite, []}`, and every function that destructures
   a type — `is_none`, `is_open`, the three set operations, `parts`, `pat_parts`, `hd_parts`,
   `guard_buckets` (a `float` bucket, disjoint from `int`), `constituents`, `same_bucket`, the
   three `Kind` readers — carries it. `float_lit/1` and `float_top/0` are the constructors.
2. **`bs_lexer.xrl`** — `{D}+\.{D}+([eE][+-]?{D}+)?`. The digit after the dot is required,
   so `1..5` is three tokens and `1.` is never a float. `1e5` is not a float: no dot, no float.
3. **`bs_parser.yrl`** — `float` in expression and pattern position, `-` before either
   folding into the literal, and unary minus as its own node, `e_neg` (finding 2 below).
   Yecc: 5 shift/reduce, 0 reduce/reduce, before and after.
4. **`bs_check`** — `builtin(float)`; a float literal's type and pattern type; `op_result/5`,
   which types an operator by its operands' parts: two ints as before, two floats as `float`
   for `+ - * /` and as `float_remainder`, a refusal, for `%` (finding 6), an inhabited `int`
   beside an inhabited `float` as `mixed_operands` carrying the part each side lies in and the
   `int` literal's float spelling where it has one, anything else as `op_type/1` always
   answered; `mixed_guard_diags/3`, the same question asked of a guard (finding 3), with the
   dead-guard warning the int reading would add withheld beside it; `divide_by_zero` over
   `0.0` and `-0.0` too; `Float` in
   `reserved_qualifiers/0`, `{'Float', 'FromInt', 1}` in `reserved_table/0` with the
   signature `int -> float`. Each `/` between two floats returns an `fdiv` note on the
   diagnostic channel, partitioned out where `fname` notes are and put on the module map as
   `fdivs`, keyed by the operator's position.
5. **`bs_emit`** — `erl_op/3` reads `fdivs`: a marked `/` is the BEAM's `/`, every other `/`
   is `div`, so a site the checker did not mark errs towards `badarith` on a float rather
   than a float where `int` was promised. A `p_float` head is the literal, and at zero the
   signed spelling (finding 4). `Float.FromInt(n)` is `erlang:float(N)` at the site, through
   `inlined_bif/1`, with no generated function. A public `float` parameter gets
   `erlang:is_float/1` where the head does not pin a float literal (`float_guard/3`, beside
   `int_guard/6`); the foreign-return test gains `float_tests/3`; the spec gains
   `float_parts/1`, which widens a literal set to `float()` as a cofinite atom set widens to
   `atom()`; the validator gains `float_clauses/1`.
6. **`bs_diag`** — `mixed_operands` renders what the checker decided: *`/` in Mean has a
   `float` on its left and an `int` on its right — nothing converts between the two: write
   the conversion, `Float.FromInt(n)`, on the `int` side*, then *or write `2.0` to make the
   literal a float* where the checker found a literal. `return_not_declared` adds *`0` is an
   `int`; the float is `0.0`* when an `int` literal is returned where `float` alone is
   declared, which is the advice ticket 80's answer promised, read off the two types the
   frozen term already prints. `float_remainder` names `%` over two floats.
   `unknown_builtin`'s list names `float`.

## Six findings, none of them in the ticket

1. **The atom part's set operations cannot be borrowed.** `ordsets` and `lists:usort/1`
   compare with `==`, under which `0.0` and `-0.0` are one element; a clause head matches
   with `=:=`, under which they are two on OTP 27+. Reused, they proved `Which(-0.0)`
   unreachable beside `Which(0.0)`. The float part has `fl_union/2`, `fl_intersect/2` and
   `fl_subtract/2` over exact membership, and `a_negative_zero_head_is_its_own_case_test`
   is the assertion.
2. **Unary minus was `0 - e`, and that is a mixed pair.** The parser desugared `-x` to a
   subtraction from the integer zero, which under ticket 80 is an `int` beside a `float`
   whenever `x` is one. `-x` is `e_neg` now, typed by its operand and emitted as the BEAM's
   unary minus, which also makes `-0.0` from a variable the negative zero that `0 - 0.0`
   is not. A negated float literal folds to the literal so `Sign(-1.5)` is a head.
3. **A guard is never typed, and the int reading empties the float before anyone asks.**
   `guard_diags/2` refuses calls and switches in a guard and `alternatives/1` reads what a
   guard credits; nothing ran `type_of/3` over one. Typed against the clause's domain, the
   mixed pair still vanished: `x < 0` over a `float` had been read as an int comparison,
   `x` narrowed to `none`, and `none` lies inside both parts. The guard is typed against
   the domain BEFORE it narrows anything, `Residual ∩ Base`, threaded to `clause_diags/5`
   beside the body's. It matters at the emitter, where ENG-330 conjoins `is_integer/1`
   onto `x < 0` and a float clause would never have matched.
4. **The zero head.** `{float, L, 0.0}` in a pattern draws `erl_lint`'s `match_float_zero`
   on OTP 28.5 and `{op, L, '+', {float, L, 0.0}}` does not, with the same meaning, measured
   before the build with `compile:forms/2`. The emitter writes the signed form for either
   zero, reading the sign bit off the float's bytes, and `bsc` relays the platform's
   warnings, so `the_float_zero_head_draws_no_warning_test` and the gate's `bare_zero` stub
   both see the bare form. A lowering detail, as the issue allowed; no ticket raised. The
   same spelling serves the validator's `=:=` and the foreign-return test, through one
   `float_form/2`, because `erl_lint` warns on the bare zero in a guard as in a pattern.
5. **The switch arm, found by the advisor's review.** The mixed-pair reading was wired where
   a clause's body is typed, which a switch arm never reaches: `m when m < 0 => :negative`
   over a `float` subject compiled with a dead-guard warning and, with ENG-330's `is_integer`
   conjoined onto the arm, `Kind(-1.5)` answered `:other`. The arm walker now asks the same
   question against the arm's pre-guard scope and withholds the same warning — the memory
   note *a pattern refusal must cover the switch arm too*, made concrete once more.
6. **`%` over two floats, found by the spec review.** The first cut typed it `int` and let
   `rem` crash at run time. Ticket 38 decided the remainder over ints and nothing decided it
   over floats, so `x % 2.0` is refused as `float_remainder` and the question is
   [ENG-385](https://linear.app/davewil/issue/ENG-385), with `math:fmod/2` as the platform's
   one candidate.

## Scenarios

| id | what | assertion |
|---|---|---|
| F51.1 | `Mean([2, 4])`, `Mean([])`, `Slash(-7, 2)` in one module, `Check([])` | `3.0`, `0.0`, `-3`, `:empty` |
| F51.2 | the literal in every spelling `float_to_list/2` prints; `1..5`; `-x`, `-1.5` in a head | reads back; three tokens; the BEAM's negation |
| F51.3 | `Verdict(0.0)` against `0.0`, `-0.0`, `1.5`; no warning through the CLI; `-0.0` as its own head | `+0.0` alone; `:empty` exactly; three answers |
| F51.4 | `Mean([]) -> 0`; one conversion dropped; every operator both ways; a refused operand; `x < 0` in a guard; `x < 0.0` selecting and crediting nothing | `return_not_declared` with `0` and *the float is `0.0`*; `mixed_operands` naming `Float.FromInt(n)` and `2.0`; one error for the refused operand, and one diagnostic alone for the guard; `inexhaustive` without the catch-all |
| F51.4b | `x % 2.0`; `x % 2` over ints | `float_remainder`; compiles |
| F51.5 | `Float.FromInt` inlined; over a `float`; `Float.Of`; `module Float` | no `Float` import, `erlang:float/1` present; `arg_not_accepted`; `unknown_reserved_operation`; refused as reserved |
| F51.6 | `term Id(float f)`; `float Down(term t)`; `int \| float` dispatched; a literal alone; `--api`; `list<float>` and `(float, int)` | passes; refused; three answers; `(float \ (0.0))`; prints `float`; compose |
| F51.7 | a public `float` parameter; a float at an `int` parameter; a pinned head; the spec; a foreign `float` return, true and lying | `function_clause` for `1` and `one`; still `function_clause`; no test added; `float()`; `3.0` and `{case_clause, 3}` |
| F51.8 | `ValidateAs<float>`, `ValidateAs<list<float>>`, `ToJson<float>` | the record naming `float` at `[]` and `["[1]"]`; `1.5` and `1.0e20` |
| F51.9 | `x / 0.0`; `x / y` | `divide_by_zero`; compiles |
| F51.10 | `0.0` as a switch arm; `m < 0` and `m < 0.0` as arm guards over a float | selects, with a catch-all; `mixed_operands` alone, and selects |
| F51.11 | `check-float.sh` | six probes; four stubs — `float_div`, `no_refusal`, `hollow_top`, `bare_zero` — each seen red, the correct form green |

## The gate

`check-float.sh` compiles ticket 69's program and three neighbours and asserts six values by
the text a person reads: `3.0`; `-3` from `-7 / 2` in the module that also divides floats,
which a lowering decided per module rather than per site fails; the mixed-pair refusal by its
sentence; `1.5` through a `term` parameter, which a `term()` with an empty float part
refuses; exactly `:empty` from `Verdict(0.0)`, which a bare zero head pads with `erl_lint`'s
warning; and `return_not_declared` for `Mean([]) -> 0`. The issue's lexer stub — `1..5` read
as `1.` and `.5` — has no probe, because no B# form puts a digit before `..`; the eunit suite
asks the lexer directly.

## Out of scope

- **`Int.FromFloat`** — named by ticket 81, truncate or round undecided, asked when a program
  needs it. `Int` is not reserved until then.
- **`%` over two floats** — refused, [ENG-385](https://linear.app/davewil/issue/ENG-385).
- **The seven `Kind` readers.** Each of the seven sites that reads a record's discriminator
  gained `floats := {finite, []}` in its map pattern, as each gained `funs := []` for F46; one
  helper in `bs_types` would gather them, and the next part will want it (standards review).
- **A relational pattern over a `float` parameter.** `Sign(>= 0)` under `public atom
  Sign(float x)` is a vacuous clause with a warning, not a refusal: the pattern-position
  cousin of the mixed pair, unreached by this feature.
- **The gate's `BAD` stub** carries the refusal's first three lines and not the `0.0` advice
  line added in review; the judge matches the first line, so the stub still discriminates.
- **`mixed_guard_diags/3`'s catch.** It catches everything the typer raises over a guard, not
  only the qualified call the comment names; every such raise is a form `guard_diags/2`
  already refuses, but the net is wider than its reason.
- **Float intervals.** `comparison/1` reads int literals only, so `x < 0.0` selects and credits
  nothing; a clause set over `float` closes with a catch-all, as one over `atom` does, and
  `LANGUAGE.md` §4 and `TOUR.md` chapter 3 say so. A refinement `float where value > 0.0` is
  refused as `opaque_refinement` for the same reason. Ticket 80 listed both under *not decided
  here*.
- **The runner's report for `Bump(1.5)`.** Still `crashed: error:function_clause`, measured
  after the build; naming the kind the boundary saw is a change to `bs_run`, outside the
  mechanism the issue lists.
- **`-x` where `x` is not `int` or `float`.** Typed `int`, as `0 - x` always was; a `term`
  operand at an operator was unchecked before this feature and is unchecked after it.
