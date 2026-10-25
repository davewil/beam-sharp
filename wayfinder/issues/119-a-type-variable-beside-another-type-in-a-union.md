# 119 — Can a clause head tell a type variable from an `int`?

Type: grilling
Status: open — [ENG-926](https://linear.app/davewil/issue/ENG-926). Raised 2026-10-25 by the
fix for [ENG-881](https://linear.app/davewil/issue/ENG-881)
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
