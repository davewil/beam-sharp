# PROTOTYPE 53a — the closed list pattern already exists, and measuring it found a hole

> **Throwaway.** Ticket [53](../issues/53-a-route-table-needs-a-closed-list-pattern.md).
> Every result below was executed against `bsc` at `8fb96ee` on 2026-08-21. Nothing here is
> reasoned; each block is a file that was compiled and, where it matters, run.

Ticket 53 was raised on the claim that **there is no spelling for "a path of exactly two
segments"**. That claim is false, and the correction is the ticket's answer.

---

## 1. The premise, tested

`[a, b]` is refused, exactly as ticket 08 says:

```csharp
Two([a, b]) -> :two
```

```
error: a list pattern needs a rest
  write `[h, ..t]`. Prefix-plus-rest is the only list pattern.
```

**But the rest is a *pattern*, and `[]` is a pattern.** So prefix-plus-rest can close itself:

```csharp
One([a, ..[]]) -> :one
One(_)         -> :other
```

```
$ bsc … One '[7]'      -> :one
$ bsc … One '[7, 8]'   -> :other
```

Compiles, runs, and means **exactly one**. Nothing was built for this and no rule was bent —
it is ticket 08's own grammar used twice.

## 2. 25a's route table, written in the language as it stands

```csharp
public atom Dispatch(Method m, list<string> path)

Dispatch(:get,    ["orders", ..[]])     -> :index
Dispatch(:get,    ["orders", id, ..[]]) -> :show
Dispatch(:post,   ["orders", ..[]])     -> :create
Dispatch(:delete, ["orders", id, ..[]]) -> :destroy
Dispatch(_,       _)                    -> :not_found
```

```
$ bsc … Dispatch ':get' '["orders"]'                 -> :index
$ bsc … Dispatch ':get' '["orders", "42"]'           -> :show
$ bsc … Dispatch ':get' '["orders", "42", "lines"]'  -> :not_found
```

**The exemplar was written wrong, not refused.** `/orders/42/lines` falls through to the
catch-all rather than being swallowed by `:show`, which is the whole property a route table
needs and the thing ticket 53 said could not be expressed.

The catch-all is still required and is legal: a `list<string>` residual is open because a
string's is (TOUR §10), so this is not a case where `_` hides anything the compiler could name.

---

## 3. And then the checker disagreed with the runtime

Measuring §1 properly meant asking whether the closed rest is *credited to exhaustiveness* or
merely matched. **The algebra has no length dimension at all**, and the two ways that goes
wrong point in opposite directions.

The first draft of this section said the closed form was credited correctly and only the open
prefix was wrong. That was a misreading of one residual, corrected here by running the probe
that separates the two explanations rather than by picking the one that fit.

**The baseline.** `[]` alone over `list<int>`:

```
error: Shape is not exhaustive
  no clause matches:
    Shape([int, ..]) -> ...
```

Now add clauses and watch the residual **not move**:

| clauses | residual |
|---|---|
| `[]` | `[int, ..]` |
| `[]`, `[a, ..[]]` | `[int, ..]` |
| `[]`, `[a, ..[]]`, `[a, b, ..[]]` | `[int, ..]` |

Identical, three times. **A closed-length clause subtracts nothing.** `[a, ..[]]` is matched at
run time — §1 proves that — and is invisible to the checker.

**And the open prefix subtracts too much.** On its own, over `list<int>`:

```csharp
Shape([a, b, ..t]) -> :many
```

```
error: Shape is not exhaustive
  no clause matches:
    Shape([]) -> ...
```

`[]` is the *entire* residual: a two-element prefix is credited with every non-empty list. It
does not match `[7]`.

**One root, two symptoms.** `bs_types` represents a list as `{nil_flag, elem}` — empty-or-not
plus an element type, with nowhere to put a length. So a cons pattern with a *variable* rest
subtracts all of non-empty regardless of how long its prefix is, and a cons pattern with a
*closed* rest cannot be expressed as a subtraction at all and is dropped. The first is
**unsound** — it proves too much. The second is merely **incomplete** — it proves too little,
and forces a catch-all that is then the only thing standing between the program and a crash.

### The two-clause repro

```csharp
public atom Shape(list<int> xs)

Shape([])          -> :empty
Shape([a, b, ..t]) -> :many
```

```
$ bsc …                  -> compiles clean, no diagnostic
$ bsc … Shape '[7]'      -> crashed: error:function_clause
```

**A program the compiler proved exhaustive crashes on an input of the declared type.** That is
the guarantee the language exists for, absent over list length, with no warning anywhere.

### What the checker believes, against what is true

| pattern | checker subtracts | actually matches |
|---|---|---|
| `[]` | the empty list | the empty list — agrees |
| `[a, ..t]` | all non-empty | all non-empty — agrees |
| `[a, b, ..t]` | all non-empty | length >= 2 — **over-subtracts** |
| `[a, ..[]]` | nothing | length exactly 1 — **under-subtracts** |

Only the two forms TOUR §5 shows are right, and they are right because they are the only two the
representation can express. Everything else is silently approximated, in whichever direction the
representation falls.

**This is a defect, not a decision, and it is much larger than the ticket that found it.** The
repro lives in the ticket raised for it rather than only here — a prototype is throwaway and an
unsound exhaustiveness check must not be recoverable only from one.

---

## What 53 should take from this

1. **No language change.** The spelling exists and is built.
2. **`route.bs` is wrong** and should be rewritten as §2. So should ticket 53's own framing.
3. **The read cost is real and is the only live design question.** `["orders", id, ..[]]` says
   "exactly two" in five characters of punctuation that a C# or TypeScript reader will not
   recognise on sight — both spell it `["orders", id]`. That is a question about whether the
   closed form deserves sugar, which is much smaller than the one asked.
4. **And the sugar question is now second in line behind a correctness one.** A closed-length
   clause is invisible to the checker, so a route table written in §2's style is exhaustive only
   by virtue of its catch-all — the compiler is not proving anything about the routes themselves.
   Sugar over a form the checker cannot see would make the surface *look* more like C# while the
   guarantee behind it stayed absent. Fix the algebra first; decide the spelling after, when
   there is something real underneath it to spell.
