# F73 — under `FromJson`, a `float` position reads a JSON integer

**Status**      **in progress** — built 2026-10-10, 13 tests in `float_reads_integer_tests`;
                closing it is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q18.
                Decides nothing; see *What the build found*
**Closes**      [ENG-616](https://linear.app/davewil/issue/ENG-616)
**Depends on**  F18 (`ValidateAs`), F51 (`float`), F61 (the absent option key, whose
                rebuilt values this reuses), F69 (`FromJson`)

## Why this one now

JSON has one number type, and JavaScript writes the float `1.0` as `1`. A field declared
`float` therefore read `0.5` and refused `1`, from the same sender: a type that passes
its tests and fails in service. Exemplar 25f wrote `int | float` at every such key and
carried a four-line `Widen` to undo it.

## The program

```csharp
module Prices

type F = { "price": float }
type Deep = { "all": list<float>, "by": map<string, float>,
              "one": { "t": "a", "v": float } | { "t": "b" } }
type Whole = { "a": int }
type Either = { "n": int | float }

public result<F, ValidationError> Read(string body)
Read(body) -> FromJson<F>(body)

public result<Deep, ValidationError> ReadDeep(string body)
ReadDeep(body) -> FromJson<Deep>(body)

public result<Whole, ValidationError> ReadWhole(string body)
ReadWhole(body) -> FromJson<Whole>(body)

public result<Either, ValidationError> ReadEither(string body)
ReadEither(body) -> FromJson<Either>(body)

public result<F, ValidationError> Check()
Check() -> ValidateAs<F>(Loose())

private term Loose()
Loose() -> { "price" = 1 }
```

```
$ bsc Prices Read '"{\"price\":1}"'
{"price" = 1.0}
$ bsc Prices Read '"{\"price\":0.5}"'
{"price" = 0.5}
$ bsc Prices ReadDeep '"{\"all\":[1],\"by\":{\"k\":2},\"one\":{\"t\":\"a\",\"v\":3}}"'
{"all" = [1.0], "by" = {"k" = 2.0}, "one" = {"t" = "a", "v" = 3.0}}
$ bsc Prices Read '"{\"price\":9007199254740993}"'
(:error, {Kind = :'ValidationError', Expected = "float", Path = ["["price"]"], Reason = :mismatch})
$ bsc Prices ReadWhole '"{\"a\":1.0}"'
(:error, {Kind = :'ValidationError', Expected = "int", Path = ["["a"]"], Reason = :mismatch})
$ bsc Prices ReadEither '"{\"n\":1}"'
{"n" = 1}
$ bsc Prices Check
(:error, {Kind = :'ValidationError', Expected = "float", Path = ["["price"]"], Reason = :mismatch})
```

Before this feature the first and third were refused, expecting `float`, at `["price"]`
and at `["all"][0]`. The other five print what they printed before.

## The rule

- Under `FromJson<T>`, an integer at a position whose type holds floats is read as the
  float equal to it, wherever the position sits: the top, a key, a list element, a
  `map<K, V>` value, a union member.
- An integer the type holds as an integer stays one. `int | float` given `1` is `1`, and
  no float is looked for, so an integer of any size is returned as it was.
- An integer no float equals is refused, as before: `:mismatch` at its own path,
  expecting the position's type. `9007199254740993`, which is 2^53 + 1, is the first.
  An integer past the largest float is refused the same way.
- The other direction does not exist. An `int` position given `1.0` is refused, as
  before.
- `ValidateAs<T>` over a term is unchanged, and so is `ToJson<T>`'s guard. In a term a
  program built, `1` is an `int` because the program said so. This is the one
  conversion `FromJson` makes that `ValidateAs` does not.

## What changed

- `bs_emit:validator_forms/1` gives a type a **wire twin**, `bs@validate@N@w`, where a
  `FromJson` root reaches it and it holds a position that could read an integer, or has
  one beneath it. `…@t` calls the twin's root. This is the arrangement F61 made for
  `ToJson`'s strict twin, and `twin_table/4` is now shared by the two.
- A twin's validator is the shared one with one clause more, after the type's own `int`
  clauses (`read_clauses/3`): an integer is handed to `bs@validate@exact/1`, and the
  float it answers is returned if it is one of the type's floats.
- `bs@validate@exact/1` is generated once per module that has a twin: `float/1` of the
  integer, kept only if `trunc/1` of it is the integer again, and `none` where `float/1`
  raises.
- A twin returns its children's values rebuilt, by the mechanism F61 added for filled
  keys: the set of types that may return another value is F61's with these added.
- A shared validator is now emitted only where something calls it. Until now every
  type's was emitted unless it could fill and no `ValidateAs` reached it; with a twin
  taking `FromJson`'s calls, that rule left the shared one emitted and uncalled, and
  `erlc` said so. The rule is now reachability: a root with no twin, or a twin's child
  that has none.

## What the build found

- **"Has an exact float" is read as equality, not as JavaScript's safe range.** 2^53 + 1
  is refused and 2^60, which a float holds exactly, is read. ENG-616 says *"when the
  integer has an exact one"*; a rule of "at most 2^53" would refuse integers that lose
  nothing.
- **An integer outside a refined `int` beside `float` is read as the float.** With
  `type Pct = int where value >= 0 and value <= 100`, a `Pct | float` position given
  `50` is `50` and given `200` is `200.0`. ENG-616's fifth clause covers `int | float`;
  this follows from the same rule and the issue does not name it.
- **`0` is read as `0.0`, never `-0.0`.** JSON's `-0` decodes to the integer `0`.
- **Exemplar 25f is rewritten on it**, which ENG-616 does not ask for. Its three answer
  types say `float` where they said `int | float`, and `Widen` is deleted: `decode.bs` is
  16 non-blank lines where it was 20.
- **No float literal can be written as a type**, so F51's `{finite, …}` float part is
  reachable here only through the algebra. The clause is generated from the same guard
  as the shared validator's (`float_guards/2`), and no test reaches it.
- **No existing test or gate assertion changed.** The suite's other 1,418 tests passed
  unmodified.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F73.1 | `{ "price": float }` given `1`, `-3`, `0`, `0.5`; a clause that adds the price to itself | `1.0`, `-3.0`, `0.0`, `0.5`; `2.0` |
| F73.2 | `FromJson<float>` and `FromJson<float \| string>` given `7`; a `list<float>`, a `map<string, float>`, a nested field set and an `option<float>` key, each given an integer; the same with the option key absent; a tagged member's `float`; members told apart by keys, and by the value's type | the float at each; the key filled with `:nothing` beside the floats; the member with its float |
| F73.3 | `9007199254740993`; `9007199254740992`; 2^60; `-9007199254740993` at the top; a 401-digit integer | refused expecting `float` at its path; read; read; refused at `[]`; refused |
| F73.4 | `{ "a": int }` given `1.0` | refused expecting `int`, as before |
| F73.5 | `ValidateAs<F>` over a term holding `1`; over one holding `1.0`; a `list<float>` holding `1` | refused expecting `float`; returned; refused at `["all"][0]` |
| F73.6 | `int \| float` given `1`, `1.5`, `9007199254740993`; a refined `int` beside `float`, given an integer inside it and one outside | `1`, `1.5`, the integer; the integer, and the float |
| F73.7 | exemplar 25f, its answers typed `float`, served a reply whose `department` confidence is written `1` | an `Evaluation` whose `department` answer is `Chosen` with `Confidence = 1.0` |

## Done when

The scenarios pass, `check-float-reads-integer.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-10

Before the build, `float_reads_integer_tests` failed 9 of 13; the four that passed are
the ones that assert nothing changed (the 401-digit integer of F73.3, F73.4, F73.5 and
the first test of F73.6). `check-float-reads-integer.sh` was red on R1, R2, R3 and R8:
the first three refused expecting `float`, and the replay had no such case to print. Its
`--self-test` sees nine defects (`refused`, `unconverted`, `fields_only`, `shallow`,
`rounds`, `int_reads_float`, `validate_too`, `always_float`, `exemplar_only`), all but
the first each required to be red on one case alone, and accepts the correct outputs.
F73.7 is R8: `wayfinder/prototypes/25f_replay.erl` serves the reply and prints
`whole number: ok`.
