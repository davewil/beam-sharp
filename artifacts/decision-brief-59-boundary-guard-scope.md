# Decision brief: ticket 59, boundary guard scope

**Ticket** 59 · **Linear** ENG-241 · **Date** 2026-10-29 · **DECISION OPEN — for human review**

Labels: MEASURED-HERE = I ran it (OTP 25.x JIT x86_64, 4-vCPU noisy VM, Gleam 1.12.0, Elixir 1.14.0).
RECORDED-NOT-RERUN = read from the repo, not re-run (bsc cannot be built here).

## 1. What is being asked, gating question first

**Gating question (ask alone):** does a private function need the record tag test, i.e. *can a
value whose runtime shape nobody checked reach a private function?* The ticket frames the answer
as "exported or not". The probes say exported-ness is a proxy that is exact at parameter depth 0
and wrong at depth 1 and for funs (section 3, P3). The int-kind test is the second question and
follows from the first, because the two tests answer the same "did anyone check?" question
(F24 §2 says so itself).

Follow-ons, not asked yet: (b) whether the int test should widen to private functions;
(c) whether `boundary_guards/5` should carry one scope rule instead of two.

Where the asymmetry lives (RECORDED, `compiler/src/bs_emit.erl`):
`guard_one/8` lines 280-300. The record branch (line 283) never reads `Public`. The `none when Public`
branch (line 291) feeds `float_guard` and `int_guard`. `tag_test/3` is line 590 and emits
`map_get('Kind', X) == Tag` as a head guard.

Premises I checked against the ticket text:

- "+14 bytes, flat in field count" for the tag test: **flat confirmed, magnitude +12 here** (P1).
- "+3-5 bytes for is_integer": **+5 here**, the top edge (P1).
- "the same code un-exported has the test elided entirely" (18, cost section): **true only if
  read as "the emitter does not emit it".** If it means erlc removes a guard that is in the
  source, P2c contradicts it (below).
- "a private function's every call site is a checked beam-sharp call site, so the test is dead
  weight" (ticket, F24 §2): **statically true, but a static check does not shape the runtime
  value.** P3 shows three ways a forged value arrives at a private function with every call
  site type-correct. F24 §6 is a real instance: the private `Tag(int x)` was reached by
  `:foo` and returned it, because the *checker's* narrowing was unsound. That was fixed by
  adding tests at the narrowing site, not by guarding the private function.

## 2. Evidence table

| Probe | Claim | Result | Label | Path (scratchpad `.../probes/59/`) |
|---|---|---|---|---|
| P1 | Tag test bytes, flat in N | Code chunk 80 -> 92 (+12) for N=1,5,20 identically. Pattern form `#{'Kind':='M.Order'}` is +18. Whole .beam +44 (unstripped; atom table +13, CInf +5), +28 stripped. 2 instrs (`bif map_get` + `is_eq_exact`) | MEASURED-HERE | `p1/out.txt`, `chunks.txt` |
| P1 | is_integer bytes | Code 81 -> 86 (+5); control with same body and no guard is the 81 | MEASURED-HERE | `p1/out.txt` |
| P2 | Tag test runtime | unguarded min 11.5 / median 13.2 ns; guarded min 16.8 / median 20.2 (+5.3 ns min). Remote call equal (11.7 vs 17.1). Noise control u1 vs u2 differs by 0.15 min. Run 2 reproduces | MEASURED-HERE | `p2/out.txt`, `out_run2.txt` |
| P2 | is_integer runtime | 9.05 / 8.85 / 9.09 min across unguarded / ctl / guarded: inside my ~0.3 ns noise. Consistent with 18's "below resolution", but my resolution is 0.3, not 0.09 | MEASURED-HERE | `p2/out.txt` |
| P2 | One entry label for local and remote call | `gtag.S`: `{call,1,{f,2}}` (local) targets label 2, the label after `func_info`; the export table lists `total/1` at that same label. `beam_asm.erl:115-120` passes the one `Entry` to `beam_dict:export/4` or `local/4`; `beam_dict.erl:103-107, 113-117` | MEASURED-HERE + source cite | `p2/gtag.S` |
| P2b | Cost of guarding the private callee too | pub->priv chain, min ns: none 11.7; exported-only 17.9; every-function 23.7. Each tag test ~ +6 ns. Pattern-head variant: 14.8 (+3) | MEASURED-HERE | `p2b/out*.txt` |
| P2c | Does erlc elide a private guard the caller proves? | **int: yes, but only if every caller proves it.** one proving caller: 1 test module-wide (callee's elided); caller unguarded: 1 (kept); mixed callers: 2. **tag: never.** Caller with the identical guard: 2 tests; caller built the map literally: 1; caller pattern-matched Kind: callee's kept. Same with `+inline` | MEASURED-HERE | `p2c/out.txt`, `w/*.S` |
| P3 | Forged value reaches private fn | Table in section 3. Exported-only: `First([forged])` returns `<<"free">>` from a `public int` | MEASURED-HERE (Erlang model of the emitted shape, not bsc output) | `p3/out.txt`, `out_fun.txt` |
| P3 | Limit of the tag test | Right tag, wrong payload passes every option | MEASURED-HERE | `p3/out.txt` |
| P4 | Gleam | Generated Erlang has no guard on public or private functions; forged `{quote,..}` returns `<<"free">>`, `pub_int(1.5)` returns `2.5`, forged opaque accepted. Public and private are emitted identically | MEASURED-HERE (1.12.0; 18 cites 1.18.1) | `p4/probe_generated.erl`, `out_gleam.txt` |
| P4 | Elixir | `defp` with `%Order{}` pattern rejects exactly what `def` does; the check is the user's pattern, nothing added by scope. `pub_first([forged]) -> defp` raises. Bare-variable `defp` accepts a forged struct. `@enforce_keys` is construction-time only (`%{__struct__: Ord, wrong_key: 1}` passes the pattern, fails later in `.amount`) | MEASURED-HERE; no .ex sources, behavioural only | `p4/out_elixir.txt` |
| — | Corpus: private vs public sigs with a bare record-typed parameter | 8 private vs 19 public (of 66 / 130 explicit sigs, 75 files). Single-line-signature grep, heuristic | MEASURED-HERE (grep) | `records.txt`, command in section 7 |
| — | Elm | not probed (not installed) | — | — |

Side finding, not asked: on OTP 25 the head-pattern form of the tag test costs about half the
guard form at runtime (+3 vs +6 ns) and 6 bytes more code (+18 vs +12). `tag_test/3` emits the
guard form. Whether that holds on OTP 28 is unmeasured.

## 3. The program that decides it

```csharp
record Order  { int Amount; }
record Basket { Order Primary; }

private int Total(Order o) -> o.Amount;

public int Sum(Order o)            -> Total(o);          // A: depth 0
public int First(list<Order> os)   -> os switch { [h, ..] => Total(h), [] => 0 };   // B: from a collection
public int Owed(Basket b)          -> Total(b.Primary);  // C: field of a guarded record
public fun<Order, int> Handler()   -> Total;             // D: private fn leaves as a value (75)
```

A foreign caller passes `Quote{Amount: "free"}` (wrong identity AND wrong payload type). Erlang
models of what `bs_emit` produces (P3, MEASURED-HERE; bsc output itself RECORDED-NOT-RERUN):

| call | exported only | every function |
|---|---|---|
| `Sum(forged)` | `function_clause` at `Sum` | same |
| `First([forged])` | **returns `<<"free">>`** | `function_clause` |
| `Owed(Basket{forged})` | **returns `<<"free">>`** | `function_clause` |
| `Handler()(forged)` | **returns `<<"free">>`** | `function_clause` |
| `First([Order-tagged, bad payload])` | returns `<<"free">>` | returns `<<"free">>` |
| every valid input | passes | passes |

Read it carefully. A is the only shape the ticket's "dead weight" argument describes, and there
the private test is dead. B, C and D are outcome 3 from 18's own definition, and the private tag
test is the only thing standing. The last row bounds it: the tag test closes forged identity,
not forged payload, under any option.

Which holes are already scheduled to close at the exported boundary (RECORDED):

- C: ticket 46 §4 decides a fixed number of projections (record field, tuple element) is
  guarded at the boundary. Unbuilt (F24 §5). When built, C closes at `Owed` and the private
  test becomes dead for C.
- B: 46 §4 and 11 refuse a guard through a collection (O(n) in a caller-chosen length). B
  cannot close at the exported function by that rule.
- D: nothing records a defence. I did not find a ticket deciding whether a private function may
  be handed to foreign code (grepped `75-a-function-as-a-value.md`: private functions are valid
  lambda targets, boundary exposure not discussed). Unverified in B#.

## 4. Options

**Option 1. Both guards exported-only.** Tag test joins the int test.
```
// compiler delta, bs_emit.erl guard_one/8 line 283
{ok, Tag} when Public -> ...      %% add the guard; a clause {ok,_} (private) -> {Pat, []}
```
- Compiler delta: one clause plus a test pinning F3.9's wording. `Public` is already threaded.
  Existing `private Inner(Order o)` expectation from 46 flips. Saves 12 B and ~6 ns per
  private record parameter; 8 such signatures in the corpus heuristic.
- Evidence: P1, P2b. B, C, D above become silent unless 46 §4 closes C and a rule closes D.
- Strongest counterargument: it makes `First(list<Order>)` return a binary from `public int`.
  18 states the guarantee as "never silently". Option 1 breaks it at B today and cannot repair B
  by 46's own rule. The ticket's "too narrow is a silent hole" is this row.

**Option 2. Both guards on every function.** Drop `when Public` at line 291 too.
```
%% guard_one/8: the `none when Public ->` clause becomes `none ->`
```
- Compiler delta: delete one guard. Corpus: 66 explicit private sigs, 12 with a bare `int`.
  F24.6 ("private Inner unguarded") flips, and `is_int_only` at bs_emit.erl:~176 (IntOnly
  comment: "or a checked B# call site does when it is private") must be rewritten.
- Evidence: P2c says erlc removes a redundant private `is_integer` when every caller proves it,
  so the int half is near-free at machine level where the exported caller is guarded (P2c a),
  and costs one test where a caller is unproven (c). P2c also says the tag half is **never**
  removed, and P2b prices it at ~6 ns per chain on a trivial body. Each pass-through A pays twice.
- Strongest counterargument: it prices the common case (A) to protect the rare one, and it
  contradicts 18's "interior functions already pay nothing" and 18 §4's stated reason (one entry
  label means the cost cannot be split). Private-by-default (40, amended 2026-08-17) makes most
  functions private. Also D and B stay incomplete on payload (last row).

**Option 3. A private function guards iff a value of unchecked shape can reach it.** Shape:
no guard when every in-module caller passes (a) a depth-0 parameter the enclosing function's
own guard tested, or (b) a literal construction, and the function is never taken as a value;
otherwise guard. Applies to both tests.
- Compiler delta: a per-module pass before `boundary_guards`: for each private function, collect
  call sites, classify each argument (`tested_param | literal | projection | other`), and record
  `escapes` if the name appears as a value. Output: a set of (function, position) pairs that
  need a guard, passed into `guard_one` in place of `Public`. Changes the symbol table: each
  private function gets a `fed_by` entry.
- Evidence: P3 rows A, B, C, D are exactly this partition: A unguarded, B/C/D guarded.
  P2c shows erlc already runs this style of analysis for `is_integer` (type propagation to
  local functions), but never for tag values (callee kept its test even when the caller built
  the map literally), so B# would be doing something erlc will not.
- Strongest counterargument: it is whole-module analysis, which **18 §4 rejected on stated
  grounds**: an edit to a caller silently moves a callee's emitted boundary with no diff on the
  callee. 18 §4 rejected it for exported-calls-other-file; whether the same reasoning reaches a
  same-module private callee depends on whether the standing one-function-per-file constraint
  applies to private functions. I did not find that settled. If it does, Option 3 needs a new
  ticket or an exception.

## 5. Recommendation

**Do not pick Option 1 or Option 2 by the word "exported".** The data point that decides it
is that the hole is a *depth* question, not a *scope* question. Recommend: **keep the tag test on
private functions** (it is the only defence at B and D, and costs 12 B), **keep the int test
exported-only** for now, and write the one-sentence rule as "a test runs where a value of
unverified shape can arrive, and the int kind is verified at every arrival today by the
exported test plus F24 §6's narrowing-site tests". That rule keeps F24 as built, leaves the tag
test as built, and removes the contradiction by changing the *comment* and 18 §4's wording, not
the emitter. Then write the missing test: a private function receiving a forged record from a
collection, which does not exist in F3/F24 scenarios.

Caveat I could not close: if David wants a single mechanical rule, Option 2 is the only one that
is function-local and sound at B, C and D; its cost is the ~6 ns and 12 B per private record
parameter (8 corpus sites), which I measured on OTP 25 only.

## 6. Limitations

- bsc was not run. Every statement of what bsc emits is RECORDED from `bs_emit.erl`, F3, F24,
  tickets 18/26/46/58. P3 reproduces the *shape* (`map_get('Kind', X) == Tag` as a head guard) in
  plain Erlang; it does not prove that bsc emits that for these B# programs.
- OTP 25.x on x86_64 VM with ~10% run-to-run noise. The ticket's numbers are OTP 28, arm64. OTP 26+
  changed map-guard code generation; I could not measure it. The ~6 ns tag-test cost may differ.
- Corpus counts are a grep over single-line signatures, not a type-resolved count.
- Elixir: no .ex sources installed; claims are behavioural. Gleam 1.12.0 vs 18's 1.18.1.
- Elm: not probed (not installed).
- Not run: whether B# lets a private function be passed to foreign code (D). That is unverified.

## 7. Probe index

All under `/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/59/`
(copy in `/home/user/beam-sharp/artifacts/probes-59/`). `./run_all.sh` runs everything (about 4 min).

- P1: `cd p1 && escript gen.escript && escript chunks.escript`
- P2: `cd p2 && ./gen.sh && escript bench.escript`; entry label: `erlc -S p2/gtag.erl`, read `gtag.S`
- P2b: `cd p2b && ./gen.sh && escript bench.escript && ./pat.sh`
- P2c: `cd p2c && ./run.sh`
- P3: `cd p3 && erlc forge.erl forge_fun.erl && erl -noshell -s forge main -s init stop && erl -noshell -s forge_fun main -s init stop`
- P4 Gleam: `cd p4/gl && gleam build`, copy `build/dev/erlang/probe/_gleam_artefacts/probe.erl` to `p4/gebin/probe.erl`, `erlc -o gebin`, `erlc gl_forge.erl && erl -noshell -pa gebin -s gl_forge main -s init stop`
- P4 Elixir: `cd p4 && elixir ex.exs`
- Corpus: `grep -rhE "^\s*private .*[(, ]($(paste -sd'|' records.txt)) [a-z]" compiler/examples --include=*.bs | wc -l`
