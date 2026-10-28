# 119 — Can a clause head tell a type variable from an `int`?

Type: grilling
Status: resolved 2026-10-28 — [ENG-926](https://linear.app/davewil/issue/ENG-926). Raised
2026-10-25 by the fix for [ENG-881](https://linear.app/davewil/issue/ENG-881); one question
Blocked by: —

## Why this is raised

Until ENG-881, a polymorphic body was checked with each type variable bound to a singleton atom,
`:'T'`. That one encoding decided three things nobody chose:

- `T | atom` in a signature was refused as *absorbed*: `:'T'` is an atom.
- `T | int` was accepted: an atom and an integer sit in different guard buckets.
- `T | :nothing` was accepted: the literal is a pattern that reaches its member.

The fix makes a variable a part of the type algebra of its own, so `atom` can no longer swallow it,
and the *absorbed* refusal no longer applies. To leave the language surface unchanged, the fix
keeps the variable in the atom bucket, where `:'T'` put it. So `T | int` still stands, and
`T | atom` is still refused, now by F36's union rule: *"no clause head can tell `atom` from `T`"*.
That bucket is left over from the encoding, and no ticket chose it.

## The question

**Q1. Is this program accepted?**

```csharp
module U

public int | string Show(int n)
Show(n) -> Describe(n)

private T | int Describe<T>(T x)
Describe(x) -> x
```

Accepted today. A caller that picks `T = int` gets back an `int | int`, and no clause head inside
`Describe` could tell which member a value came from. That is the same thing `T | atom` is
refused for.

- **Accepted**: a variable is disjoint from every written type, as F45's opacity already treats it
  for `T | :nothing`. Compiler delta: `guard_buckets/1` gives a variable no bucket, and
  `T | atom` becomes accepted too. One line in `bs_types`, and the two pinned tests in
  `poly_signature_tests` flip.
- **Refused**: a variable could be in any bucket a caller chooses. Compiler delta: `guard_buckets/1`
  gives a variable every bucket, as it does a recursive back-reference. `T | int` is refused with
  the message `T | atom` gets now, and `T | :nothing` still stands, because its literal reaches.
  The suite has no other program that writes a variable beside a bucketed type: all 1502 tests
  passed with that rule in place on 2026-10-25.

**Recommendation: refused.** It is the same reason `T | atom` is refused, applied to every bucket
and not only the one the old encoding happened to use.

## Answer

David, 2026-10-28: *"refuse T | int, keep generics"*. Asked first whether generics were a good
idea at all; the answer kept [27](27-parametric-polymorphism.md)'s decision and placed the
ambiguity in the untagged union, not the variable. The case that settled it, run on `1429fdc1`:

```csharp
module D

public string Wrapped(int n)
Wrapped(n) -> Wrap(n)

private string Wrap<T>(T x)
Wrap(x) -> Show(x)          // x arrives at Show as the T member

private string Show<T>(T | int v)
Show(int n) -> "the int member"
Show(v)     -> "the T member"
```

`Wrapped(5)` prints `"the int member"`: the checker reads the value as `T`, the `int` clause takes
it.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [A type variable beside another type in a union](issues/119-a-type-variable-beside-another-type-in-a-union.md)
  — **a type variable could be any kind a caller picks, so it shares every guard bucket, and a
  signature whose union puts one bare beside a type no pattern reaches is refused**: `T | int`
  and `T | atom` are refused alike, by F36's *"no clause head can tell"* rule. A member a pattern
  reaches still stands beside a variable, so `option<T>` (`T | :nothing`) and `result<T, E>`
  (`T | (:error, E)`) are unchanged. A parametric alias is judged where a signature uses it,
  as every parametric alias is: `type Either<T> = T | int` is not refused on its own. Raised 2026-10-25 by the ENG-881 fix, which had kept the
  atom bucket the old singleton-atom encoding gave a variable; resolved 2026-10-28 by David,
  generics kept ([27](issues/27-parametric-polymorphism.md)). Built — F45, under
  [ENG-881](https://linear.app/davewil/issue/ENG-881).
```
