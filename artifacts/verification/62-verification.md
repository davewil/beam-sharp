# Verification of the ticket 62 brief (outbound ABI, function-name casing)

Verifier: independent re-run, 2026-10-08. Scratch builds in `/tmp/verify62/` (`base/`, `patched/`), probe copies with hardcoded `/tmp` paths edited to point there. Nothing in `compiler/`, the brief, the probes, Linear or git was touched. OTP 25 / Elixir 1.14.0 only; no Elixir 1.19, no Gleam.

## Verdict

**PASS WITH CORRECTIONS.**

The decisive finding reproduces exactly: `:Shop."New"(1)` parses and runs on Elixir 1.14, so "`apply/3` is the only way" is false. The collision, corpus, neighbour and Dialyzer claims reproduce. The corrections are:

- the compile-time and load-time percentages are not stable across runs;
- one quotation attributed to ticket 35 is not in ticket 35;
- two line citations are off by one;
- a few phrasings are stronger than the evidence.

None of these changes the recommendation.

## Reproduced (table)

| Claim | Result on my build | Matches brief and .out? |
|---|---|---|
| Alias diff is against `compiler/src/bs_emit.erl` and applies cleanly | Applied with `build-bsc.sh` (needs an absolute patch path; a relative one fails). `diff` of the patched copy against `compiler/src/bs_emit.erl` shows only the patch hunks. 15 beams in both builds. | yes |
| p1: `:Shop."New"(1)` parses and runs; quoted, variable-module, compiled `defmodule`, capture and pipe forms run | `p1.out` is byte-identical to the committed `.out`. | yes |
| p1 control: unquoted `:Shop.New(1)` fails | `{:SYNTAX_ERROR, "unexpected ( after alias New"}`. `:Shop.new(1)` and `:shop.new(1)` parse. | yes |
| Fresh module compiled by me (own B# source: `New`, `Pay`, `ParseURL`) | `:Shop."New"(1)` gives `%{Id: 1, Kind: :"Shop.Order", Total: 0}`. `Enum.map(1..3, &:Shop."New"/1)` gives three maps. `1 \|> :Shop."New"() \|> :Shop."Pay"()` gives Total 500. `m = :Shop; m."New"(5)` works. `:Shop."ParseURL"("x")` gives 1. Unquoted `m.ParseURL("x")` is a `SyntaxError` ("unexpected ( after alias ParseURL"). | yes |
| p2: corpus is 27 of 35 modules, 94 exports, 80 names, 0 R1 collisions, 3 BIF aliases, `Band` is an operator word | Identical. The only diff is the scratch path inside one error line. | yes |
| p3: R1 collides on `XY`/`X_y`; R2 on `GetXML`/`GetXml`/`Get_Xml`, `ToJSON`/`ToJson`, `ParseURL`/`ParseUrl`, `FOO`/`Foo`, `AB`/`Ab`; R3 has no collisions | Identical. Erlang accepts BIF-named and keyword-named exports. The control with an unqualified `length/1` call is refused. Erlang `shop:and(1)` is a syntax error and `shop:'and'(1)` is ok. | yes |
| p3: Elixir parses 38 spellings | 38 `:parses` lines. This includes the `new` control, so 37 are reserved words or BIFs (the brief says "38 such spellings"). `:bifs.length([1,2,3])` gives `{:pascal_length,[1,2,3]}`, while `Kernel.length` gives 3. | yes, with a minor count nit |
| p4: alias works with the patch and is absent without it | Unpatched: `:Shop.new(1)` raises `UndefinedFunctionError`. Wrap and dup: `{:ok, ...}`. `import :Shop, only: [new: 1]` works with the patch and raises `CompileError` without it. 16 author entries and 19 exports in total. `nonexistent_alias` raises everywhere. | yes |
| p4: stack traces | Wrap build: `examples/Shop/shop.bs:18: :Shop.which(...)` for the alias route. Dup build: also `:Shop.which`. | **see Mismatches 3** |
| p5: Enum 76 names, 4 `?`, 1 `!`; OTP 25 has 1118 beams, 37,611 names, 5 upper-initial exports (all `wx`), 19,072 with any uppercase letter; the scan control lists `'New'` and `'_x'` | Identical. | yes (one wording nit, Overstatements 5) |
| p7: Dialyzer with spec gives the same warning as the original; with no spec the warning is weaker; unpatched build says "missing or unexported function 'Shop':new/1" | Identical, apart from timing lines. | yes |
| Ticket 32 decision text | Quoted sentence confirmed (see Mismatches 1). | yes |
| Gleam statements are all labelled unverified | Yes: stale premises 2 and 3, and section 7. | yes |
| Real-corpus collisions (see below) | R1 and R2 give 0 collisions on 275 real names. | yes ("constructed" is accurate) |

### (d) Collisions on real code, independent run

I pulled every `public ... Name(` from all `.bs` under `compiler/examples` (100 names), from `LANGUAGE.md` (114), and from `compiler/features`, `wayfinder` and `docs` (210). The union is 275 distinct names. R1 and R2 are the brief's own functions, copied into `/tmp/verify62/rules.erl`.

```
== all
names: 275
R1 collisions: []
R2 collisions: []
names with digit/underscore or 2+ consecutive capitals: []
R1/R2 differ: []
```

So no collision occurs in real code. The brief says the pair was constructed, and that is accurate. A consequence the brief does not state: no real name has an acronym, so R1 and R2 give identical output everywhere. The corpus gives no evidence for either rule. The brief does say the corpus "cannot discriminate".

R1 has a second collision the brief did not list: `AB` and `A_b` both give `a_b`. This is the same class as `XY`/`X_y`. It is also constructed.

### (e) Cost numbers, three independent runs of `p6-measure.sh` (the author's run, my run A, my run B)

| Metric | Author | Run A | Run B | Brief states |
|---|---|---|---|---|
| 200 fns, compile median, none | 297.8 | 261.8 | 253.4 | |
| 200 fns, compile median, wrap | 413.1 | 398.7 | 350.6 | |
| 200 fns, wrap compile delta | +39% | +52% | +38% | "roughly 39%" |
| 200 fns, dup compile delta | +117% | +140% | +122% | |
| 200 fns, load median, none / wrap | 2522 / 3129 | 2692 / 2974 | 2381 / 2825 | "+24%, ranges 2824-4726 vs 2410-2992" |
| 200 fns, wrap load delta | +24% | +10% | +19% | |
| 200 fns, dup load delta | +94% | +40% | +63% | not stated in the brief |
| 5 fns, wrap load delta | +3% | -5% | -5% | "inside the spread" (true) |
| 200 fns, beam bytes none / wrap / dup | 38980 / 49476 / 60008 | 38784 / 49280 / 59808 | same | "+27% / +54%" |
| Call ns, direct vs wrap alias | 17.7 / 18.9 | 17.1 / 18.5 | 17.2 / 18.0 | "below noise" |

- **Beam bytes:** reproduce (+27% and +54%, within 0.2 points). Absolute bytes are about 180 lower on my build because the embedded source path is shorter, so the byte counts are path-dependent.
- **Compile:** the sign and rough size hold, but 38 to 52% across three runs is not "roughly 39%".
- **Load:** in run A the wrap and none ranges at 200 functions overlap (2776-4754 vs 2054-3564), which contradicts the brief's "ranges do not overlap". The load percentage is in the 10 to 24% band, not 24%.
- **Compile split:** I timed the Erlang step alone, with `compile:file(Syn200.abstr, [from_abstr, binary])`:

  | Variant | Erlang step only (median ms) | Compile total in run A |
  |---|---|---|
  | none | 181.7 | 261.8 |
  | wrap | 255.2 (+40%) | 398.7 |
  | dup | 421.8 (+132%) | 629.6 |

  The compile delta is therefore mostly the Erlang compiler handling twice the functions. The author's admission that front-end and `erlc` are mixed is correct. The B# front-end plus abstract-format printing and parsing also grew, by about 80 ms to about 143 ms. I did not isolate which part of that growth is the patch's `alias_post`.

## Mismatches

1. **Ticket 32 quote (b).** The brief's attribution is accurate: `32-ffi-surface.md:344`, in `## Decisions entry`, reads "**There is no snake_case⇄PascalCase rule anywhere in the language**". Line 204 says it again in the Answer, under "### 3. Naming". The context is the inbound declaration, "Both spellings are written: the Erlang atom in quotes, the beam-sharp name in the declaration", and the reasons given (`'PKCS-1'`, `fetch!`, `&&&` cannot be spelled) are inbound reasons. The brief's reading is fair: the wording is universal ("anywhere in the language"), but the reasoning does not reach a derived outbound alias. Two places in the brief pull in opposite directions:
   - **§2.5** says the inbound reason "does not apply outbound".
   - **Option C** says it "contradicts a settled decision".
   One of these should be softened. The repo also has `compiler/src/bs_otp.erl:7-8` ("A snake_case<->PascalCase derivation cannot spell 'PKCS-1' ... so the language has no such rule"), a compiler comment the brief does not cite. It stands in the way of Option C more directly than the parser comment does.
2. **Ticket 35 misquote.** The brief puts "so it is not a naming rule by another route" in quotation marks. That string does not appear in any ticket or source file (`grep` over `wayfinder/` and `compiler/src` finds nothing). Ticket 35 line 44 says "which is a naming rule by another route" (the Question's worry). Line 94 says it is "answered by scoping rather than waved away". The brief's "by mechanism rather than preference" is also not verbatim: ticket 35:237 says "answers itself on *mechanism* rather than preference", and the exact phrase "by mechanism rather than preference" is in ticket 41, not 35. The substance is right, and the quotes are wrong.
3. **Stack-trace claim (p4).** The brief says a wrapper alias "leaves no frame" and a dup alias "shows `:Shop.which(...)`... so one source function reports under two names depending on route". My run shows both the wrap and dup builds report `examples/Shop/shop.bs:18: :Shop.which(...)` for the alias route (identical to the author's `.out`), while the PascalCase route reports `:Shop."Which"(...)`. So in the wrap build the trace names the alias, not the PascalCase function. This contradicts the brief's first sentence. The brief's second sentence (two names by route) holds for both builds. The wrapper's tail call is not visible. The reported frame is the alias, so it does not hide it either. The brief's wording should say the alias name appears.
4. **Corpus (§4 "Corpus").** The brief says of the 8 failures "unclear how many are scratch-build artefacts". `compiler/examples/exemplars/README.md` says "None of these compile today", so the 7 exemplar failures are expected in the real compiler too, not artefacts. Only `Signalbox` (`internal error in pass core: bad argument`) is possibly OTP-25-specific. `compiler/features/README.md` F67 refers to Signalbox as a live example with a diagnostic, so the real compiler probably handles it. I could not tell why it crashes here. The corpus is effectively 27 of 28 real modules.

## Circularity flags

- **`lib.sh` and the vacuity guard.** None of the 62 probes sources `lib.sh`. The 62 probes use `common.sh`, which defines its own `bsc()` and `build_shop()`. `grep -c 'probe '` on `probes/62/*.sh` is 0. The guard is used by probes 52, 57 and 59, not by 62. `build_shop` prints compiler errors through `head -5` but never fails. A missing or broken build is not treated as success, because the downstream Elixir step then crashes visibly or the paired positive case shows `UndefinedFunctionError`. So the 62 results are not vacuous. The statement that a vacuity guard "was added to lib.sh" does not bear on the 62 probes.
- **Controls that are weak on their own.** `:Shop.nonexistent_alias(1)` raising `UndefinedFunctionError` would also happen if the whole module were missing. It is only meaningful next to the `{:ok, ...}` for `:Shop.new(1)` in the same run, and it sits next to it. Likewise, the unpatched `:Shop.new(1)` raising `UndefinedFunctionError` is only informative because `:Shop."New"(1)` is `{:ok, ...}` in the same output. The paired structure holds in all of p1, p4 and p7.
- **Is the alias patch tautological?** Partly. `alias_post` writes `new(X) -> 'New'(X)`, and p4 then calls `new`. That the call works from Elixir is a property of BEAM exports, not a test of a design. The unpatched control can fail and does fail, so the probe is not unfalsifiable. It shows feasibility and cost, not that a derived alias is a good idea. The brief calls it a prototype, so the claim is correctly scoped.
- **p3 collision tables.** The R1 `XY`/`X_y` pair and the R2 pairs were authored into `names()`. The collision "finds" are therefore constructions, and the brief says so. The R2 collisions (`ToJSON`/`ToJson`) are collisions by definition of the rule, not discoveries. "Ordinary pairs" (Overstatements 3) is a judgement the probe does not support.
- **Expected values adjusted?** I found no sign that expected values were changed to fit. The author's `.out` files match my runs everywhere except paths, timings and the 180-byte path difference. The brief records one honest correction (the call-overhead control label).
- **Measurement design.** The load test runs 40 loads in the same VM after purge and takes the 20th sorted value. That is a warm-load figure, not a cold start. The call-overhead test has no slower-path control (the brief admits this). The wrapper adds one local call, and the median is higher in all three runs (+1.2, +1.4 and +0.8 ns).

## Citation errors

| Cited | Actual |
|---|---|
| `10-atoms-in-a-csharp-skin.md:333-335` | The sentence "Fieldless variants compile to atoms ... The constructor *is* the declaration site." runs from line 334 to line 336. The brief's range is off by one. The content is quoted correctly. |
| `bs_lexer.xrl:150` | Correct (`{UPPER}{ALNUM}*`). Note that `ALNUM` (line 16) includes `_`, which is why `X_y` is a legal name. |
| `parser.yrl:167-169` | The text is at lines 167-169, and "no case mapping exists" is on line 169. Correct. |
| `32a_gleam_external.gleam:4`, `18c_gleam_ffi_trust.gleam:44`, `10c_gleam_forge.erl` | Correct (`pub fn key_find` at 4, `pub fn lookup` at 44, `gleamprobe:describe(red)` at 26, `area({circle, 2.0})` at 29-30). |
| `62a_from_the_outside.sh` section 4 | Correct (line 123, self-skips with "SKIPPED — no gleam on PATH"). |
| `LANGUAGE.md` §12 lines 3188-3191 | Correct (the `apply(:Shop, :New, [1])    # the way in` line is inside that range). |
| Ticket 87 / ENG-398 | Correct (`bs@type_atoms`, `bs_emit.erl:74,1481`). |
| Ticket 35 "so it is not a naming rule by another route" | Not found (Mismatches 2). |
| Ticket 35 "by mechanism rather than preference" | The verbatim phrase is in ticket 41; ticket 35:237 has the near variant (Mismatches 2). |
| Ticket 26 casing rule, ticket 32 §2 | Ticket 32 line 197 refers to "Ticket 26's casing rule". Correct. |
| `bs_otp:callbacks/1`, `callback_name/3` | Correct (exported at `bs_otp.erl:20`). |

## Overstatements

1. **"`apply/3` is the only way" attributed to ticket 62 and `LANGUAGE.md`.** Ticket 62 candidate 1 says "Elixir callers use `apply/3`", and `LANGUAGE.md` calls it "the way in". Neither text says "only". The ticket's heading "Elixir cannot call a PascalCase export" is literally false for the quoted form. The brief's "present `apply/3` as the only route" is a fair reading of the heading plus the examples, but stronger than the sentences.
2. **Version safety (a).** The brief correctly flags that Elixir 1.19 was not tested. But "the quoted-call form is old syntax" is an unmeasured assertion, and "the repo's claim being contradicted" overreaches slightly, because the ticket measured the unquoted forms on 1.19.5 and those results are unaffected. It is a labelled gap and is not presented as a measurement. The "re-run p1 on Elixir 1.19" next step is right. Ticket 62's SYNTAX_ERROR rows all use the unquoted form, so there is no direct measured contradiction of any 1.19.5 result.
3. **R2 collides on "ordinary pairs".** In real code (275 names) it collides on none. The pairs are `GetXML`/`GetXml`, `FOO`/`Foo`. A module with both is contrived. "Ordinary" should read "natural-looking but not found in the corpus".
4. **Cost precision.** "Roughly 39%" compile, "about 24%" load with "ranges 2824-4726 vs 2410-2992 do not overlap", and call overhead "17.7 ns (16.7-21.1)" are given with more precision than three runs support: 38 to 52% compile, 10 to 24% load, and run-A load ranges that overlap. Tiny absolute figures (705 us, 17.7 ns) are machine-specific. The direction (the cost scales with function count, and dup costs about twice wrap) is solid.
5. **"Another 19,072 contain an uppercase letter inside".** The 19,072 is the count of exports containing any uppercase letter. It includes the 5 upper-initial ones, so "another" is slightly wrong and the figure is a superset.
6. **"The correct call is silent in every variant"** is true for the alias builds. The unpatched control reports the alias as missing, which is by design.
7. **`G` framing and the recommendation.** These are judgement, not measured, and are fairly labelled. Option C's "contradicts a settled decision" is stated as fact in the "strongest counterargument" while §2.5 argues the reason does not apply (Mismatches 1).
