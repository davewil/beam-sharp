# Decision brief — ticket 39, emitted code quality (ENG-211)

**Environment**: Erlang/OTP 25.3.2 (erts-13.2.2.5), JIT enabled, Elixir 1.14.0, Linux sandbox. The
ticket's numbers are OTP 28 / erts-16.4, Elixir 1.19.5, Gleam 1.18.1, Apple Silicon. **These are not
the same JIT and the two sets of numbers must never be quoted against each other as if they were
a reproduction.** Every number below is a fresh OTP-25 measurement from this sandbox, min of 25
runs, direct `.beam` calls, same methodology as `aoc/bench/bench.erl`. Raw scripts and captured
output are under `artifacts/39-emitted-code-quality/probes/`.

## What's undecided

The ticket asks whether beam-sharp's emitted code is worth compiler work, and if so what the
highest-leverage fix is, on the theory that a mandatory signature (ticket 04) makes beam-sharp
declare `int` where Erlang's compiler infers `0..99` and the JIT specializes against the
narrower fact. **That specific theory does not reproduce in this sandbox**: on OTP 25, with the
exact source files in `aoc/bench/` today, beam-sharp's real hot loop (`Day01.Spin`, private,
called only from `Clicks`) disassembles **byte-for-byte identical** to hand-written Erlang's
`spin/4` — same 26 instructions, same `{tr,{x,0},{t_integer,{-99,99}}}`-style annotations on both
sides — and the measured runtime gap on the original tight-integer-loop workload is **1–4%**, not
20%. A genuinely new, independently-confirmed gap turned up instead, on the axis the ticket
flagged as unmeasured: **record field projection**. What's actually undecided now is narrower
than the ticket framed it: not "why does the tight loop lose 20%" (unreproduced here, and possibly
OTP-28-specific), but "beam-sharp's `.field` access always compiles to an `erlang:map_get/2` BIF
call rather than a `get_map_elements` pattern match, and that call is measurably slower — is that
worth fixing, and is the fix simple enough to be worth doing now."

## Sub-investigations, what came back

1. **Localize the gap** (`02-spin-isolated-otp25.txt`, `03-causal-test-otp25.txt`): isolating
   `Spin` from the outer fold changes nothing — the real `Day01.Spin` and `bench_erl:spin/4` are
   identical code on OTP 25, so isolating an already-identical loop just reconfirms identity.
2. **Causal test** (`03-causal-test-otp25.txt`, via `strip_tr.erl`): hand-stripped every
   `{tr, Reg, Type}` annotation from Erlang's own compiled `bench_erl.beam` (reassembled from
   `erlc +to_asm` output through `compile:file([from_asm])`, so nothing else about the code
   changed) and reran. **The stripped variant is consistently 5–8% slower than the annotated
   original** (18.6–19.9ms vs 17.7–18.0ms min, five runs) — real, reproducible, above the ~0.3ms
   noise floor. This is the strongest evidence in this sandbox that annotation-loss is causally,
   not just correlationally, connected to a slowdown — it just isn't what's happening to
   beam-sharp's real code here, because that code isn't losing the annotation.
3. **Can `bs_emit` supply the missing type info?** No channel exists to try, because there's no
   gap to close on this axis in this build — but the general mechanism was tested and confirmed on
   the *other* axis (below): `-spec`/`-type` attributes are never consulted by
   `beam_ssa_opt`/`beam_types` (the ticket's own spec-stripping experiment already implied this;
   nothing here contradicts it), so threading `bs_types` intervals into the emitted `-spec` was
   never going to help — the lever has to be code *shape*, not annotation.
4. **Records and dispatch** — the real finding. `ShapeBench.bs` (two record types, a union, a tight
   loop constructing and dispatching over them) vs a hand-written Erlang counterpart using
   beam-sharp's own map erasure (`#{'Kind' => 'ShapeBench.Circle', 'R' => R}`, confirmed against
   the actual disassembly): **beam-sharp is consistently 17–19% slower** (`04-records-dispatch-otp25.txt`,
   five runs, 19.75–20.20ms vs 16.60–17.01ms min). Disassembly diff shows `Loop`/`Pick` are
   instruction-identical; the difference is in `Area`, where beam-sharp's `.R`/`.S` field access
   compiles to `{bif, map_get, ...}` while Erlang's map-pattern head compiles to
   `{get_map_elements, ...}`. Isolated in a controlled microbenchmark (`mapget_probe2.erl`, map
   construction forced through an opaque cross-module call so the optimizer can't fold the round
   trip away — verified via disassembly that both paths survive): **`map_get` is ~30% slower than
   `get_map_elements` for the identical field read**, four runs, consistent to within 0.3ms
   (`05b-mapget-isolated-fixed-otp25.txt`).

   **The mechanism is in the source, not inferred.** `bs_emit.erl`'s `expr({e_proj, L, V, Field},
   _C)` lowers every `.field` projection to `{call, L, {remote,...,erlang,map_get}, [...]}`,
   unconditionally, with the comment *"One `map_get`. Guard-safe by construction, which is what
   lets the same node serve the boundary tag test above."* That's a deliberate choice: `map_get/2`
   is one of Erlang's guard-safe BIFs, so the same lowering works whether the projection appears in
   an ordinary expression or inside a `when` clause. A `case`-with-map-pattern does not have that
   property — `case` cannot appear in a guard at all.

   **Spike result** (`06-mapget-alt-lowering-otp25.txt`): a `case M of #{'R' := V} -> V end`
   lowering, tested standing beside both the current `map_get` path and the pattern-match path,
   **fully closes the gap** — 1.00–1.01x against the pattern-match baseline, four runs. So a fix
   exists and was measured to work, but it isn't a one-line swap: it only applies where the
   projection is *not* inside a guard, so `bs_emit` would need to keep `map_get` for guard
   positions and switch to the `case` lowering for body positions — two code paths, not one.

## Options

**(a) Do nothing on the tight-loop axis; it doesn't reproduce here and may be OTP-28-specific.**
For evidence: byte-identical disassembly on OTP 25, 1–4% runtime delta, five consecutive runs. This
is the strongest evidence in the whole investigation — not a benchmark number but the actual
compiled bytecode matching instruction-for-instruction, including the JIT annotations. Against it:
this sandbox cannot run OTP 28, so it cannot rule out that the ticket's original 20% is real and
version-specific rather than a measurement artifact; "doesn't reproduce on the version we have" is
not the same claim as "isn't real." Strongest counterargument: if OTP 28 genuinely treats
`compile:file([from_abstr])` input differently from plain `.erl` source in a way OTP 25 does not,
that's a real, version-dependent risk that resurfaces the moment the project's pinned OTP 28.5
toolchain is available to test against, and shipping "do nothing" without ever confirming it on
OTP 28 leaves the original finding unaddressed rather than refuted.

**(b) Fix `.field` projection: `map_get` in guards, `case`-with-map-pattern in bodies.** For
evidence: a controlled, disassembly-verified microbenchmark showing the proposed lowering matches
native-pattern-match speed exactly (1.00–1.01x) while the current lowering costs ~30% on the
isolated read and 17–19% on a realistic records+dispatch workload — both reproduced across
multiple runs. This is a real, understood, actionable mechanism with a tested candidate fix,
independent of any OTP-28-vs-25 uncertainty (the mechanism is `map_get` vs `get_map_elements`,
which exists on both). Against it: `bs_emit` would need guard-position tracking for `{e_proj,...}`
that may not currently exist at that call site (unverified — I read the lowering, not the
guard-context plumbing around it), and every record-heavy program pays this cost today, but no
workload in the repo's own benchmarks or exemplars is dominated by field reads the way `ShapeBench`
deliberately is, so the *practical* impact on real beam-sharp programs is unmeasured. Strongest
counterargument: this is optimization work on an emitter CLAUDE.md's own ticket says has "never
been tuned," on a codebase where **no optimization work has ever been done** — fixing one
lowering in isolation, discovered by a synthetic benchmark built to find it, risks exactly the
"measuring the author's coding style" failure mode the ticket itself calls out in its Gleam-guard
anecdote, just inverted (a benchmark built to expose a gap, finding one).

**(c) Accept both as documented, unfixed tradeoffs and move on.** For evidence: nothing in this
investigation shows either gap breaking a real exemplar or blocking other tickets — F3 is already
"done," ticket 18's boundary-guard question is separately tracked, and the tight-loop question may
be moot on the OTP version this sandbox has. Against it: the causal test in §2 above (annotation
stripping → 5–8% real slowdown, reproduced five times) proves the *mechanism* the ticket theorized
is real and measurable, even though beam-sharp isn't currently triggering it — meaning the tight-loop
risk is dormant, not disproven, and could resurface with an unrelated `bs_emit` change that happens
to widen a type the optimizer currently narrows on its own. Strongest counterargument: "dormant risk"
is not "verified gap," and spending compiler effort defending against a risk this investigation
could not even reproduce is premature relative to (b), which has a confirmed, present-tense cost.

## Recommendation

**(b), scoped to the field-projection fix only** — not the tight-loop axis, which this session's
evidence argues against touching at all right now. The one piece of evidence that tips it: the
`case`-vs-`map_get` spike (`06-mapget-alt-lowering-otp25.txt`) is the only measurement in this
entire investigation where a proposed fix was tested standing beside its target and matched it
exactly, on a mechanism confirmed twice — once in the realistic `ShapeBench` workload and once in
an isolated, disassembly-verified microbenchmark holding everything else constant. Every other
finding here is either a non-reproduction (the tight loop) or a risk without a tested remedy (the
annotation-stripping causal test). This is the one place the investigation produced not just a
diagnosis but a working prescription. The gating question for David, phrased per CLAUDE.md's rule
(ask the one that gates, not a matrix): **does `bs_emit` already know, at the point it lowers
`{e_proj,...}`, whether it's inside a guard?** If yes, the fix is small and should be scoped as a
feature. If no, that plumbing is the actual cost of (b) and is worth seeing as B# code before
committing to it.

## What I could not verify

- **The OTP-28 vs OTP-25 JIT gap.** This sandbox has Erlang/OTP 25.3.2 only; the project is pinned
  to OTP 28.5, and mise/asdf are unavailable while github.com/api.github.com return HTTP 403
  (confirmed org egress block). Every number in this brief is an OTP-25 number. The ticket's
  central claim — beam-sharp's tight loop carries a bare `{x,0}` where Erlang's carries
  `{tr,{x,0},{t_integer,{0,99}}}` — **does not reproduce on OTP 25**: both sides carry identical
  annotations here. I cannot determine whether that's because OTP 28's compiler backend treats
  `compile:file([from_abstr])` differently from plain `.erl` source, because something in the
  repo changed between the ticket's filing (2026-08-15) and now in a way git history doesn't
  clearly show (the repo's history appears to be periodically squashed/rebased — `git log` on
  `bs_emit.erl` and `aoc/bench/` shows only two touches since 2026-08-15, neither of which reads
  as a type-narrowing change, but I cannot rule out a rebase hiding the actual diff), or because
  of some other OTP-28-specific factor. **This is the single most important unresolved question
  the next session with OTP 28 access should answer first**, and it should re-run
  `03-causal-test-otp25.txt`'s exact method (strip `{tr,...}` from real Erlang, compare against
  real beam-sharp) on OTP 28 before trusting any theory about why the two versions disagree.
- **The Gleam leg of the original four-way benchmark.** Gleam is not installed and cannot be
  installed here (no apt package, github.com blocked). No Gleam numbers appear anywhere in this
  brief or its artifacts; the three-way comparisons above (Erlang/Elixir/beam-sharp) explicitly
  drop Gleam rather than fabricate a number for it.
- **Whether the field-projection fix's ~30% isolated / ~17-19% realistic-workload gap matters for
  any *actual* beam-sharp program.** No exemplar or existing benchmark in the repo is
  records-and-projection-heavy the way `ShapeBench.bs` was deliberately built to be; I could not
  find or construct a real workload (as opposed to a synthetic one built to expose the mechanism)
  to weigh the fix's value against.
- **Whether `bs_emit` already tracks guard-vs-body position at the `{e_proj,...}` call site.** I
  read the lowering clause and the surrounding comment but did not trace the caller chain far
  enough to confirm whether guard context is already available there or would need to be threaded
  in — this determines whether option (b) is a small, contained change or requires new plumbing.
- **Absolute timing comparability.** This sandbox's absolute times (~17-20ms for the tight loop)
  are roughly 3x the ticket's OTP-28/Apple-Silicon numbers (~5-6ms) — expected from a
  slower/older JIT plus different, likely more constrained, hardware, and not itself informative;
  only the *relative* (beam-sharp vs Erlang) numbers within this sandbox are used above.
