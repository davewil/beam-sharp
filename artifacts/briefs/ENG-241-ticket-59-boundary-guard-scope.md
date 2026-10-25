# Ticket 59 (ENG-241): the boundary guard applies two rules with different scopes

**State: open. Nothing here resolves it.** Written 2026-10-25 from `artifacts/probes/59/`; the verifier's report is `artifacts/verification/ENG-241.md`.

## The question, asked alone

For a **private** function, should the compiler emit the boundary guards at all? There are two guards today: the record `Kind` tag test, which private functions get (`bs_emit.erl:275`, no `Public` test), and the integer kind and range test, which they do not (`bs_emit.erl:284`, `none when Public`). The ticket asks which scope is right "stated once, for both".

## What the probes established

The ticket frames the choice as defect versus deliberate. The probes show a third thing: **the discriminator "exported" protects only top-level parameters, and both guards are blind below the top level**, so what a private function receives from an exported one is unguarded in a way the tag test happens to patch and the kind test does not.

One program, forged from outside (Erlang calling the exported entry; `p59_scope.sh`). `G.Order` carries a `G.Customer`; `RunOrder` is exported, `Inner` is private:

```csharp
record Customer { Credit: int }
record Order    { Id: int, Buyer: Customer }
type Byte = int where value >= 0 and value <= 255

private int Inner(Customer c)
Inner(c) -> c.Credit
public int RunOrder(Order o)
RunOrder(o) -> Inner(o.Buyer)

private atom Classify(Byte b)
Classify(b) when b >= 100 -> :big
Classify(b)               -> :small
public atom RunBytes(list<Byte> bs)
RunBytes([b, .._]) -> Classify(b)
```

| call from outside | unpatched | G1: no tag test on private | G2: kind test on private too |
|---|---|---|---|
| valid `Order` (control) | 7 | 7 | 7 |
| forged top-level tag | `function_clause` in `RunOrder` | same | same |
| **forged nested `Buyer` tag** | `function_clause` in `Inner` | **returns 7** | `function_clause` in `Inner` |
| forged nested `Buyer`, field missing | `function_clause` in `Inner` | `badkey Credit` from `erlang:map_get` | `function_clause` in `Inner` |
| `RunBytes([7])` (control) | `small` | `small` | `small` |
| **`RunBytes([100.5])`** | **`big`** | `big` | `function_clause` in `Classify` |
| `ClassifyPublic(100.5)`, same function exported | `function_clause` | same | same |

**Threat model, as the verifier bounded it.** Every forged value above is built by Erlang calling an exported function, which is the case boundary guards exist for. The verifier tried to reach a private function with a bad value from B# alone (`term` arguments, `x + 300`, `:erlang.float(x)`, record construction and `with`, foreign returns typed `Byte` or `(int, Byte)`) and found **no route that compiled and ran**: each was refused at compile time or stopped at the foreign-return guard (F42) before the private call. Mailbox, `gen_server` state and `code_change` routes were not tried. So the holes below are real for external callers of an exported function whose parameter is a container of refined values or a record holding a record, and nothing shows more than that.

Reading it:
- The private tag test is not dead weight: it is the only thing that catches a wrong-kind record arriving as a *field* of a record the exported entry did accept. Removing it (G1) turns that into a silently accepted wrong record. This is the ticket's "it is not a defect" argument, with its mechanism found.
- The private kind test's absence is a live hole of the same shape: a float inside `list<Byte>` reaches `Classify`, a function whose parameter is published `0..255`, and answers `:big`. This is the defect ticket 58 closed for *exported* functions, still open one call down.
- F24's own pinned test says `Private calls are checked at their call sites` (`boundary_kind_tests.erl:87`). True of the top-level argument, false of a value read out of a container.

## Options

### 1. Narrow: tag test on exported functions only (G1)

One clause, `{ok, _} when not Public -> {Pat, []}` before `bs_emit.erl:277`. Patch `v59-G1`.

Measured: the nested-forgery rows above. `compiler/test` fails **nothing new** (1494 / 4): no test pins the private tag test. Beam bytes over the 22 compiling example modules: unchanged (54364), the examples contain no private record parameter.

**Strongest counterargument.** It is a silent hole opened to satisfy a sentence in 18 §4, and it is the direction the ticket itself calls costlier ("too narrow is a silent hole").

### 2. Widen: the kind and range guards on private functions too (G2)

Drop `when Public` at `bs_emit.erl:284` and the now-unreachable `none -> {Pat, []}` clause. Patch `v59-G2`. Rule stated once: every function guards every closed-record, `int` and `float` parameter.

Measured: `RunBytes([100.5])` is now refused. Cost: **+348 bytes over the 22 compiling example modules (+0.64%)**. Run-time cost on the one hot loop in the repo, where all six functions are private and take `int` (`aoc/bench/Day01`, `p59_cost.sh`): 12.95 ms median against 12.79 ms, a 1.2% *gain*, i.e. noise; no cost is measurable. ticket 18 had put `is_integer` at +3 to 5 bytes and below its ±0.09 ns/call resolution; that holds.

`compiler/test`: **two new failures, and they are the two tests that pin the current decision**: `boundary_kind_tests:a_private_function_is_not_guarded_test` and `boundary_range_tests:a_private_function_carries_no_range_guard_test`. They would be rewritten, not fixed.

**Strongest counterargument.** It reverses an explicit, tested decision (F24.6, F37) on the strength of one probe, and it still does not close the hole at its source: the exported entry does not validate `list<Byte>` elements, so the cheaper place to guard would be the container, not every private callee. That alternative was not built.

### 3. Keep both as they are and write the rule down

Record: tag unconditional, kind exported-only, reason stated once.

Measured: nothing changes. Both probes' unpatched columns stand.

**Strongest counterargument.** The stated reason would have to be "a wrong tag is caught and a wrong kind is not", which the `RunBytes([100.5])` row contradicts for kind.

## Recommendation

**Option 2, with that scope understood: it closes a hole only external callers can reach, for under 1% of size. Provided the two pinned tests are rewritten in the same change and the rule is written once in 18 §4**: "every function guards every parameter whose declared type is a closed record, `int` or `float`; a private function is not exempt, because a private callee is reached with values read out of containers that no exported guard looked into." The measured cost is under 1% of size and zero in time; option 1 has a measured silent wrong answer; option 3 contradicts its own justification.

Not measured: G2 on private record or `float` parameters (only the six `int` functions of Day01 were timed, 0.7 to 1.0% faster in two verifier runs, which could be noise); G1's byte effect on a program that has private closed-record parameters (none of the 22 measured modules has one; the exemplars that do compile in no build).

Open and not probed: guarding the container at the exported boundary (`list<Byte>` elements) instead. It would make private guards unnecessary for this route and cost O(n) per call, so it is not obviously cheaper; nobody measured it.

The +14 bytes per tag test is ticket 26a's figure, not re-measured. G2 also leaves stale comments saying the kind guard is "exported only" (near `bs_emit.erl:177-181` and the section header at about line 330).

## Where the ticket's text and the code disagree

- The ticket cites `boundary_guards/5`; it is `boundary_guards/6` at `bs_emit.erl:265` in the current tree, and the scope test is in `guard_one/7` (`bs_emit.erl:275`).
- As the ticket quotes it, 18's cost section says a non-exported function "has the test elided entirely". For the integer kind that is true (`a_private_function_is_not_guarded_test` pins it); for the record tag it is not, which is the asymmetry this ticket is about.
