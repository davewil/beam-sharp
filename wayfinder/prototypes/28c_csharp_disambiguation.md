# 28c — What C# actually does with `F(Foo < b, c > d)`

Ticket 28's first bullet says C#'s rule "is specified (ECMA-334): after parsing a candidate type
argument list, the token that follows decides", and asks to **confirm it is expressible for
beam-sharp's grammar rather than assuming**. Confirming that needs two things: what the rule
actually decides, and whether an LALR(1) grammar can decide the same way.

This file measures the first. [`28a`](28a_bracket_disambiguation.escript) measures the second.

Measured `local` — run here, not cited.

- **dotnet 9.0.306**, macOS (Apple Silicon), `net9.0`, 2026-08-13.

## Method

The difficulty with testing this is that the two readings need contradictory declarations: the
comparison reading needs `Foo` to be a *value*, the generic reading needs it to be a *generic
method*. So instead of making both compile, put a generic method in scope and let **the error text
reveal which reading the parser took**:

- `CS0019 — operator '<' cannot be applied to 'method group' and 'int'` → the parser produced a
  **comparison**, and binding then failed because a method group is not comparable.
- `CS0118 — 'b' is a variable but is used like a type` → the parser produced a **type-argument
  list**, and binding then failed because `b` is not a type.

```csharp
using System;

class P {
    static object Foo<A, B>(int x) => null;
    static void F(bool p, bool q) { Console.WriteLine("TWO ARGS"); }
    static void F(object o)       { Console.WriteLine("ONE ARG"); }

    static void Main() {
        int b = 1, c = 2, d = 3;
        F(Foo < b, c > d);          // CASE A: bare identifier follows '>'
     // F(Foo < b, c > (d));        // CASE B: '(' follows '>'
    }
}
```

`dotnet build` each in turn.

## Result

| Case | Source | Diagnostic | Reading the parser took |
|---|---|---|---|
| A | `F(Foo < b, c > d)` | `CS0019: Operator '<' cannot be applied to operands of type 'method group' and 'int'` | **comparison** |
| B | `F(Foo < b, c > (d))` | `CS0118: 'b' is a variable but is used like a type` (and the same for `c`) | **generic call** |

So the rule is real, it is a **follow-token test applied after a candidate type-argument list**, and
it gives the right answer in both directions. C# is not confused here and never was; the C++
comparison in the ticket's framing overstates the problem for C#.

## Why it is nevertheless unavailable to beam-sharp

The rule requires the parser to scan a candidate type-argument list of **arbitrary length**, reach
the token after the closing `>`, and only then decide what it has been reading. That is unbounded
lookahead plus a re-decision.

`yecc` is LALR(1). It must decide **at the `<`** whether to shift into a type-argument list, with
one token of lookahead — which is `b`, and is compatible with both readings. Variant D in
[`28a`](28a_bracket_disambiguation.escript) is exactly this: the production is present, the parser
commits at `<`, and the parse dies at `d`.

That is not a defect in the encoding. It is what an LALR(1) grammar *can* do with a rule whose
decision point is after an unbounded suffix.

beam-sharp's parser is `leex`/`yecc` because ticket 13 chose the Erlang Abstract Format and those
ship with OTP. So the borrowed rule is understood, correct, and **refused for a reason internal to
this language** — a tier-3 divergence under the map's amended heuristic, not a failure to look.

## The consolation, which is most of the point

The two rules **agree on case A**, which is the shape that occurs. They differ on case B — and in
beam-sharp `Foo<b, c>` is not an instantiable form at all, because ticket 28 §1 removes explicit
instantiation from user code entirely. **The reading they differ on does not exist here to be
chosen**, so the divergence is not observable in any beam-sharp program.

## Reproducing

```sh
mkdir cs && cd cs
cat > probe.csproj <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>disable</Nullable>
  </PropertyGroup>
</Project>
EOF
# paste the Program.cs above, then:
dotnet build -v q --nologo
# swap the commented line and build again
```
