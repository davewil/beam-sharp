# 80 — Prior art on an `int` flowing where a `float` is expected: Erlang, Dialyzer, Elixir, Gleam, C#, F#

Research for [ticket 80](../issues/80-does-an-int-flow-where-a-float-is-expected.md), 2026-09-15.
Asked by David while Round 1 was open, before answering it: *"What do Erlang, Elixir, Gleam etc.
do?"*

**The survey's answer: every language that types the BEAM takes the BEAM's reading, and the two
languages that take C#'s are the two that run on a VM with a real conversion instruction.** Gleam
and Elixir's type system both refuse an integer where a float is expected. Erlang's own equality
keeps them apart and its compiler now warns on the float-zero pattern. Dialyzer is the one BEAM
tool that lets `0` out of a `float()` function, and it does so by construction. C# converts, and
the conversion is real: the value that arrives is a `Double`. F# 6 added the same conversion at
sites where the expected type is known, off-by-default warning and all — which is ticket 80's
second reading, adopted late by a language that had refused it for fifteen years.

**Everything below is MEASURED or CITED, never both in one sentence.** *Measured* means a probe
run for this file on this machine produced the output quoted. *Cited* means a primary source was
fetched for this file and says it.

| arm | instrument | what it can show |
|---|---|---|
| Erlang | `erl`/`erlc` OTP 28.5 (mise, the pinned toolchain) | **measured**, entirely; the OTP 27 zero change **cited** from [erlang.org, data types](https://www.erlang.org/doc/system/data_types.html), fetched 2026-09-15 |
| Dialyzer | OTP 28.5, a PLT built for this file over `erts kernel stdlib` | **measured** |
| Elixir | 1.20.4 on OTP 29 (Homebrew's, not the pinned toolchain — the type system is the compiler's, not the VM's) | **measured**; the reference page ([hexdocs, gradual set-theoretic types](https://elixir.hexdocs.pm/gradual-set-theoretic-types.html), fetched 2026-09-15) lists `integer()` and `float()` as two basic types and says nothing about their relation, so the measurement stands alone |
| Gleam | 1.18.1, `gleam_stdlib` 1.0.5, generated Erlang read from `build/` | **measured**; [tour.gleam.run, floats](https://tour.gleam.run/basics/floats/), fetched 2026-09-15, **cited** for the operator rule |
| C# | .NET SDK 9.0.306, a console project | **measured**; [the C# standard, §10.2.3](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/conversions), fetched 2026-09-15, **cited** |
| F# | `dotnet fsi` from the same SDK | **measured**; [RFC FS-1093](https://github.com/fsharp/fslang-design/blob/main/FSharp-6.0/FS-1093-additional-conversions.md), fetched 2026-09-15, **cited** |

The probe is ticket 80's program in each language: a `Mean` over a list of ints declared to
return a float whose empty clause returns `0`, a `Verdict` whose first head is the float literal
`0.0`, and a mixed `int + float`.

## Erlang — two values, one order, and a warning on the zero

Measured, OTP 28.5:

```
1 + 1.0        2.0
4 / 2          2.0      (Erlang's `/` is always float division; `div` is the integer one)
1 div 2        0
0.0 =:= -0.0   false
0.0 == -0.0    true
```

The module

```erlang
-spec v(float()) -> atom().
v(0.0) -> empty;
v(_) -> some.
-spec m(list(integer())) -> float().
m([]) -> 0;
m(Xs) -> lists:sum(Xs) / length(Xs).
```

compiles, and `erlc` warns on line 4:

```
pa.erl:4:3: Warning: matching on the float 0.0 will no longer also match -0.0 in OTP 27.
If you specifically intend to match 0.0 alone, write +0.0 instead.
```

Then `pa:v(0)` is `some`, `pa:v(0.0)` is `empty`, and `pa:m([])` is `0` — an integer out of a
function specced `float()`, and the pattern `0.0` does not see it. This is the fact ticket 80's
program turns on, and Erlang states it in one line of the data-types page (cited): *"Both integers
and floats share the same linear order. That is, `1` compares less than `2.4`, `3` compares greater
than `2.99999`, and `5` is equal to `5.0`"* — under `==`. Under `=:=`, the same page: *"Prior to
OTP 27, the term equivalence operators had a bug where they considered `0.0` and `-0.0` to be the
same term."* A clause head matches by term equivalence, so since OTP 27 a `0.0` head matches
`+0.0` alone, and the compiler says so.

## Dialyzer — the one BEAM tool that lets the `0` out

Measured, OTP 28.5, PLT over `erts kernel stdlib`, on the module above:

```
  Proceeding with analysis... done in 0m0.05s
done (passed successfully)
```

No warning for `m([]) -> 0` under `-spec m(...) -> float()`. That is success typing doing what it
was built to do: the function's success type is `number()`, the spec `float()` overlaps it, and
Dialyzer only reports a spec that *cannot* be right. So the BEAM's type tool is not a precedent
for either reading — it does not check the question.

## Elixir — the type system refuses, and infers the integer through the call

Measured, Elixir 1.20.4:

```elixir
def v(0.0), do: :empty
def v(_), do: :some
def w(x) when is_float(x), do: x
def m([]), do: 0
def m(xs), do: Enum.sum(xs) / length(xs)
def call1, do: w(0)
def call4, do: w(m([]))
```

Two type warnings and one pattern warning:

```
warning: incompatible types given to w/1:
    w(0)
given types:
    -integer()-
but expected one of:
    float()

warning: incompatible types given to w/1:
    w(m([]))
given types:
    -integer()-
but expected one of:
    float()

warning: pattern matching on 0.0 is equivalent to matching only on +0.0. Instead you must match on +0.0 or -0.0
```

The second is the interesting one: the checker inferred `m([])` as `integer()` from its first
clause and carried that into `w`'s guard, with no annotation anywhere. `integer()` and `float()`
are two types with nothing between them — the BEAM's reading, on the BEAM's own `+`, which
promotes at runtime: `1 + 1.0` is `2.0`, `4 / 2` is `2.0`, `div(4, 2)` is `2` (measured). The
runtime results are unchanged; only the compile-time verdict differs from Erlang's silence.

## Gleam — two types, two operator sets, and `0.0` lowered to `+0.0`

Cited (tour, floats): *"Gleam's numerical operators are not overloaded, so there are dedicated
operators for working with floats."* Measured, 1.18.1, on

```gleam
pub fn mean(xs: List(Int)) -> Float {
  case xs {
    [] -> 0
    _ -> 1.0
  }
}
pub fn mixed(a: Int, b: Float) -> Float { a + b }
```

three errors:

```
error: Type mismatch
The type of this returned value doesn't match the return type annotation of this function.
Expected type:  Float
Found type:     Int

error: Type mismatch
This case clause was found to return a different type than the previous one ...

error: Type mismatch
The + operator expects arguments of this type:  Int
But this argument has this type:  Float
Hint: The +. operator can be used with Floats
```

With `0.0` and `int.to_float(6) /. int.to_float(2)` it compiles, and the Erlang it generates
(read from `build/dev/erlang/pa80/_gleam_artefacts/pa80.erl`) is the thing to notice:

```erlang
-spec verdict(float()) -> binary().
verdict(M) ->
    case M of
        +0.0 -> ~"empty";
        _    -> ~"some"
    end.
```

Gleam's `0.0` pattern lowers to `+0.0`, silently: no warning from `erlc`, and `-0.0` takes the
other arm. Its `/.` lowers to a `case` on the divisor with `+0.0` and `-0.0` arms returning zero,
because (cited) *"Division by zero will not overflow, but is instead defined to be zero."* Gleam
is the strictest arm: no conversion, no shared operator, and a spelling for the zero question that
B# will meet the day it lowers its first float pattern.

## C# — the conversion is real, and the pattern matches by value

Cited, the standard §10.2.3, *Implicit numeric conversions*: *"From `int` to `nint`, `long`,
`float`, `double`, or `decimal`."* And: *"The pre-defined implicit conversions always succeed and
never cause exceptions to be thrown."* Measured, .NET 9.0.306:

```csharp
static double Mean(List<int> xs) => xs.Count == 0 ? 0 : (double) xs.Sum() / xs.Count;
static string Verdict(double m) => m switch { 0.0 => "empty", _ => "some" };
static double Mixed(int a, double b) => a + b;
```

```
Verdict(Mean([]))              empty
Mean([2, 4])                   3
Mixed(1, 1.5)                  2.5
7 / 2                          3
Verdict(-0.0)                  empty
((object) Mean([])).GetType()  Double
```

Three things for ticket 80. The `0` in `Mean` arrives as a `Double`, not an `int` boxed in a
double-shaped hole: C# emits the conversion (`conv.r8`) at the site, which is the emitted `float/1`
the ticket's second reading prices. `7 / 2` is `3` — the operand-typed `/` ticket 38 borrowed. And
`Verdict(-0.0)` is `empty`: a constant pattern on a `double` compares by IEEE equality, so C# has
no zero question at all.

## F# — refused for fifteen years, then added, at known-type sites only

Cited, RFC FS-1093 (F# 6, 2021): the conversions added are *"`int32` → `int64`, `int32` →
`nativeint`, and `int32` → `double`"*; *"Type-directed conversions are only activated if the types
precisely match based on known type information at the point of resolution"*; the warning is
FS3389, *"OFF by default"*; and the motivation named is *"Using integer literals in floating point
data such as `[| 1.1; 3.4; 6; 7 |]`"*. Measured, `dotnet fsi` 9.0.306:

```fsharp
let mean (xs: int list) : float = match xs with | [] -> 0 | _ -> 1.0
let v (m: float) = match m with | 0.0 -> "empty" | _ -> "some"
```

prints `0.0 Double` and `empty`: the `0` is accepted against the annotated `float` and arrives
converted. Beside it, `let mixed (a: int) (b: float) = a + b` is `error FS0001: The type 'float'
does not match the type 'int'` — the conversion is at the *expected-type* site only, never at an
operator, which is exactly the line the RFC draws (cited: *"A non-array-literal expression of type
`int[]` still needs to be explicitly converted to `int64[]`"*).

F# is the arm that matters most for the second reading, because it is the one language here that
*chose* it after living without it: the conversion is scoped to sites where the checker already
knows the expected type, the compiler emits the real conversion, and operators are left strict.
That is a smaller version of C#'s rule, and its cost in the compiler is the expected-type channel
ticket 80 names.

## What the survey settles, and what it does not

- **The BEAM's reading has every BEAM precedent**: Gleam refuses at the type, Elixir refuses at
  the type, Erlang keeps the values apart and warns on the zero, and the runtime promotes only
  inside an arithmetic operator. Dialyzer's silence is not a vote; it does not ask.
- **C#'s reading has C# and F# 6**, both on a VM with a conversion instruction, both emitting it.
  F# scopes it to known-type sites and leaves operators strict — a third shape, narrower than
  C#'s, that ticket 80's round 2 would reach under the second reading.
- **The zero is a separate, smaller question that the survey found and ticket 80 does not ask.**
  On OTP 27+, a `0.0` head matches `+0.0` alone; Erlang warns, Elixir warns, Gleam lowers to `+0.0`
  without a word, C# matches both. B#'s `Verdict(0.0)` has to lower to *something*, and each of the
  three BEAM answers is on the table. It is recorded on the feature ([ENG-378](https://linear.app/davewil/issue/ENG-378))
  as owed, and raised as its own ticket only if the feature cannot take Gleam's spelling as a
  lowering detail.
- **Not surveyed**: OCaml (`+.`, the shape Gleam took), Haskell (literal polymorphism through
  `Num`), Rust and Go (no implicit conversion). None runs on the BEAM and none is a source the
  borrow heuristic ranks; they would add weight to the first reading and nothing to the second.
