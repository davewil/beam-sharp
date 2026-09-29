# 116 — Is arithmetic over a type variable refused?

Type: grilling
Status: open — [ENG-579](https://linear.app/davewil/issue/ENG-579). Raised 2026-09-29 by the F67
build ([ENG-551](https://linear.app/davewil/issue/ENG-551)), which refuses an arithmetic operand
with no numeric part and left a type variable as it found it
Blocked by: —

## Why this is raised

F67 builds [112](112-an-arithmetic-operand-with-no-numeric-part.md) A4: `+ - * / %` refuse an
operand with no `int` or `float` part. Inside a polymorphic body the checker sees a type variable
as an opaque atom (F45), so read literally the rule refused `T + 1`, a program that compiled and
ran before F67. The build kept it compiling, because two decided rules point different ways and
neither names this case:

- [27](27-parametric-polymorphism.md) §2 and §3 make a variable opaque and unbounded: *"a type
  variable is a slot for values you carry; a union is a slot for values you examine"*, and §3 names
  arithmetic as a capability only a bound would grant, with bounds deferred to
  [16](16-ad-hoc-polymorphism.md). Read that way `a + 1` over `T` is refused, since the body must
  hold for every `T`, `string` included.
- [112](112-an-arithmetic-operand-with-no-numeric-part.md) A4 refuses an operand with *no* numeric
  part, and [83](83-a-union-operand-at-an-operator.md) left an operand with a numeric part beside
  another (`int | :none`, `term`) compiling. A variable that may be `int` sits nearer that leave.

## The question

```csharp
module Scale

public int Bump<T>(T a)
Bump(a) -> a + 1

public int Demo()
Demo() -> Bump("x")
```

Today, and after F67, this compiles: `Bump(4)` is `5`, and `Bump("x")` is
`crashed: error:badarith`.

Under **refuse**, `Bump` is refused at its `+` as `non_numeric_operand`, naming the variable `T`
rather than `:'T'`, the atom the body sees. `Bump(4)` stops compiling. The delta: drop the
variable's exemption in `bs_check:operand_verdict/2`, and print a variable by its name in the
refusal's `type`.

Under **keep**, nothing changes, and F67's *Leaves* line records the exemption as decided.

**Also here, whichever the answer:** an atom literal spelled like a variable in scope, `:'T'` in a
function generic over `T`, is the same atom the checker uses for the variable, so under *keep* it
escapes the refusal and raises `badarith`. Separating the two needs F45's representation of a
variable to change, not F67's check.
