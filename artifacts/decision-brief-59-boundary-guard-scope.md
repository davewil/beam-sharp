# Decision brief — ticket 59 (ENG-241): the boundary guard applies two rules with different scopes

Status of the ticket: **left open.** Evidence: `artifacts/probes/results/59-*.txt`, patches `v59a`, `v59b`, `v59c`. Limits: `artifacts/README.md`.

## The one question David decides

Is a private function guarded because it is private-and-reachable-only-from-checked-code, or because anything that can *hold a reference to it* can call it with anything?
Today this module compiles, and the answer to "what does a wrong value do" depends on which guard you are asking about:

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }

private int Show(Order o)
Show(o) -> o.Total

public fn(Order) -> int Handler()
Handler() -> Show                 // the private function escapes as a value

private int Class(int n)
Class(n) when n >= 9 -> 1
Class(n) -> 0
public fn(int) -> int Classifier()
Classifier() -> Class
```

## Sub-decisions

1. Does the record **tag** test belong on private functions (today: yes, unconditionally)?
2. Does the int/float **kind** test belong on private functions (today: no)?
3. What single sentence states the scope for both?

## What was measured

- **The comment is deliberate, not an oversight.** `bs_emit.erl` says of the kind guard "Exported functions only ... The record tag guard above is emitted on private functions too; that asymmetry is deliberate."
  F24 §3 says the same. The ticket is asking whether the stated reason holds.
- **Can a wrong-Kind value reach a private function through a *call*? No.** Four attempts to hand a private `Inner(Order o)` a non-`Order`
  from an exported function (a `term`, a structural map with the same fields, an unnarrowed `Order | Invoice`, `59-can-a-wrong-kind-reach-a-private-fn.txt`) are all refused at the call site; narrowing by clause head compiles.
  A foreign function cannot be declared to return a record at all ("Erlang cannot produce its `Kind`"). So for ordinary calls the private tag test never fires on an accepted program.
- **But a private function can leave the module as a value, and then both guards matter** (`59-escaped-private-function.txt`, calling the escaped funs from plain Erlang):

  | variant | `Handler()(Invoice map, same fields)` | `Classifier()(8.5)` / `(9.5)` |
  |---|---|---|
  | baseline (tag on private, kind not) | `function_clause` | **`0` / `1` (silent wrong answers)** |
  | v59a (tag exported-only) | **`7` (an Invoice accepted as an Order)** | `0` / `1` |
  | v59b (kind widened to every private) | `function_clause` | `function_clause` |
  | v59c (guard exported **or escaping**) | `function_clause` | `function_clause` |

  So today's kind asymmetry already has a hole, and narrowing the tag test (the direction the ticket's "defect" reading points) opens a second one: two records with identical fields are distinguished only by the tag.
- **Cost, measured on x86-64 / OTP 25** (`59-emitted-code-and-bytes.txt`, `59-private-call-cost.txt`):
  tag test on a private record function: **+24 bytes** per function in the probe module (1548 vs 1524); 20M calls to a private record function: median **590 ms with it vs 470 ms without**, about 6 ns per call (null control, same beam both sides: 582 vs 599 ms, 3% noise).
  This is larger than the ticket's "+14 bytes, below resolution" framing suggests, for a tight non-inlined loop; how much a real program sees was not measured.
  Kind test widened onto every private function (v59b): **+76 bytes** (1624 vs 1548) in the probe module, and two existing tests that pin the rule fail (`boundary_kind_tests:a_private_function_is_not_guarded_test`, `boundary_range_tests:a_private_function_carries_no_range_guard_test`).
- **The tag test is only a tag test.** A forged `#{'Kind' => 'P.Order'}` with no `Total` passes the exported entry and the private function alike and dies with `badkey` either way (same file). The private tag test adds nothing against a half-forged record.

## Neighbours

Executed: an Elixir `defp g(x), do: x` called through a public `f/1` accepts `:anything_at_all` (one-line probe, output `Elixir defp, no guard emitted: :anything_at_all`). Elixir therefore gives no scope to compare against; I did not probe Erlang.
Gleam and Elm are **not installed**; I made no claim about them. The repo's earlier Gleam FFI-trust prototype is `wayfinder/prototypes/18c_gleam_ffi_trust.gleam`, cited as prior work, not re-run.

## Options

### A. Narrow the tag test to exported functions (`v59a`)
One `when not Public` clause. −24 bytes and −6 ns per private record call; no test regresses (failing set identical).
**Strongest counterargument:** the escape row above. A private function stored as a fun and called from Erlang accepts a wrong record silently. This is the ticket's own "forged record reaches a private function" argument, made concrete by a path the ticket did not consider (function values, F46).

### B. Widen the kind test to every private function (`v59b`)
Closes both holes, uniform rule "everything is guarded". +76 bytes in the probe module and a guard per private integer parameter; breaks the two pinned tests (their premise would be reversed by decision, which is fine).
**Strongest counterargument:** it pays on every call of every private integer function to defend against a path that, for ordinary calls, the checker already closed. Tight integer loops are where that per-call cost would show (not measured on ticket 39's code).

### C. Guard what is reachable: exported **or used as a value** (`v59c`, 6 added lines in `bs_emit:function/2`, on top of v59a)
```erlang
Escapes = [NA || NA = {_, _} <- maps:values(maps:get(fnames, Ctx0, #{}))],
Public  = is_public(F) orelse lists:member({element(2, F), Arity}, Escapes),
```
combined with A. Closes both holes (last row), leaves non-escaping private functions unguarded (same size as A; verifier measured v59c = v59a), eunit failing set identical.
**Strongest counterargument:** the rule needs `fnames` to be complete for every way a name becomes a value; a missed path silently re-opens the hole. Verifier probes (`verification/59.md`) tried a name in a returned tuple, a record field, a list, a lambda body, an escaping overload and `:lists.map`: v59a accepts the wrong record in all of them, v59c in none, and v59c leaves non-escaping private functions unguarded. Another module cannot name a private function (call refused, qualified value does not parse). Still untested: multi-file modules, hot reload, `apply` by atom, behaviour callback tables. Caveat: the baseline already fails 5 `function_value_tests` on OTP 25, so "failing set identical" proves little for v59c's area.

## Recommendation

**C.** One stated rule for both guards: a function is guarded when an unchecked caller can reach it, which is exported **or** escaping as a value. It is the only option that closes both holes without taxing non-escaping private code. If David wants the simplest rule over the cheapest code, B; A should not be chosen, because the escape probe shows it accepts a wrong record.
Before resolving: audit other ways a name becomes a value, and run the full gates on OTP 28.
