# Decision brief — ticket 59 (ENG-241): the boundary guard's two scopes

Prepared 2026-10-01 by a scheduled run. **Nothing is resolved.** Probes, B# programs and variant
patches are under `artifacts/probes/59/`. `bsc` from HEAD `0dddf8b`, OTP 27.3.4. Elixir 1.14 and
Gleam 1.18.1 were run for the survey (behaviour only, no installed sources); Elm is not measured.

## Where the code stands

`bs_emit.erl:267 guard_one/7` already receives `Public`. The record **tag test** branch never reads it
(emitted on every function); the **int kind**, range and float tests are gated `none when Public ->`.
So the asymmetry is one clause deep, and either rule is a one-line change.

## Sub-decisions

1. One scope for both guards, stated once.
2. Is "exported" the right discriminator? (BEAM keeps one entry label per function, ticket 18.)
3. Cost if it widens.

## The measurement that decides which way the evidence points

Ticket 18's guarantee is *"a foreign term that breaks your types will crash — not always where it
entered, but never silently."* Both halves of the asymmetry were run against it.

**The private tag test is load-bearing** (`p1_forged_element.sh`, `prog/Shop59`). An exported
`SumAll(list<Order> os)` hands each element to a private `One(Order o)`. The entry guard has no record
parameter to test, so a forged element is checked only by `One`'s own tag test:

```
                                              HEAD                      tag test exported-only
SumAll([Good])                                 7                          7
SumAll([Forged])  an Invoice-tagged map        {error,function_clause}    100       <- accepted as an Order
Direct(Forged)    exported record parameter    {error,function_clause}    {error,function_clause}
```
Narrowing the tag test (the ticket's "defect against 18 §4" reading) turns a crash into a silently
wrong answer. That is outcome 3, which 18 exists to prevent.

**The int kind test's narrower scope is a live hole at HEAD** (`p4_int_kind_through_a_list.sh`,
`prog/Kind59`). The same shape with an `int` that has a comparison:

```
public int Total(list<int> xs)   Total([x, ..rest]) -> Band(x) + Total(rest)
private int Band(int n)          Band(>= 9) -> 2 ; Band(_) -> 1

Total([10])      2
Total([100.5])   2                       <- HEAD: a float is accepted; 100.5 >= 9 is true
BandOut(100.5)   {error,function_clause} <- the exported twin is guarded, so this is the same bug as ticket 58, one call deeper
```
With the kind test applied to private functions too (`variant_kind_test_on_private_too.patch`),
`Total([100.5])` becomes `{error,function_clause}`.

So the two scopes are not symmetric in what they protect: the tag test's accidental width is doing
real work, and the kind test's narrowness leaves a hole. Neither "narrow both" nor the status quo
satisfies 18's sentence.

## Cost

- **Tag test on a private function** (`p2`): `Shop59.beam` 1516 vs 1480 bytes (**+36 B**, +2.4%);
  `One/1` 8 vs 6 instructions. Ticket 26a recorded +14 B flat on OTP 28/arm64; consistent.
- **Kind test on a private function** (`p4`, `p5`): `Kind59.beam` +40 B (1260→1300, relative source path) and +36 B (1340→1376, absolute path; the embedded path changes absolute sizes, not the delta).
  Ticket 18 recorded +3–5 B per `is_integer`; this program also carries the range comparison.
- **Call time** (idle box, 7 samples × alternating builds, `p2`, `p5`): the private tag test costs about **+2.3 ns per element** in a 100k-element private record loop (median 18.6 → 16.4 ns without it, i.e. roughly 13% of that loop, which also does a non-tail recursive call); the private kind test about **+1.0 ns** (median 13.4 → 14.4 ns, roughly 7%). These are micro-loop upper bounds, not application costs; tickets 18/26a reported call time below their resolution on a different loop shape and platform, so the comparison is not like for like.

## Neighbour survey (`p3_neighbours_private_guard.sh`)

- **Elixir 1.14**: a `defp` with a struct pattern refuses a forged map nested in a list
  (`FunctionClauseError`); the same `defp` that only projects a field accepts it and returns `100`.
  Elixir's tag test is the *pattern*, written by the author, on private functions as readily as public.
- **Gleam 1.18.1**: `pub fn` and private alike run no guard; a forged `{invoice,1,100}` or
  `{order,1,2,3}` reaches a `case` and dies with `case_clause` only because the pattern happens to
  fail. No scope decision exists to compare.
- **Erlang**: no declared types, nothing to guard.

## Options

**A. Status quo, stated as a rule: tag everywhere, kind exported-only.** Compiler delta: none (a
sentence in 18 §4 and LANGUAGE.md). *Strongest counterargument:* the kind half is a measured hole
(`Total([100.5])`), so the sentence would document a known violation of 18's guarantee.

**B. Both guards on every function (widen).** Compiler delta: remove `when Public` and the dead
variable (`variant_kind_test_on_private_too.patch`: +2 −4). Closes the hole, keeps the tag test.
*Strongest counterargument:* it guards values the checker already proved at every B#-to-B# call site,
and `18 §4`'s own cost census (83.3% of exported positions are bare variables) was the argument for
guarding *less*; the per-call cost lands on private recursive loops (see call time).

**C. Narrow the tag test to exported-only (the ticket's "defect" reading).** Compiler delta: one clause
(`variant_tag_test_exported_only.patch`). *Strongest counterargument:* measured above — it removes the
only check on the nested path, and a forged tag is silently accepted. Unless a deep entry check
exists (18 §4 rejected whole-aggregate analysis by name), this option violates 18.

## Recommendation

**B.** It is the only option the two measurements both support, it is a deletion rather than an
addition, and the +36–40 bytes are the same order as the figures 18 and 26a already accepted. If the
call-time cost on a private hot loop is judged too high, the fallback is A with the hole *named* in 18
and a ticket for a deep entry check, **not** C.

## Caveats

- OTP 27, Linux/x86_64; tickets 18 and 26a measured OTP 28/arm64. Byte figures from one small program each.
- Full `rebar3 eunit` for the variants: see the appended note.
- Does not cover a private function reached as a fun value (F46's escape channel). Earlier briefs on this
  ticket measured that separately; I did not repeat it.
- The nested-field path (ticket 46 §4: a field of an exported record parameter) is not guarded under
  any option here.

## Verification

See "Verifier result" appended below by the independent verifier run.
