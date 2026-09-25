# 94 — A fallible map over a list: three hand-written functions per use

Type: grilling
Status: open — [ENG-435](https://linear.app/davewil/issue/ENG-435). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

25d maps a function that can fail over the rows a query returns. F46 built `List.Map`, `Filter`
and `Fold`, and listed a short-circuiting traverse as *"breadth under ticket 67, not asked"*.
Measured on `a0f9cbf`: `List.TryMap(xs, f)` → `error: All calls List.TryMap/2, and \`List\` has
no operation of that name`. So 25d writes it by hand:

```csharp
private result<list<OrderRow>, FetchError> Rowed(list<WireRow> rows)

Rowed([])          -> []
Rowed([w, ..rest]) -> Build(w) switch {
    (:error, e) => (:error, e),
    row         => Prepend(row, Rowed(rest))
}
```

with `Prepend` a third function to put the row in front of a result. 25f's `Answers` is the same
shape.

## Round 1

**Q1. Does `List` gain an operation that maps a fallible function and stops at the first failure?**

```csharp
Rows(rows) -> List.TryMap(rows, w => Build(w))
```

Under yes: `List.TryMap<T, U, E>(list<T>, fn(T) -> result<U, E>) -> result<list<U>, E>`, the
failure being the first element's, in list order. Under no, the recursion above is the idiom.
The name is part of the answer.

Compiler delta: one entry in F32's reserved signature table, typed as F45 types a polymorphic
call; one generated walker in `reserved_form/1` beside `Map` and `Fold`, tail-recursive with a
reversed accumulator; the failure test is ticket 49's fixed pair.
