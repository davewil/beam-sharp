# AoC as a test of the language, and where beam-sharp stands

**2026-08-15.** Written at the end of the session that shipped F7 (`switch`), ran beam-sharp against
Advent of Code for the first time, and benchmarked it against the three other BEAM languages.

A snapshot, not a decision. Nothing here changes a ticket.

---

## 1. Why AoC, and what it was worth

The exemplars in `compiler/examples/exemplars/` were written to answer specific ticket questions.
AoC was written by someone else, for other languages, with no interest in what this one finds
convenient — which is the entire value. David: *"I want to see if beam-sharp can solve AoC
problems."*

**Two puzzles, both solved, both exact.**

| Puzzle | Answers | Verified against |
|---|---|---|
| 2019 Day 1 — Rocket Equation | 3358992 / 5035632 | David's own answers |
| 2025 Day 1 — Secret Entrance | 1195 / 6770 | David's own answers |

**The thesis held up on code written by an outsider.** Both solutions came out **exhaustive with no
catch-all** — including 2019's recursion, which the checker proves total over `int` because the
guard states the termination boundary as an *interval* (`m <= 8`) rather than testing a computed
result. A guard testing the result would have credited nothing and forced a `_`. Nobody designed
the puzzle to reward that; it just did.

2025 Day 1 went further: `Spin`'s three clauses cover `left = 0`, `left > 0` and `left < 0` and are
*proven* to, and part two simulates **673,364 individual clicks** through tail calls without
complaint.

### The false start, which is the more useful half

The first write-up claimed 2019 Day 1 *"solved, both parts, exact"* **before any input existed**.
David had withheld it deliberately: *"you didn't get the input, and you made up the question."*

Both charges were right. The number offered as evidence — `Sum([12, 14, 1969, 100756]) = 34241` —
was the sum of the four *example* masses, which AoC never asks for. The question was invented,
computed and presented as validation.

**The seven checks that were real came from the problem statement. The eighth came from me.** That
distinction is narrower and more useful than "check your work": a check you write yourself proves
the code does what you already believed. It is worth knowing which of your checks an outsider
supplied. The repo had written the same finding down months earlier — exemplar 25a *"constructed a
shape to answer the question"* — and the map retracted it the same day.

---

## 2. What the puzzles cost the language

Both gaps were found in the first ten lines of real work, and neither was known.

**Division does not exist.** No `/`, `%`, `div` or `rem` in the lexer. Measured: division appears
**zero times** across `LANGUAGE.md`, every ticket and the fog — absent by *oversight*, never
discussed. → **[ticket 38](../wayfinder/issues/38-division-and-modulo.md)**, which splits cleanly:
truncation is settled because C#, JavaScript and Erlang all agree (measured; Python's floored
`-7 // 2 = -4` is the outlier and is not an audience), while **divide-by-zero is where they split**
and where beam-sharp could make `/` the first operator carrying a precondition its checker enforces.

**Unary minus did not exist either** — `-1` did not lex as anything, so a direction had to be
written `0 - 1`. Unlike division this needed no decision: never discussed anywhere, and C# and
Erlang both have it, so the tiers agreed. **Fixed the same night.** The regression it invites is
the interesting part — adding a prefix `-` to a grammar that already has an infix one is exactly
where a parser re-associates silently, so the test asserts that `1 - 2 - 3` is still `-4`, because
yecc reported zero conflicts and F6.9's rule is that the count is not the check.

**And the real blocker is neither.** A puzzle input is a file, and beam-sharp has no file I/O, no
`string`, no `binary`, and nothing to take either apart. `:file.read_file/1` returns a binary that
cannot be given a type. Both solves required the shell to read *and, for 2025, parse* the input —
`L68` became `-68` before the compiler saw anything, which is a genuine part of that puzzle solved
outside the language.

> **beam-sharp can express the computation and cannot read the question.**

That is a sharper argument for what `string` and the module system are worth than any exemplar has
produced.

---

## 3. Performance: two workloads, opposite answers

All four languages compile to BEAM bytecode and run on the same VM, so the only honest comparison is
of **emitted code**. Both harnesses load `.beam` files and call the function directly — no CLI
startup, no compile step, no VM boot inside the number — and check the answer before the clock.

| workload | dominated by | result |
|---|---|---|
| 2025 Day 1 pt 2 — 673k tight integer iterations | the **emitted loop** | **beam-sharp 20% behind**, consistently |
| fib(100,000) — bignums, 100k cons cells, GC | the **runtime** | **dead heat**; the ordering flips between runs |

**So the gap is not a general overhead.** It appears exactly where the emitted instructions are the
whole cost and vanishes where time goes into BIFs, allocation and garbage collection — which every
language on this VM shares equally.

**And the cause is not established**, which is recorded as such rather than given a plausible story.
Ruled out by measurement: the FFI (`:erlang.rem` is lowered to the BIF, not a remote call), the
instruction sequence (`Wrap/1` and `Spin/4` disassemble identically, 26 instructions each), and the
`-spec` (stripping all seven leaves the loop byte-identical and the time unmoved). What remains is
that operands carry less JIT type information. → **[ticket 39](../wayfinder/issues/39-emitted-code-quality.md)**.

**The framing in that ticket runs against the intuition, deliberately.** beam-sharp is not paying a
tax for being typed — nothing extra executes. It is *discarding* information at the emission
boundary: ticket 20's exact intervals mean it **knows** `Wrap` returns `0..99`, a fact Erlang's
analyser has to reconstruct and cannot spell in a `-spec` at all. Ticket 04's mandatory signature is
a candidate for why it currently cannot use that: a declared `int` return is never narrowed. If that
is right, **the ceiling is above Erlang's, not below** — and no optimisation work has ever been
done, so 20% is a baseline, not a verdict.

`fib(100,000,000)` was asked for and is not slow but *impossible*: `Fib` returns a **list** of n
Fibonacci numbers, the nth has ~0.209n digits, and the measured scaling is ~O(n²) — extrapolating to
about six years and ~10¹⁵ bytes.

### Both benchmarks measured the wrong thing first

Worth recording together, because it is the same class of error twice in one night.

- The **four-language table** initially showed Gleam and beam-sharp *beating* hand-written Erlang.
  Three of the four implementations carried a `when left > 0` guard the fourth did not — one extra
  comparison × 673,364. It was measuring my coding style.
- The **fib harness** gave an 8× min/median spread for Elixir (82 ms against 832 ms). It was
  measuring garbage collection: each run's garbage was still being collected while the next ran.
  Fixed by running every iteration in a fresh process that then exits.

Both are kept in `aoc/bench/README.md` rather than tidied away.

---

## 4. Where the project stands

**The idea is proven; the language is early.** These are different claims and only the first is
settled.

### What is genuinely established

- **The differentiator works and is built.** Multi-clause heads with exhaustiveness proven at
  compile time — F1 through F7, 169 tests, three gated surfaces.
- **The residual-as-diagnostic is the best part**, and it emerged from the design rather than being
  bolted on. `:cancelled => ...`, `0`, `int <= 1 | int >= 3` are all things the compiler *hands you
  to paste*.
- **It is not slow.** Level with Erlang, Elixir and Gleam on allocation-heavy work; 20% behind on a
  tight loop, localised, unexplained, and untuned.
- **It survives outside contact.** Two puzzles by an author with no stake in it, both exhaustive
  with no catch-all.

### What is not

- **It cannot do I/O.** No `string`, no `binary`, no file access.
- **The acceptance corpus does not compile.** The exemplars were also, until this session, written
  in a **dead dialect** — 63 nameless clause heads, measured — because nothing gated them.
- **OTP is declared, not checked.** `behaviour` emits an attribute and nothing verifies the
  callbacks, so ticket 00's showcase still has no implementation strategy under it.
- **The module system is the load-bearing fog**, and four other patches wait on it.

### The risk worth naming

**Decisions keep; unbuilt ones compound.** The whole of the prelude's stratum 2 is unbuilt,
`ToExistingAtom` needs respelling before anyone implements it from ticket 10, and F8 is blocked on a
token every future `.bs` file will carry. The gap between *decided* and *built* is widening faster
than it is closing.

### The strongest asset, and it is not the type system

**The gates.** In one session they caught `true` silently miscompiling every boolean clause head,
63 clause heads rotting in a dead dialect, a scope section presenting four boundaries as walls when
none was, and two benchmarks measuring the wrong thing. **None of that was caught by care — care is
what produced the errors.** That is what makes the clean-room handoff plausible at all, and it is
rarer than the type system.

---

## 5. If one thing came next

**`string` and `binary`.** It is the only item on the critical path for *both* corpora — it unblocks
I/O for AoC and `list<string>` for the exemplars, which fail on the identical `unknown_builtin`
error — and it is already decided (ticket 20, prelude stratum 2), so it is a feature rather than an
argument.

Three things are owed before much else moves, each with its blocker named:

| | Status | Blocked on |
|---|---|---|
| **F8** `var` binds, `=` matches | drafted | one token — the match marker, not `^` |
| **Ticket 38** division and modulo | open | divide-by-zero: crash, or a checked precondition |
| **Ticket 39** emitted code quality | open | an experiment, not a decision |
