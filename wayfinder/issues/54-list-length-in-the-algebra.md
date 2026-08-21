# 54 — List length in the algebra: a proved-exhaustive program that crashes

Type: grilling
Status: open — [ENG-236](https://linear.app/davewil/issue/ENG-236)

Raised 2026-08-21 from [prototype 53a](../prototypes/53a-closed-list-patterns.md), which set out
to test [ticket 53](53-a-route-table-needs-a-closed-list-pattern.md)'s premise and found this
instead.

## The repro, in two clauses

```csharp
module Gap

public atom Shape(list<int> xs)

Shape([])          -> :empty
Shape([a, b, ..t]) -> :many
```

```
$ bsc --src-root . Gap                 # compiles clean, no diagnostic
$ bsc --src-root . Gap Shape '[7]'
crashed: error:function_clause
```

**The compiler proved this exhaustive and it crashes on a value of the declared type.** No
catch-all was refused, no warning was printed, and `list<int>` is as ordinary as a type gets.

## Why

`bs_types` represents a list as `{nil_flag, elem}` — empty-or-not, plus an element type. There
is **nowhere to put a length**. Measured, over `list<int>`:

| pattern | checker subtracts | actually matches |
|---|---|---|
| `[]` | the empty list | the empty list — agrees |
| `[a, ..t]` | all non-empty | all non-empty — agrees |
| `[a, b, ..t]` | all non-empty | length >= 2 — **over-subtracts, and this is the crash** |
| `[a, ..[]]` | nothing | length exactly 1 — **under-subtracts** |

The two forms TOUR §5 demonstrates are exactly the two the representation can express. Both
others are silently approximated, in whichever direction falls out — and one of those directions
is unsound.

The under-subtracting half is visible too: `[]` alone, `[]` plus `[a, ..[]]`, and `[]` plus
`[a, ..[]]` plus `[a, b, ..[]]` all leave the identical residual `[int, ..]`. Adding
closed-length clauses moves nothing.

## Question

**How much of list length does the algebra model?**

This is a decision and not only a repair, because "carry the length" has a range and the range
has a cost. Ticket 20 already put **integer intervals** in the algebra and ticket 30 found that a
binary segment's width refines what it binds; length is the same kind of quantity, and the
machinery for reasoning about it may already be there.

## Candidates

1. **Exact prefix length.** A cons pattern subtracts `length >= n` where `n` is its prefix, and a
   closed rest subtracts `length == n`. Smallest change that makes the repro red. Says nothing
   about lists whose length is bounded by a type.
2. **Length as an interval, reusing ticket 20's machinery.** `list<T>` carries a length interval
   the way `Octet` carries `0..255`; `[a, b, ..t]` is `length >= 2`, `[a, ..[]]` is
   `length == 1`, and the residual printer already knows how to talk about intervals — which is
   why the diagnostic for the repro could name the missing case rather than only refusing.
   Strictly more than candidate 1 and possibly not more expensive, since the interval code exists.
3. **Refuse what cannot be checked.** Reject `[a, ..[]]` and `[a, b, ..t]` at the grammar, leaving
   exactly the two forms the algebra can express. Honest, cheap, and it deletes the spelling
   ticket 53 needs — so it costs the route table.
4. **Do nothing and warn.** Refuse to credit any multi-element prefix, forcing a catch-all. Kills
   the unsoundness without modelling anything, and makes every list function catch-all-terminated,
   which is the tax [ticket 12](12-totality-vs-let-it-crash.md) §2 exists to avoid.

## What must not happen

**Do not fix the over-subtraction alone.** Making `[a, b, ..t]` subtract `length >= 2` removes the
crash and leaves `[a, ..[]]` invisible, so a route table written the way 53 resolves is *still*
unchecked and now looks fine. The two symptoms have one root and a fix that treats one is a fix
that hides the other.

**Do not start with the implementation.** [`CLAUDE.md`](../../CLAUDE.md): the failing test and the
gate come first. `Gap` above is the failing test and it is four lines long.

## Notes

Blocks nothing formally, and **should be taken before ticket 53's sugar question**, which is now
downstream of it: sugar over a form the checker cannot see would make the surface read more like
C# while the guarantee behind it stayed absent.

449 tests pass today *with* the wrong behaviour. Some may encode it, and finding out which is part
of the work rather than a surprise to meet halfway through.
