# F73 — under `FromJson`, a `float` position reads a JSON integer

**Status**      **in progress** — built 2026-10-10, 16 tests in `float_reads_integer_tests`;
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
- Where a union's members are tried in turn, each is asked for the value as it is
  before any is asked to read an integer as a float. `{ "v": float } | { "v": int }`
  given `1` is `{ "v" = 1 }`, as `{ "v": int | float }` is. The same holds where the
  members are tried by filling their absent `option<T>` keys.
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
- Under a wire twin, `alternatives/3` is handed each member's shared validator and then
  each member's twin (`tries/2`), so a member that holds the value unconverted answers
  first. For the same reason a wire twin that makes F61's fill attempts over several
  members asks the type's shared validator first (`fill_clause/3`).
- A wire twin's table carries the table its names were changed from, under `shared`.
  That key is how `read_clauses/3`, `tries/2` and `fill_clause/3` know they are writing
  a wire twin.
- A shared validator is now emitted only where something calls it. Until now every
  type's was emitted unless it could fill and no `ValidateAs` reached it; with a twin
  taking `FromJson`'s calls, that rule left the shared one emitted and uncalled, and
  `erlc` said so. The rule is now reachability: a root with no twin, a twin's child
  that has none, or a type or member a wire twin asks unconverted.

## What the build found

- **The first build read `{ "v": float } | { "v": int }` given `1` as `1.0`.** Found by
  the review, which ran 100,348 calls through this build and the one before it: 310
  changed a value that had been accepted, all of this shape. The float member's twin was
  asked first and converted. That is `int | float` written as two members, and ENG-616's
  fifth clause says the integer is returned. Fixed, and F73.9 and S1 pin it.
- **The fix missed members tried by filling.** A second review ran 46,372 `FromJson`
  calls through the fixed build and its parent, and six differed, all one shape:
  `{ "v": float, "w": option<int> } | { "v": int, "w": option<int>, "k": option<int> }`
  given `{"v":1}` was `{ "v" = 1.0, "w" = :nothing }` where it had been the second
  member with `1`. F61's attempts go member by member too, and each re-entered the
  twin. Fixed, and F73.9's third test and S2 pin it.
- **Where two members can both read a value and neither holds it as it is, the
  compiler's order of the members chooses.** `{ "v": float, "w": float } |
  { "v": int, "w": float }` given `{"v":1,"w":2}` is `{ "v" = 1.0, "w" = 2.0 }`, and
  `{ "v" = 1, "w" = 2.0 }` reads one integer fewer. Until now that order could not be
  seen, since every member returned the value it was given. Not decided by any ticket.
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
  16 non-blank lines where it was 20, counted as F69 counted them, without the header
  the extraction adds.
- **No float literal can be written as a type**, so F51's `{finite, …}` float part is
  reachable here only through the algebra. The clause is generated from the same guard
  as the shared validator's (`float_guards/2`), and no test reaches it.
- **No existing test or gate assertion changed.** The suite's other 1,418 tests passed
  unmodified.
- **Errors move, for input refused before and still refused.** Where the first fault
  was an integer at a `float` and a second fault follows, the second is now the one
  reported. The review counted 1,645 such inputs.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F73.1 | `{ "price": float }` given `1`, `-3`, `0`, `0.5`; a clause that adds the price to itself | `1.0`, `-3.0`, `0.0`, `0.5`; `2.0` |
| F73.2 | `FromJson<float>` and `FromJson<float \| string>` given `7`; a `list<float>`, a `map<string, float>`, a nested field set and an `option<float>` key, each given an integer; the same with the option key absent; a tagged member's `float`; members told apart by keys, and by the value's type | the float at each; the key filled with `:nothing` beside the floats; the member with its float |
| F73.3 | `9007199254740993`; `9007199254740992`; 2^60; `-9007199254740993` at the top; a 401-digit integer | refused expecting `float` at its path; read; read; refused at `[]`; refused |
| F73.4 | `{ "a": int }` given `1.0` | refused expecting `int`, as before |
| F73.5 | `ValidateAs<F>` over a term holding `1`; over one holding `1.0`; a `list<float>` holding `1` | refused expecting `float`; returned; refused at `["all"][0]` |
| F73.6 | `int \| float` given `1`, `1.5`, `9007199254740993`; a refined `int` beside `float`, given an integer inside it and one outside | `1`, `1.5`, the integer; the integer, and the float |
| F73.8 | one type with a `float` and an `option<string>` key under `FromJson`, `ValidateAs` and `ToJson` in one module, read from `{"price":2}` | the key filled and the float read, and the build prints nothing else |
| F73.9 | `{ "v": float } \| { "v": int }` given `1`, `1.5`, 2^53 + 1; the open form in a list; two members that differ at one key, given a value only one holds as it is, and one neither does; two members with absent option keys, one holding `1` and one reading it | the integer, the float, the integer; each element as its member holds it; the member that holds it; a member that reads it; the member that holds it, filled |
| F73.7 | exemplar 25f, its answers typed `float`, served a reply whose `department` confidence is written `1` | an `Evaluation` whose `department` answer is `Chosen` with `Confidence = 1.0` |

## Done when

The scenarios pass, `check-float-reads-integer.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-10

Before the build, `float_reads_integer_tests` failed 9 of its first 13 (F73.9's three came
from the two reviews, and each failed against the build it was written for); the four that passed are
the ones that assert nothing changed (the 401-digit integer of F73.3, F73.4, F73.5 and
the first test of F73.6). `check-float-reads-integer.sh` was red on R1, R2, R3 and R8:
the first three refused expecting `float`, and the replay had no such case to print. Its
`--self-test` sees twelve defects (`refused`, `unconverted`, `fields_only`, `shallow`,
`rounds`, `int_reads_float`, `validate_too`, `always_float`, `uncalled`, `first_reader`,
`first_filler`, `exemplar_only`),
all but `refused` and `uncalled` each required to be red on one case alone, and accepts
the correct outputs.

R9 came from the review, which found that no test could see a validator emitted and
never called: eunit's helper drops the build's warnings. R9 puts one type under
`FromJson`, `ValidateAs` and `ToJson` in the probe's module, and every probe's output is
compared whole. With the emission rule changed to emit a root for every `FromJson` type,
the gate was red on all eight probes, each opening with `Warning: function
bs@validate@10/2 is unused`. S1 is F73.9, and was red against the first build's emitter:
`wanted '{"v" = 1}', got '{"v" = 1.0}'`. S2 is its third test, red against the second
build's: `wanted '{"k" = :nothing, "v" = 1, "w" = :nothing}', got '{"v" = 1.0, "w" =
:nothing}'`.
F73.7 is R8: `wayfinder/prototypes/25f_replay.erl` serves the reply and prints
`whole number: ok`.
