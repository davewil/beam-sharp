# Verification of artifacts/39/brief.md (independent, read-only)

Method: copied the tree (minus .git, wayfinder, build) to
`/tmp/claude-0/-home-user-beam-sharp/2e35dc52-b5e4-5ac3-801c-9c12d8324568/scratchpad/verify39/repo`, rewrote the hardcoded
`/home/user/beam-sharp` paths with sed, and ran the brief's Reproduce section unmodified in order (00, gleam build, 01..17). Outputs are in
`verify39/out/`. The repo, brief, ticket and Linear were not touched. Host load average was about 15 on 4 cores during the run, which is
much noisier than the committed runs (iqr 4-5 ms here against 1 ms committed).

## 1. Probe reruns

| Probe | Result | Notes |
|---|---|---|
| 00 build bsc, gleam build | REPRODUCED | builds and runs as described |
| 01 rebench | REPRODUCED (conclusion) | my run: Erlang 11.16, Elixir 11.24, bs 11.23, Gleam 9.50, so bs 1.18x with Erlang and Elixir also 1.18x. Committed: 1.14x, 1.28x, 1.20x. The original harness does not give a stable bs gap; the variation is run to run. |
| 02 asm diff | REPRODUCED (differs only in `{line}` paths) | see 03 |
| 03 hot-diff.py | REPRODUCED, with a script weakness | prints DIFFERENT for all three, as disclosed. In my run the bs bodies also differ by `{line,...}` entries. The regex at `03-hot-diff.py:9` only strips `{line}` when it sits on one line, and longer paths make it wrap. So the script's output depends on path length. I did my own normalisation (strip line, renumber labels, drop function atoms) on the disassembled beams: wrap, hit and spin are all identical (6, 7, 22 instrs). The row-3 claim is true; the committed script cannot show it. |
| 04 shuffled | REPRODUCED | min Erlang 10.26, Elixir 10.18, bs 10.27, Gleam 8.42. bs equals Erlang and Elixir within 0.1 ms; Gleam is 18% faster here (brief: 12%) because of the load. |
| 05 order | REPRODUCED | bimodal about 9.1 / 11.5 ms again, for any implementation and any position. Same bs build three times in one process: 10.93/10.57/10.85, 9.12/9.16/11.62, 11.48/11.70/10.40. |
| 06 variants | REPRODUCED | erl 8.99, +inline 7.95 (-11.6%), +no_type_opt 8.99; bs 9.02, +inline 8.09 (-10.3%), +no_type_opt 9.11; Gleam 7.94. |
| 07 tr-count | REPRODUCED exactly | 8 `{tr,`, 11 var_info, 0/0 under no_type_opt |
| 08 carry-ranges | REPRODUCED exactly | but see C2 and C3 |
| 09 record guard | REPRODUCED | min: RecPub 36.79, RecPriv 34.10, no-guard 18.49, hand-guard 35.74 (about 1.9x). Committed 33.85/35.15/18.45/36.10. The abstr of RecPriv does carry the map_get tag test. |
| 10 public int guards | REPRODUCED within noise | 9.51 vs 9.05 min (+5%), p25 11.19 vs 11.32 (-1%). Brief says +1-2%. Sign of the effect is not stable, and "noise" is correct. |
| 11 refined range | REPRODUCED exactly | |
| 12 survey | REPRODUCED exactly | |
| 13 inline attribute | REPRODUCED | 28 instrs, 2 local calls; min bs 9.58 vs attr 8.62, p25 12.46 vs 10.46 |
| 14 inline threshold | REPRODUCED exactly | |
| 15 stacktrace | REPRODUCED exactly | |
| 16 size/time | REPRODUCED (sizes differ by absolute path length only; percentages match) | compile-time delta this run +5.5% to +144%; committed +2% to +76%. The brief's range is narrower than what I saw, but its reading ("noisy, tens of percent of a few ms") stands. Signalbox fails in bsc's own compile (`internal error in pass core`, `ModelKey/1`), as stated. |
| 17 inline100 | REPRODUCED | a 9.18, inline 8.34, {inline,100} 8.16, Erlang+inline 7.95, Gleam 8.02. The {inline,100} vs inline gap is inside the iqr (1.6-1.7 ms), so row 14 "UNVERIFIED" is correctly marked. |

Timing variance seen: min values repeat to about 0.1-0.4 ms across runs when they land in the fast mode. Medians and p25 move by 1-3 ms
with load. The shifts between runs are up to about 27% (9.0 to 11.5 ms), and the order of implementations within a run does not track
them. All ranking conclusions held under 3-4x the iqr of the committed runs.

## 2. Circularity hunt

No hardcoded expected output, no `|| true`, no stderr discard on a measured path, no patch that implements a claim before a probe detects it.
Harness order is shuffled with a fixed seed. Every sample is a fresh process with no warm-up, so the load is symmetric. Answers are
cross-checked (6770, or equal across impls) before timing. The variants in 06 and 17 differ in one option, built from the same abstr
with a module rename, so the builds are like for like. Erlang is built by erlc without debug_info and bs with it, which is a
small unlike-build gap; 06 shows no_type_opt and inline effects are the same on both, so it does not change a conclusion.

Findings:

- **C1 `13-inline-as-attribute.v1-quoting-bug`: legitimate.** v1 compiled the modified abstr fine (`compile: {ok,'Day01_attr'}`) and crashed
  only in the later disassembly eval (`unbound_var 'Day01_attr'`, a shell quoting error). v2 uses the same inserted attribute and the same
  compile options and just moves the disassembly into a module. The fix was not tuned to an outcome, and v1's benchmark table points
  the same way. Severity: none.
- **C2 Row 7 is misread (severity medium).** "A result guard does carry a range" rests on `08-carry-ranges.sh` wc/1, where the tested value
  is `((N rem 100)+100) rem 100`. The optimiser already infers `0..99` from that arithmetic, so the `< 100` test is dropped because it is
  redundant by inference. The `{tr,..,{0,99}}` on the surviving `is_ge` comes from inference, not from the guard. I tested the
  discriminating case (`case g2(N) of R when R >= 0, R < 100 -> hit(R+1)`, g2 opaque, erlc OTP 25): both tests are kept and the
  following `+` and `return` carry no `{tr}`. So on OTP 25 there is no evidence, and mild counter-evidence, that a guard carries a range.
  The brief's own caveat ("costs one test where the optimiser can't prove it") is the real reading.
- **C3 Row 6 "asm unchanged" is not shown by the .out (severity low).** `08-carry-ranges.sh:4`: the awk range for a/b/c prints only
  headers (see `08-carry-ranges.out:1-6`), so wa is never displayed beside wb. I diffed wa and wb myself: identical except label numbers. The claim is
  true; the committed evidence does not show it.
- **C4 Row 13 cause (severity low).** "The FFI result `case .. when is_integer(bs@rv0)` enlarges it" is inferred from the final asm being
  identical, plus `{inline,100}` succeeding. No probe removes the wrapper. `Day01.abstr` does contain `bs@rv0` (lines 34-39). The brief
  admits in Option C that "none was run".
- **C5 Stale comment `RecPriv/recpriv.bs:1`** says "no boundary guard is emitted for it". The probe contradicts that, which is the finding,
  so the comment is wrong rather than the probe. Low.
- **C6 Row 1 wording (severity low).** The repo's own harness gave bs 1.28x and 1.20x in 2 of 3 committed runs. "REFUTED on this host" is fair for
  the shuffled fresh-process harness and for 05, but the unshuffled in-process harness does show a gap on some runs, for bs and sometimes
  for others. "Not reproducible, noise-dominated" is the safer word than "refuted".
- **C7 Row 12 is shown on a hand-written `st.erl`, not on a bsc-emitted public function** with a failing boundary guard. The mechanism
  is the same, but the B# claim in Option B is extrapolated. Low.

## 3. Citations and numbers

- `bs_emit.erl:73-76` module and export attributes: correct. `bs_emit.erl:322-325` asymmetry comment: correct. `bs_emit.erl:267-275`
  `guard_one`: correct (the tag test is emitted regardless of `Public`). `bs_emit.erl:1241-1249` `return_guard`: correct.
  `bsc.erl:843` option list: correct.
- `aoc/bench/bench_bs.bs:8-10`: the FFI `rem` declaration is lines 7-9; `Wrap` is lines 11-12. Off by one to three lines, harmless.
- Numbers in the evidence table and Measurements match the committed .out files. "~5.8 ns per call" is from the hand-guard run
  ((36.10-18.45)/3M); RecPub gives 5.1 and RecPriv 5.6. Fine. "p25 10.46 vs 11.63" (row 11) matches `13-inline-as-attribute.out`.
- Not in the brief, and it bears on the recommendation: the ticket's own OTP 28 table has Gleam only 3% ahead of Erlang (5.13 vs 5.30 ms).
  On this OTP 25 host Gleam is 12-18% ahead. The inline gain may be much smaller on the ticket's platform. The brief flags the platform
  risk but not this specific gap.

## 4. Verdict per row

| # | Verdict | Note |
|---|---|---|
| 1 | CONFIRMED (prefer "not reproducible / noise-dominated" over "refuted") | C6 |
| 2 | CONFIRMED | bimodality reproduced |
| 3 | CONFIRMED | independently normalised; committed script cannot prove it (03 weakness) |
| 4 | CONFIRMED on OTP 25 | `{-99,99}` and `{1,199}` present in 07/03 outputs; `{0,99}` also appears in the `+inline` Spin |
| 5 | CONFIRMED | 07 and 06 reproduced |
| 6 | CONFIRMED, evidence incomplete | C3 |
| 7 | NOT CONFIRMED | C2; evidence reads inference as a guard effect, and my opaque-value test shows no range carried |
| 8 | CONFIRMED | source: `int rem` FFI returns plain `int` |
| 9 | CONFIRMED | 25 vs 26 instrs, 1 vs 3 calls, `inline` on Gleam's `.erl` line 2 |
| 10 | CONFIRMED (OTP 25) | -10% to -12% reproduced |
| 11 | CONFIRMED | compile:file with from_abstr, not `erlc` itself, but the bsc comment says they are the same function |
| 12 | CONFIRMED | hand-written example, C7 |
| 13 | CONFIRMED (mechanism inferred) | C4 |
| 14 | UNVERIFIED, correctly marked | still inside spread |
| 15 | CONFIRMED as "inside noise" | sign not stable across runs |
| 16 | CONFIRMED | about 1.9x reproduced; RecPriv carries the guard |
| 17 | CONFIRMED | |

No row is circular. Row 7 is the only one I would not accept as written.

**Recommendation B still follows** as a cheap, reversible change, on rows 9-11 alone. Its stated gain ("takes the whole measured gain",
-10%) is an OTP 25 number. The ticket's OTP 28 table suggests about 3%. The brief should say so before resolving, and should drop
row 7 from its list of support (the recommendation does not use it). Option C's rejection also stands. The brief's own re-run on the
ticket's machine remains the required gate.
