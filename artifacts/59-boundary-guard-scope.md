# Decision brief: ticket 59, the boundary guard applies two rules with different scopes

Linear: ENG-241. Repo ticket: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`.
Status after this brief: **still open**.

Probes: `artifacts/probes/p59_forged_reach.sh`, `src59/*.bs`, `corpus.escript`, `bench59.escript`.
Prototype patches: `patches/59n-tag-test-exported-only.patch`, `patches/59w-kind-test-everywhere.patch` (each a 3-line change in `bs_emit:guard_one/8`).

## The one question

Is a private function's parameter a boundary for values that came out of a forged argument to an exported function? Every other choice in the ticket follows from the answer.

## What I measured

**Today.** `bs_emit.erl:274-292`, `guard_one/8`: the record tag test is emitted whatever `Public` says, and the int and float kind tests are gated on `Public`. The emitted code for a private `Greet(Customer c)` is `'Greet'(C) when map_get('Kind', C) =:= 'Rc.Customer'`.

**The ticket's argument for removing the private tag test is that every call site is a checked B# call.** That holds for the argument itself. It does not hold for values *derived* from an argument. An exported guard checks the top-level record's `Kind` and nothing inside it (18 §2 allows only O(1) checks), so a nested record or a list element reaches a private callee unchecked. I forged three such values and passed them through an exported function (`p59_forged_reach.sh`, three compiler builds):

| forgery, passed to the exported function | today | tag test removed from private (N) | kind test added to private (W) |
|---|---|---|---|
| `Order.Who` is a map with `Kind = 'Rc.Other'`, private `Greet(Customer c)` | `function_clause` | **returns the name, silently** | `function_clause` |
| `Bucket.Count` is `100.5`, private `Classify(Octet n)` with `>= 9` | **returns `high`** | returns `high` | `function_clause` |
| list `[1, 100.5]`, private `Classify(int n)` with `>= 9` | **`[low, high]`** | `[low, high]` | `function_clause` |

Rows 2 and 3 are holes that exist today. Row 1 is a hole that N would open. The verifier's extra probes (`verification/59-extra.sh`): a forged Customer through two private hops is still caught by the tag test today and answered silently under N; a forged tuple element `(:pair, 100.5)` reaching a private `>= 9` through two hops is answered today and refused under W. One hole all three builds share: a private parameter typed as a union of records (`Person | Company`) gets no tag test, because the test is only emitted for a single closed record, so a forged `Kind` passes. W does not close that. The program for row 1:

```csharp
record Customer { Name: string }
record Order { Id: int, Who: Customer }
public string Run(Order o)
Run(o) -> Greet(o.Who)
string Greet(Customer c)
Greet(c) -> c.Name
```

**Cost, measured over the 22 modules in `compiler/examples` (`corpus.escript`):**

| build | .beam bytes | guarded clauses |
|---|---|---|
| today | 56020 | 82 |
| N, tag test exported only | 56020 | 82 |
| W, kind test also on private | 56368 | 89 |

N saves nothing on these 22 modules: none has a private function with a record parameter. The verifier found it does change the exemplars: `exemplars/25e` goes 6336 to 6268 bytes (guarded clauses 4 to 3) and `25f` 23784 to 23748 (11 to 10), the only two exemplars that compile standalone. So N's saving is real but small: 68 and 36 bytes. W adds 348 bytes (0.62%) and 7 guards.
Run time, `bench59.escript`, 2M iterations, min of 41 runs, alternating builds: today 11.46 to 11.51 ms, W 12.24 to 12.25 ms. The verifier's four alternating pairs gave 11.10 to 11.67 against 12.13 to 12.46 ms. That is 0.35 to 0.5 ns per iteration. Each iteration runs about 2.4 `is_integer` tests (one on `Count`'s accumulator, one or two in `Weigh`), so the cost per test is lower than the per-iteration figure. That is the worst case, because the private body is one comparison. Machine: x86-64 JIT, OTP 28, a busy 4-core sandbox (the background test suites were running, so read the ratio, not the absolutes).

## The three programs

**S. Leave both as they are.** Row 1 stays safe, rows 2 and 3 stay open. Cost: zero. The asymmetry is then a rule with a reason nobody wrote down, and the reason (nested values) applies equally to ints and floats.
Strongest counterargument: it is the only choice that makes no change to the compiler, and 18 §4 states the analysis is function-local on purpose. Rows 2 and 3 are `list<int>` and field cases the census in 18 did not count.

**N. Narrow: tag test on exported functions only.** Matches 18 §4 as written. Row 1 turns from a crash into a silent wrong answer.
Strongest counterargument: it removes a test whose removal saves 0 bytes here and was priced by 26a at 14 bytes, flat in field count. The saving is smaller than the hole.

**W. Widen: kind test on every function.** Closes rows 2 and 3, leaves row 1 as is. Patch `59w` is three changed lines.
Strongest counterargument: it contradicts the sentence in `bs_emit.erl` and in 18 §1 that private functions pay nothing, it costs about 0.4 ns per call in a loop that is nothing but private calls, and it adds more than a kind test. The verifier found W also emits the range test on private refined ints (`is_integer(N) andalso N =< 255 andalso N >= 9`) and an `is_float` guard on private float parameters. A forged `Count = 300` into a private `Octet` is refused under W and answered under today's compiler. Nothing changes for atoms, strings, lists, tuples or records.

## Recommendation

W. It makes the two rules agree and closes rows 2 and 3 plus the tuple case. It does not close the union-parameter hole, which is a separate gap in the tag test. The ticket's cost argument is correct but small: +0.62% bytes and sub-nanosecond calls. If the cost of 0.4 ns per private call is unacceptable for a hot loop, the choice is N plus an explicit statement that private functions are not defended against forged nested values, and row 1 then goes in the spec as a known limit.

## Limits

- Three forgery shapes in the table plus three the verifier added; none exhaustive. Maps nested deeper, tuples, and `option<T>` payloads were not tried.
- The benchmark loop is a worst case by construction. I did not measure a realistic private-call mix.
- Row 2 and 3 are holes under today's rule 18 §2 describes ("a foreign term that breaks your types will crash, never silently"). They contradict that sentence. I did not check whether 18 §2 meant element types to be out of scope.

## Existing test suite

`compiler/test` (73 modules), baseline 1442 pass and 6 fail (a locale-dependent group in my shell, unrelated).
- N: 1442 pass, the same failures. No existing test pins the private tag test, so N would pass the suite without anyone noticing. That is itself a finding.
- W: 1440 pass, 8 fail: the 6 above plus `boundary_kind_tests:a_private_function_is_not_guarded_test` and `boundary_range_tests:a_private_function_carries_no_range_guard_test`. Both assert the rule under review (F24.6, "only exported functions receive kind guards"), so W has to change those two tests as part of the decision. No other test moves.
