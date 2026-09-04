# Independent verification — ticket 39 decision brief (ENG-211)

Auditor: independent session, OTP 25.3.2 / Elixir 1.14.0, same sandbox class as the brief. All
work under `artifacts/39-emitted-code-quality-VERIFICATION-work/` (scratch; not part of this
report's deliverable). The brief and its probes were **not modified**.

Method note: for every claim below I rebuilt from the real, currently-checked-in source
(`git status --short compiler/src/ aoc/bench/` was clean before I started — no local
modifications anywhere in either tree) through a freshly-escriptized `bsc`
(`compiler/_build/default/bin/bsc`, rebuilt via `rebar3 escriptize` in this session), and wrote my
own disassembly/benchmark scripts from scratch rather than re-running the brief's captured
`.txt` output, except where noted.

## Claim-by-claim

### 1. Non-reproduction of the ~20% tight-loop gap — CONFIRMED

What I ran: rebuilt all of Erlang/Elixir/beam-sharp from `aoc/bench/bench_erl.erl`,
`aoc/bench/bench_ex.ex`, `aoc/bench/Day01/bench_bs.bs` through fresh `erlc`/`elixirc`/`bsc`
(Gleam skipped — confirmed not installed, `apt-cache search gleam` empty, matching the brief's
claim), using the brief's `bench_no_gleam.erl` harness (verified byte-for-byte reasonable: same
methodology as `aoc/bench/bench.erl`, minus the Gleam leg). Ran it 4 times fresh, then again
reversed impl order (beam-sharp timed first) for 2 more runs to rule out a benchmark-order
artifact (see §5 below — this class of artifact is real elsewhere in this investigation).

Result: beam-sharp consistently 1.00–1.03x relative to Erlang/Elixir, e.g. 17.54/17.41/17.47ms
(beam-sharp) vs 17.67–17.75ms (Erlang), 17.28–17.41ms (Elixir), across 6 independent runs, order
included. No 20% gap anywhere. **Directly reproduces the brief's finding, independently.**

### 2. Byte-for-byte identical disassembly, `{tr,...}` annotations included — CONFIRMED

What I ran: wrote my own `beam_disasm:file/1`-based dump script (not the brief's), disassembled
my freshly-built `Day01.beam` and `bench_erl.beam`, extracted `Spin`/`spin` and `Wrap`/`wrap`,
normalized only the module/function-name atoms, and diffed.

Result: **exact match**, `{tr,{x,0},{{t_integer,any},18446744073709551517,99}}`-style annotations
present and identical on both sides (note: OTP 25's disassembler prints intervals as
`{Kind,Lo,Hi}` with negative numbers as `2^64+n`, not OTP 28's `{Lo,Hi}` pair the ticket quoted —
a cosmetic version difference, not a substantive one; the annotation itself, its presence, and its
content are identical between beam-sharp and Erlang on this OTP). `diff` on both functions after
name-normalization: empty. This is the brief's most surprising claim and it holds up completely
under an independently-written disassembly script.

### 3. Causal annotation-stripping test (5–8% real slowdown) — CONFIRMED

What I ran: copied `strip_tr.erl` and read it carefully first — it recursively unwraps every
`{tr, Reg, _Type}` to `Reg` anywhere in the term tree, and substitutes the module name everywhere
via the same recursive-tuple/list walk; this is what it claims to do. Ran it myself:
`erlc +to_asm` on `bench_erl.erl`, then `strip_tr:main/3` to produce `bench_erl_stripped.S` and
`.beam` via `compile:file([from_asm])`. Verified `grep -c "{tr," bench_erl_stripped.S` → 0.
Verified correctness (`bench_erl_stripped:part_two/1` returns the same answer as `bench_erl`).
Re-disassembled the stripped module and diffed against the original `spin/4`: the **only**
difference (beyond the module-name atom, expected) is the absence of `{tr,...}` wrappers —
confirms the causal test's premise that annotation-presence is the sole isolated variable.

Ran `bench_causal.erl` (the brief's own harness) 5 times: stripped Erlang consistently 6–7%
slower than the annotated original (min 18.60–18.76ms stripped vs 17.44–17.64ms original), close
to the brief's captured 5–8% (18.6–19.9ms vs 17.7–18.0ms). **Real, reproducible, above noise.**

### 4. Records/dispatch: beam-sharp 17–19% slower on `ShapeBench` — CONFIRMED, with one flagged discrepancy

What I ran: copied `ShapeBench.bs` and `shape_bench_erl.erl` fresh, compiled both through the
freshly-built `bsc`/`erlc`, verified identical answers (`83337083375000` for `Grind(50000)`, and
`20354473547961` for `Grind(673364)`), disassembled both myself.

**`Area`/`area` (the field-projection site)**: confirmed exactly as claimed. beam-sharp's `Area`
does `get_map_elements` on `Kind` (the boundary-tag dispatch) then `{bif, map_get, [{atom,'R'},...]}`
for the field read; Erlang's `area` does `get_map_elements` for **both** the tag dispatch and the
field read. This is the precise, correctly-characterized mechanism.

**`Pick`/`pick`**: confirmed instruction-identical (module/function names aside) — `diff` empty.

**`Loop`/`loop` — FLAGGED**: the brief states "`Loop`/`Pick` are instruction-identical." My own
diff of `Loop` shows this is **not quite true**: beam-sharp's `Loop` carries `{tr,{x,0},...}`
annotations on its `test,is_eq_exact` and `gc_bif,'rem'` instructions that the hand-written
Erlang `loop` (no `-spec`) lacks. This is a real, reproducible difference the brief's own
`04-records-dispatch-otp25.txt` narrative glossed over. It does not change the central finding —
if anything it means beam-sharp has *more* type information here, working in beam-sharp's favor,
not against it, so it doesn't threaten the map_get conclusion — but "Loop/Pick are
instruction-identical" as stated in the brief is imprecise for `Loop`.

Reran `shape_bench.erl` (brief's harness) 4 times fresh, plus a reversed-order variant
(`shape_bench_rev.erl`, beam-sharp timed first) 3 times: consistently 1.16–1.21x, matching the
brief's 17–19% (my numbers ran slightly higher, 19–21%, but same order of magnitude and the same
direction). Order-reversal made no measurable difference here, unlike the isolated microbenchmark
below — this result is robust.

### 5. `map_get` vs `get_map_elements` mechanism and the ~30% isolated gap — CONFIRMED, but the harness has a real order/warm-up artifact worth flagging

**Source claim (`bs_emit.erl`)**: verified directly by reading the file, not the brief's
paraphrase. `compiler/src/bs_emit.erl` lines 790–795:
```
%% One `map_get`. Guard-safe by construction, which is what lets the same node
%% serve the boundary tag test above.
expr({e_proj, L, V, Field}, _C) ->
    {call, L, {remote, L, {atom, L, erlang}, {atom, L, map_get}},
     [{atom, L, Field}, {var, L, var_name(V)}]};
```
The quoted comment and the unconditional `map_get` lowering are **verbatim real**, not invented
or paraphrased.

**Optimizer-fold correction (05 → 05b)**: verified the brief's own self-correction is honest.
Disassembled the naive `mapget_probe.erl` (map built inline each iteration) myself: only **one**
`put_map_assoc` and **one** `map_get` appear in the whole module — the pattern-match path was
folded away entirely by `beam_ssa_opt`, explaining the implausible 4.9–5.1x in `05-...txt`. The
opaque-helper fix (`mapget_probe2.erl`, calling `mapget_helper:mk/1` across a module boundary)
does prevent this: I disassembled it and confirmed `put_map_assoc`/`get_map_elements`/`map_get`
all survive in all three (`via_pattern`, `via_bif`, `via_case`) variants, and none of the three
`call_ext` calls to `mapget_helper:mk/1` are folded away.

**The ~30% `map_get`-vs-`get_map_elements` gap**: reproduced. Rerunning `mapget_bench2.erl`
(the brief's exact harness) repeatedly gave `map_get` consistently 1.30–1.37x slower than the
pattern-match baseline across 10 independent runs — same order of magnitude as the brief's
~1.28–1.33x. This part of the finding is solid and did not require any correction.

**The `case`-lowering spike (claimed 1.00–1.01x) — genuinely fragile as measured, but the
underlying result holds under corrected methodology.** This is the most important finding in this
verification. Rerunning `mapget_bench2.erl` verbatim, 10 times, gave `via_case` at **1.09–1.21x**
relative to the pattern-match baseline, not the brief's captured 1.00–1.01x. I tracked this down:

- Reversing the impl order (`mapget_bench3.erl`: case, map_get, pattern) showed the function timed
  **first** in the sequence always came out fastest — even though `via_case` and `via_pattern`
  disassemble to functionally-identical hot paths (verified: identical instruction sequence except
  for the dead failure-branch tail, `badmatch` vs `case_end`). This is a genuine order-dependent
  warm-up artifact in the single-process, no-warm-up, sequential-`timer:tc` benchmark design that
  `mapget_bench2.erl` shares with `bench.erl`/`shape_bench.erl`.
- Running each impl in a **fresh spawned process per timed call** (`mapget_bench4.erl`, same
  fix the repo's own `aoc/bench/README.md` documents needing for the `fib` benchmark's GC-bleed
  problem) removed the artifact: `via_case` reliably matched `via_pattern` at 1.00x, `map_get`
  reliably ~1.18–1.19x slower, across 3 runs.
- A cheaper fix — one warm-up call plus `erlang:garbage_collect()` before each impl's timed loop,
  keeping the original single-process sequential design (`mapget_bench5.erl`) — also removed the
  artifact: `via_case` at 1.00–1.01x (matching the brief's number), `map_get` at 1.26x, across 3
  runs.

So: the **qualitative** conclusion — `case`-with-map-pattern lowering matches native
pattern-match speed, `map_get` does not — replicates under corrected methodology and I verified it
independently by two different routes. But the brief's own harness, run exactly as captured, does
**not** reliably reproduce the specific 1.00–1.01x number; it reproduces 1.09–1.21x more often
than not in my hands, and the brief's captured "four runs" of `06-mapget-alt-lowering-otp25.txt`
appear to have avoided the artifact by chance of ordering (or by some environmental difference I
could not identify) rather than by a methodology that controls for it. **This is a real weakness
in the brief's stated confidence for this one number**, not a fabrication — the direction and
rough magnitude are real, but "1.00–1.01x, four runs" overstates how repeatable that exact figure
is with the harness as written.

The realistic-workload confirmation (`ShapeBench`, §4 above) does **not** show this fragility —
reversing its impl order made no difference — so the central records/dispatch finding does not
depend on the fragile number.

**I also checked whether this order-sensitivity affects the tight-loop non-reproduction (§1)**:
reran with beam-sharp timed first — no change, still 1.00–1.03x. The artifact appears specific to
comparing near-identical-cost implementations against each other in one process without a
warm-up step, not a general property of every benchmark in this investigation.

### 6. Spiked fix closes the gap — CONFIRMED (mechanism), FLAGGED (specific number, see §5)

Same evidence as §5. The `case M of #{'R' := V} -> V end` lowering does close the gap to
approximately native pattern-match speed under methodology that controls for the order artifact
(1.00x fresh-process, 1.00–1.01x warm-up+GC). Under the brief's own harness run cold and repeated,
it lands anywhere from 1.00x to 1.21x depending on run — so "closes the gap" is correct, but the
tight "1.00–1.01x, four runs" claim of precision/repeatability is not fully earned by the harness
as built.

## Circularity / cherry-picking hunt

- **Hand-tuned source, checked**: `git status --short compiler/src/ aoc/bench/` was clean; I built
  every beam-sharp artifact (`Day01`, `ShapeBench`) from the exact checked-in `.bs` files through a
  freshly-escriptized `bsc` from a clean `compiler/src/`, not from any cached or brief-supplied
  `.beam`. The byte-identical-disassembly result (§2) is not an artifact of a hand-tuned source —
  I never touched `bench_bs.bs` and got the same identity result the brief did.
- **Order/warm-up bias, found and precisely located**: see §5/§6. This is real and I would not
  have found it without deliberately reversing impl order and trying alternate process/GC
  discipline, as the task asked. It affects the *isolated microbenchmark's* exact number, not the
  ShapeBench workload or the tight-loop non-reproduction.
- **Disadvantaging `map_get` by construction, checked and ruled out**: all three variants in
  `mapget_probe2.erl` (`via_pattern`, `via_bif`, `via_case`) call the identical opaque helper
  `mapget_helper:mk/1`, build the identical map, and do the identical `Acc + Field` accumulation —
  I read the source and disassembly line by line; there is no extra allocation, no extra work, on
  any one path relative to the others. The `map_get` slowdown is not a construction bias.
  `ShapeBench`'s `Area` was also independently disassembled by me from a fresh build and shows the
  same shape (`map_get` after tag dispatch vs. `get_map_elements` for both), so the mechanism is
  not an artifact of the isolated benchmark's specific shape either — it shows up in a realistic
  program built independently of the microbenchmark.
- **Git-history squashing caveat, checked and confirmed accurate**: the brief flags that repo
  history "appears to be periodically squashed/rebased" and can't be trusted to show the real diff
  since ticket 39 was filed. I confirmed this directly: `git log --oneline -- compiler/src/bs_emit.erl
  aoc/bench/` shows exactly 3 commits since 2026-08-15 (the brief said "two," a minor
  undercount), one of which (`f01d859`, 2026-08-31) adds `bs_emit.erl` as a 1598-line whole-file
  insertion and `aoc/bench/` as if newly created — consistent with the brief's squash-history
  suspicion, not contradicting it. The other two (`728f439`, `5f37397`, both today) touch
  `bs_emit.erl` for List/Map-type features unrelated to `e_proj` or numeric narrowing — I grepped
  their diffs for `e_proj|map_get|get_map_elements` and found nothing, confirming the brief's "does
  not read as a type-narrowing change" characterization is accurate despite the minor 2-vs-3 count
  error.
- **No other rigging found.** I did not find evidence of a wrong iteration count, a folded-away
  comparison (beyond the one the brief itself caught and fixed, 05→05b, which I independently
  verified was a real fold via disassembly), or a benchmark structured to disadvantage one side
  through extraneous work.

## "What I could not verify" section — honesty check

- **OTP 28 unavailability**: accurate. This sandbox has only OTP 25.3.2 (`erlang:system_info(otp_release)`
  → `"25"`); no `mise`/`asdf` on `PATH`.
- **Gleam unavailability**: accurate, confirmed (`apt-cache search gleam` returns nothing here).
- **Git-history squashing risk**: accurate and, per above, slightly undercounted (3 touches, not
  2) but the substantive claim ("neither reads as a type-narrowing change") holds under my own
  check of the diffs.
- **Whether the field-projection fix matters for a real (non-synthetic) beam-sharp program**:
  reasonable as stated. I grepped for `record` usage across the repo and found records in several
  exemplars (`25a`–`25e`, `Shop`, `Queue`, `Label`, `Intake`, `Parcel`) but did not find, and did
  not attempt to construct, a records-and-projection-**dominated** tight loop among them the way
  `ShapeBench.bs` deliberately is — so this caveat is honestly stated, not underclaimed.
  I did not independently re-derive this list beyond a repo-wide grep (a few minutes, not
  exhaustive), so I'd rate this one "plausible, lightly checked" rather than fully verified.
  **What the "what I could not verify" section does *not* mention, and should**: the order/warm-up
  fragility of the isolated `map_get`-vs-`case` measurement (§5). That is a real limitation this
  investigation ran into and did not flag — the brief presents `06-mapget-alt-lowering-otp25.txt`'s
  four captured runs as settled evidence for "1.00–1.01x" without noting that the harness used to
  produce it is order-sensitive when rerun. That omission is the one place I'd call the "what I
  could not verify" section incomplete rather than dishonest — nothing in it is false, but it
  understates how fragile one specific headline number is.

## Overall confidence: MEDIUM-HIGH

The brief's two most surprising claims — non-reproduction of the 20% tight-loop gap on OTP 25, and
the new `map_get`-vs-`get_map_elements` mechanism as a genuine, present-tense cost — both hold up
under fully independent re-derivation: fresh build from unmodified source through a freshly-built
`bsc`, my own disassembly script, my own benchmark reruns (including order-reversed and
alternate-methodology variants the brief did not try). The causal annotation-stripping test and the
strip_tr correctness both check out exactly as described. The two things keeping this out of HIGH:

1. **The `case`-lowering spike's headline number (1.00–1.01x) is not robust to a plain rerun of the
   brief's own harness** — I got 1.09–1.21x more often than not across 10 reruns, and traced this to
   a real order/warm-up artifact in the single-process sequential-`timer:tc` design shared by
   several of this investigation's benchmarks. The qualitative conclusion survives (confirmed by
   two independent corrected methodologies), and it does not undermine the `ShapeBench`
   realistic-workload result (which is order-insensitive), but the brief states "four runs" of a
   number that turns out to be one of the more fragile measurements in the whole investigation,
   without flagging that fragility.
2. The "Loop/Pick are instruction-identical" claim in §4 of the brief is not quite accurate for
   `Loop` (extra `{tr,...}` annotations on beam-sharp's side) — minor, doesn't change the
   conclusion, but is a small factual overstatement in a document whose whole value proposition is
   disassembly-verified precision.

Neither issue changes the recommendation-relevant substance: the tight-loop gap genuinely doesn't
reproduce here, and the field-projection `map_get` cost is genuinely real, present, and mechanically
understood. But a reader relying on this brief's exact percentages for the spike fix should know the
1.00–1.01x figure is the least repeatable number in the document.
