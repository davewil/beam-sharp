# Decision brief — ticket 59 (ENG-241): the boundary guard applies two rules with different scopes

**Status of the ticket: left open.** This brief recommends; it decides nothing.
Probes: `artifacts/probes/59/` (outputs beside each script as `output-*.txt`). Toolchain and caveats: `artifacts/probes/README.md`.

## The gating question (ask this one alone)

> A `list<Order>` parameter on an exported function is **not** checked element by element. When an element reaches a private function, does it count as *checked*?

Today the answer is "no" for the record tag (the private function re-tests) and "yes" for the int kind (it does not). The ticket treats that as two rules to reconcile; the probe below shows it is one unanswered question about containers.

## What the ticket did not have: a program that tells the two readings apart

The ticket argues "defect" (every private call site is a checked B# call, so the guard is dead weight) against "not a defect" (a forged record can arrive through an exported function, which 18 §4 deliberately does not trace). Neither side had a program. Here is one (`59/probe.sh`; builds the same module under three compilers, then calls it from Erlang with forged data):

```csharp
record Order { Id: int, Total: int }
record Other { Id: int, Total: int }          // same fields, different record
type Octet = int where value >= 0 and value <= 255

public int First(list<Order> os)
First([])      -> 0
First([o, ..]) -> Total(o)
private int Total(Order o)  ;  Total(o) -> o.Total
public int Direct(Order o)  ;  Direct(o) -> o.Total

public int FirstOctet(list<Octet> os)
FirstOctet([o, ..]) -> Classify(o)
private int Classify(Octet t)   // Classify(>= 128) -> 1 ; Classify(<= 127) -> 0
public int Direct2(Octet t)     // same body
```

Called from Erlang (`output-probe.txt`; builds: **c** = today, **narrow** = tag test exported-only, **wide** = kind test on private too):

| call | c (today) | narrow | wide |
|---|---|---|---|
| `First([genuine Order])` | 9 | 9 | 9 |
| `First([forged Other])` | `function_clause` | **returned 77** | `function_clause` |
| `Direct(forged Other)` | `function_clause` | `function_clause` | `function_clause` |
| `FirstOctet([200])` | 1 | 1 | 1 |
| `FirstOctet([200.5])` | **returned 1** | **returned 1** | `function_clause` |
| `Direct2(200.5)` | `function_clause` | `function_clause` | `function_clause` |

Reading the table:
- **The private tag test is not dead weight.** It is what stops an alien record that arrived inside a list from being read as an `Order` (today vs narrow, row 2). The "defect" reading's premise — "site 1 has already rejected a wrong tag" — does not hold for container contents.
- **The kind side already has the hole the narrow build would open.** Today an out-of-domain float inside `list<Octet>` reaches the private `Classify` and is answered (row 5, columns c and narrow). So the asymmetry is not a deliberate pair of rules: one half protects containers by accident and the other leaves them open.

## Sub-decisions

| # | Sub-decision | Settled by |
|---|---|---|
| a | Does a container element reaching a private function count as checked? | the gating question |
| b | Scope of the tag test (everywhere / exported-only) | (a) |
| c | Scope of the kind test (exported-only / everywhere) | (a) |
| d | Is "exported" the right discriminator at all? 18's measurement says the BEAM's own is exported-vs-local, one entry label (`ticket 18 §1`) | already priced in 18; unchanged |

## Cost (measured)

`59/cost.sh`: a private recursive loop of 5,000,000 iterations calling a private function (min of 15 runs, one execution of the script per row — rerun before relying on the third digit):

| build | record loop (2 tag tests/iteration) | int loop (Octet) | `G.beam` bytes (probe module) |
|---|---|---|---|
| c (today) | 43 ms (saved run; 50 median of 4 runs) | 40 ms | 1904 |
| narrow | 41 ms (41 median of 4) | 42 ms | 1880 (−24) |
| wide | 47 ms (52 median of 4) | 40 ms | 1976 (+72) |

(**Verifier correction:** my first draft quoted 53/38/56 ms from one early run; repeated runs spread by as much as the effect.)

- The tag test costs roughly **0.8 ns per test** (≈8 ms over 10 M tests across repeated runs; narrow was faster in 4 of 4 runs) — real, small, and no larger than the run-to-run spread.
- The kind test on a *private* function costs **nothing detectable** in a loop: 40 ms in both c and wide. The JIT already knows the argument is an integer.
- 26a measured the tag test at +14 bytes flat; 18 measured `is_integer` at +3–5 bytes. This module's totals agree in order of magnitude.

## Survey (what neighbouring languages do for the same forged value)

`59/neighbours.sh`, executed:

| language | forged value reaching a **public** fn | reaching a **private** fn via a container | instructions that test the type |
|---|---|---|---|
| Gleam 1.19.1 | `pub_total({other,1,77})` → **77** | `via_priv([{other,1,77}])` → **77** | 0 type tests in `pub_total` and `pub_double`; `pub_double(2.5)` → `5.0` |
| Elixir 1.20.4 | `M.pub(%{__struct__: Other,…})` → `FunctionClauseError` (struct pattern in the head) | `defp priv(%O{} = o)` also → `FunctionClauseError` | n/a — the match is in the head, identical for `def` and `defp` |
| Elixir, untyped head | `pub_untyped(forged)` → 77 | — | — |
| Erlang | not probed: nothing at either site unless the author writes a guard — stated from the language definition, not run | | |

Reading: no neighbour distinguishes public from private for the check. Gleam trusts its type system at both and so would accept the forgery everywhere; Elixir's check is a *pattern the author wrote*, which applies equally to `def` and `defp`. The only language with a visibility-scoped rule is B# today. Elm: unprobed (package server unreachable).

## Options

**A. Leave the code; write the rule down.** Tag test everywhere because container contents are unchecked; kind test exported-only. Delta: none in code; ticket 18 §4 gains a sentence, `bs_emit.erl:333`'s comment ("that asymmetry is deliberate") gains its reason.
Strongest counterargument: the table above — `FirstOctet([200.5])` returns `1` today. A rule that protects `list<Order>` and not `list<Octet>` is the same gap with a different spelling, and the comment would be defending it.

**B. Narrow: exported-only for both** (`59/proto/narrow.patch`, 3 changed lines in `guard_one`). Matches 18 §4 literally and the cost section's "elided entirely".
Strongest counterargument: `First([forged Other])` **returns 77** (measured). It trades about 1 ns per private call for a silent wrong answer on forged container contents, and the ticket's own sentence says the cost of getting it wrong is asymmetric in that direction.

**C. Wide: exported and private alike for both** (`59/proto/wide.patch`, one changed line). Closes the `FirstOctet([200.5])` row.
Strongest counterargument: it contradicts 18's "non-exported function has the test elided entirely" and puts a kind-and-range guard on every private `int`-refined parameter, on top of the tag test private record parameters already carry. Measured here: nothing detectable in the int loop (40 ms vs 40 ms), **+72 bytes** in the probe module (one private function gained its guard), and the tag test's ~0.8 ns stays. It does not close union-typed containers: a forged record in `list<Order | int>` passes all three builds (verifier-measured), which needs the boundary walk 18 §4 declined.

## Recommendation

**C**, if the answer to the gating question is "no, container contents are not checked". Rationale: it is the only build in which the six calls above all behave identically for tag and kind, and its measured price is a few bytes and no detectable int-loop time. **B** is correct only if the gating answer is "yes" — which would first require the exported function to walk its container parameters (a different, larger piece of work; ticket 18 §4 explicitly declined it). A is the fallback if David wants nothing to change this month, but its comment would have to say that `FirstOctet([200.5])` is known and accepted.

## Not done / limits

- No gate run; same environmental limits as the other briefs (README).
- Timings are on a shared VM; the record-loop difference (~8 ms of ~45) is about the size of the run-to-run spread.
- Verifier probes (`artifacts/verification/ENG-241.md`): **wide does reject `[[200.5]]` in `list<list<Octet>>`** when the element reaches a private function (my claim that it does not was wrong); out-of-range ints (300) leak through today's build exactly as floats do; a forged record inside `list<Order | int>` is accepted by **all three** builds (the tag test covers only a single closed record); and wide also adds a float guard on private functions, which I did not cost.
- Erlang's row in the survey is not an executed probe.
