# Verification of decision brief 59 (boundary guard scope)

Verifier: independent agent. OTP 25 (JIT, 4 vCPU, noisy), Gleam 1.12.0, Elixir 1.14.0. Clean copy in
`/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/verify-59/` (originals untouched).
bsc was not built; "bsc emits X" is checked only by reading `compiler/src/bs_emit.erl`.

## 1. Probe table

| Probe | Reproduced? | Circularity flag | Citations checked |
|---|---|---|---|
| P1 bytes (tag +12, is_integer +5, pattern +18, flat N=1/5/20) | YES. Code chunk 80/92/98, 81/86 identical. Whole-.beam sizes differ by 12 B (788 vs 800) because CInf stores the source path; brief's "+44 unstripped" is the *delta*, which reproduces | none for bytes. See flag F-flags below: I re-ran with bsc's real options and got the same +12 / +5 / +18 | 26 line 302/381 "+14 B flat" OK; 18 line 438 "+3-5" OK |
| P2 runtime (tag +5.3 ns min; remote equal; noise ctl) | YES. Re-run min: unguarded 11.46/11.31, guarded 16.28 local (+4.9), 17.23 remote (+5.5). Medians 12.0/12.3 vs 16.9. Noise ctl u1 vs u2 0.15. 25 repeats/row | suspect (mild): see 3 | beam_asm.erl:115-120 and beam_dict.erl:103-117 verified verbatim in OTP 25 source (line numbers match the OTP 25 tree here; not checked against other OTP versions) |
| P2 is_integer runtime | YES, 8.77-8.92 across all three | suspect (mild): body `O+1` can get cheaper once the type is known, which could offset the guard. My control with body `erlang:size({O})` (no benefit from the guard): ctl 8.27/8.40, guarded 8.58 (+0.2, inside noise). So "free" survives | 18 line 438 "below resolution" OK |
| P2b chain (none 11.7, exported-only 17.9, every-fn 23.7, pattern 14.8) | YES: 11.68/11.86, 17.77, 23.62; pattern 14.9 | none | - |
| P2c erlc elision (int elided only if every caller proves; tag never) | YES, all 14 rows identical, incl. `+inline` | none for the claim. The claim is about erlc, not bsc, and is labelled so. Negative controls (b, c, e) do exercise the same path as the positives | - |
| P3 forgery (B, C, D reach private fn; limit row) | YES, all rows identical | see section 2: model is faithful on the shape; no missing guard found | bs_emit.erl 274-289, 590 OK; 1079-1090 (`fun Name/Arity`, no wrapper) OK |
| P3 fun | YES | none (see section 2, D) | - |
| P4 Gleam | YES. Regenerated probe.erl is byte-identical to `probe_generated.erl`; outputs identical. Public and private emitted the same shape, no guards | weak analogy only: Gleam has no implicit guards to scope | 18 line 125 "1.18.1" OK |
| P4 Elixir | YES, outputs identical | weak analogy: the Elixir check is the user's explicit pattern, so it cannot inform an implicit-guard scope rule. The brief says "behavioural only" | - |
| Corpus (8 priv / 19 pub record sigs; 66 / 130 sigs; 75 files; 12 private bare-int) | YES, same numbers | heuristic: record-name list includes names that may not all be records (Tag, Line, Route, State). Count is an upper bound | - |

## 2. Circularity hunt

**Model vs `bs_emit`.** I read `guard_one/8` (274-289), `record_tag/2` (508), `tag_test/3` (590), `clause/4` and the fun-reference emitter (1079-1090).
- Shape match: tag guard is `erlang:map_get('Kind', X) == Tag` as a clause-head guard (the `e_op '=='` becomes `is_eq_exact`). The model is the same strength as the real guard. The real guard is skipped only when the pattern already constrains `Kind` (`constrains_kind`), and `record_tag/2` requires a single closed record type, so a `list<Order>` or `term` parameter gets nothing. This agrees with the model (B has no guard on the element).
- `tag_test` is called from `guard_one` only. I grepped `record_tag(`: the other uses are pattern desugaring (541) and record construction (1103). Nothing else emits a tag test, so the model did not omit a guard bsc really emits on elements, fields or funs.
- D: `expr({e_fname...})` emits `fun total/1` directly. No wrapper, no guard. The model `fun tot_ng/1` is faithful. The brief's remaining doubt, whether B# lets a *public* function return a private function name as `fun<Order,int>`, is real: F46 (`compiler/features/F46-function-as-a-value.md`) and ticket 75 line 305 only say private names are valid lambda targets. I did not find a worked example of a private function escaping. D stays "unverified in B#".
- C depends on the 46 §4 projection guard being unbuilt; F24 §5 says so. OK.
- B depends on the exported function not guarding collection elements: 46 lines 117-119 and 213-221 confirm the refusal.

**Soft spots found:**
1. **Only forged values were sent, never an "A under every-function" row.** The brief's table gives "same" for A in both columns. The model for A under every-function is not run in P3. Trivially true, but not shown.
2. The D control ("valid via fun") runs only on the exported-only variant. Minor.
3. **Attribution error.** The brief says "F24 §2 says so itself" about the two tests answering one "did anyone check?" question. F24 §2 does not say that; §2 says "Exported only, by 18 §4" and §3 describes the asymmetry. Unsupported attribution (harmless to the argument, wrong as a citation).
4. P3 uses the wrong-identity AND wrong-payload term. Forged identity with a *valid* payload type would show the harm less starkly (a private `Total` would return the wrong record's int, still silent). The brief does state the payload limit.

**Negative controls.** They run the same code path with valid input and pass under every policy; the `function_clause` at A shows the guard does fire where present. Good.

**Flags (task item 3).** bsc builds with `compile:file(Abstr, [from_abstr, debug_info, {outdir,D}, report_errors, report_warnings])` (`compiler/src/bsc.erl:843`). No `+inline`, no optimisation flag. The brief's probes use default erlc (P1 adds `no_line_info`). bsc forms carry real source lines and `file` attributes (`bs_emit.erl:64-69`; `?A` = 0 only on module-level attributes). I rebuilt the five P1 variants through `from_abstr` + `debug_info` with real line annotations: Code = 73 / 85 / 91 / 74 / 79 for none / tag / pattern / int-ctl / int. Deltas **+12, +18, +5**, identical to the brief. One trap I hit and the brief did not: if every annotation is line 0, erlc emits an extra out-of-line `-inlined-total/1-` stub and the guard costs +29 B. bsc does not do that (clause lines are real), but a clause synthesised with line 0 would.

## 3. Re-measured numbers

- Bytes: +12 (tag, guard form), +18 (tag, pattern form), +5 (is_integer), flat in N. Ticket 26's +14 is not reproduced here (+2 off); 18's +13 is a different construct (tuple discriminator). The brief states "+12 here". Fine.
- ns/call (R = 25, N = 20M): tag test +4.9 to +5.5 ns on a ~11.4 ns/iteration baseline = **~43-48%**, but that baseline is a bare loop of call + `map_get` + add, so the percentage is an upper bound for a real function. Quote the absolute number.
- The loop is not optimised away: `total/1` is a real local call (`{call,1,{f,2}}` in the .S), module-external bench, result accumulated. Call overhead is in both arms, so it cancels in the difference.
- **New, not in the brief:** "flat in field count" is true for bytes only. With a 61-key record (hash map, not flatmap) my loop measured unguarded min 20.5 ns, guarded 35.8 ns (**+15 ns**), vs +5.4 at 2 keys. Records over 32 fields would pay roughly 3x. Rare, but it qualifies the cost side of the argument.
- OTP 25 only; the brief's remark that "OTP 26+ changed map-guard code generation" is not something I verified.

## 4. Citation spot-check

| Citation | Status |
|---|---|
| `bs_emit.erl` 274-289, 276, 283, 590 | exact |
| `bs_emit.erl:181` `IntOnly` | exact |
| "comment at 172-176" | **wrong**: the comment is lines 176-180 (172-176 is the `strip_rels` note). Also the brief's sentence there is garbled ("172-176 comment: ...") |
| ticket 59 text, 46 §4, 11 O(n) refusal, 18 lines 125/408/438-441/599-614, F24 §3/§5/§6, F24.6, F3.9, 26 +14, 75 line 305, 40 amendment | all found where stated |
| "F24 §2 says so itself" | not supported (see above) |
| MEASURED-HERE / RECORDED labels | consistent. P3's model is correctly labelled "Erlang model, not bsc output" |

## 5. Independent probe of the load-bearing claim

`/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/verify-59/indep/indep.escript`. I wrote a small generator that applies `guard_one`'s rule (tag test on a record-typed param, scope = exported-only vs every function) to abstract forms, compiled with bsc's real options, with one private `total(Order)` reached from 8 exported shapes. The forged term is sent by a different process for the mailbox case.

| path to private `total` | exported-only | every function |
|---|---|---|
| depth 0 (param is the record) | function_clause | function_clause |
| element of a list | **returns `<<"free">>`** | function_clause |
| tuple element | **returns** | function_clause |
| field of a guarded record | **returns** | function_clause |
| value of a map argument | **returns** | function_clause |
| `fun total/1` escaping | **returns** | function_clause |
| term received in a mailbox | **returns** | function_clause |
| exported guarded callee | function_clause | function_clause |

Valid input returns 42 on every path under both policies. This **agrees** with the brief, and adds three paths (tuple element, map value, mailbox). Wording caveat: the experiment shows the guard on the *private callee* is what closes depth >= 1, so "depth, not exported vs private" is a framing, not a finding. The data say: scope of the *callee's* guard matters exactly where the value arrives from depth >= 1. My probe, like P3, encodes `bs_emit`'s rule rather than running bsc, so it shares the same residual limit.

## Verdict

**Evidence holds; the brief is mostly sound, with four corrections.** Every probe reproduces (timings within noise, bytes exactly). I found no circularity that changes a conclusion: the model's tag guard matches `tag_test/3`, no other emitter path guards elements, fields or funs, and the negative controls use the same path. Corrections: (1) "F24 §2 says so itself" is unsupported; (2) the "172-176" citation should be 176-180; (3) "flat in field count" is bytes only, runtime is +15 ns on >32-key records; (4) D (a private function escaping through a public one) is still unverified in B#, and that is the only path where the brief's recommendation for keeping the private tag test rests on an unconfirmed premise, though B and C stand without it. The `Option 2` ~6 ns cost figure is OTP 25 only.
