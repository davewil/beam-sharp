# Verification of the ticket 62 decision brief

Verifier run, 2026-10-30. Environment: OTP 25 (stdlib 4.3.1.3), Elixir 1.14.0, rebar3. No bsc, no gleam, nothing downloaded.
Probes were run from a copy at `/tmp/v62/probes` (fresh dir). Mutations in `/tmp/v62/mut`. Own one-liners in `/tmp/v62/own`. The brief and the probes were not edited.

## Verdict

**The headline and the main measurements hold. The brief is usable, with these corrections:**

1. Four load-time figures in brief.md match none of the saved `.out` files (they sit inside the observed run-to-run range).
2. Probe p7's "exit 1 on unexpected" never fires. It prints `UNEXPECTED` and exits 0.
3. Probe p6 greps `bad_alias`, which also matches `bad_alias2`, so its OBSERVED line is not independent.
4. Claim 6 and claim 9 are true by construction of the stand-in. They show nothing about bsc.
5. The corpus census (p3) misses at least two names, because its regex rejects `(`-initial return types.
6. The SyntaxError text the brief quotes is not Elixir 1.14's text.

Nothing was found to be fabricated, and no probe hard-codes the headline result.

## Task 1: independent re-run (`bash run_all.sh` from the copy; every probe exited 0)

| Probe | Result vs saved `.out` |
|---|---|
| p1_elixir_call_syntax | identical |
| p1_mutation_must_fail.out | not produced by run_all.sh. I reproduced the mutation myself (see Task 2): exit 1 |
| p2_elixir_compiled_and_format | identical |
| p2b_field_access | identical |
| p3_derivation_census | identical |
| p4_alias_collisions | identical |
| p5_measure | sizes, atoms and code-memory identical. `load_us` differs by noise (see 2b) |
| p6_dialyzer_alias_spec | differs only in the PLT temp path and the elapsed time |
| p7_runtime_stack | trace results identical. Timings differ: 123,936 / 135,417 / 134,716 us vs the saved 127,554 / 114,820 / 136,641, so the order flipped. The brief already says no claim is made |
| p8_ecosystem_census | identical |

## Task 2: circularity audit and mutations

### (a) Headline: `:Shop."New"(1)` works, `:Shop.New(1)` is a SyntaxError — PASS, confirmed with my own code

- **Beam construction.** The probe `Shop.beam` is a hand-written `src/Shop.erl`, compiled with `erlc` (version 8.2.6.3). It is not bsc output.
  - It is a real Erlang-compiled beam exporting `'New'/1`, `'Pay'/1`, `'Which'/1` and `'bs@type_atoms'/0`.
  - It also exports hand-written `new/1`, `pay/1` and `which/1`.
  - The map shape (`Kind`, `Id`, `Total`) matches what `wayfinder/prototypes/62a_from_the_outside.sh:59,102-114` expects, and the module is named `Shop` as in `compiler/examples/Shop/shop.bs`.
  - It is faithful in shape. It is not faithful in content: `shop.bs` also has `Amount`, `Band`, `Total`, `Squared` and `Bump`.
- **My own beam.** I wrote a separate `Foo.erl` (exports `'New'/1` and `'Pay'/1`), compiled it with `erlc`, and used `elixir -pa` with no author harness.
  - `elixir -e ':Foo.New(1)'` gives `SyntaxError: unexpected ( after alias New. Function names and identifiers in Elixir start with lowercase...`.
  - `:Foo."New"(1)` returns `%{Id: 1}`.
  - `1 |> :Foo."New"() |> :Foo."Pay"()` returns `%{Id: 1, Paid: true}`.
  - `(&:Foo."New"/1).(2)` returns `%{Id: 2}`.
  - A compiled `.exs` module using `:Foo."New"(x)` returns `%{Id: 3}`.
  - The same `.exs` with the unquoted form is a SyntaxError.
  - `:Foo."Nope"(1)` raises `UndefinedFunctionError`, so the quoted form is a real call.
- **Assertions.** p1's assertions never assert that `:Shop.New(1)` is a syntax error or that the quoted form is ok. They assert that `apply/3` returns a map, that the NoSuch controls are not ok, and that any ok New-spelling equals the `apply` result. The headline lines are printed from observation, not hard-coded. p2 does assert quoted-call results in compiled code.
- **Mutations.**
  - Renaming `'New'` to `'NewX'` in a Shop copy: p1 exits 1 (FAIL on harness sanity and on equality). This reproduces `p1_mutation_must_fail.out`.
  - Shop returning `Total => 1`: p2 exits 1.
  - Caller using unquoted `:Shop.New`: p2 exits 1.
- **Claim 6.** `:Shop.new(1)` works only because the stand-in defines `new/1`. This is tautological. It shows nothing about bsc.

### (b) Size and load-time numbers

- **Sizes and atoms are deterministic.** I ran `p5_run.sh` 3 more times. All sizes, atoms and code-memory deltas were identical across runs.
  - N=100: beam 13,272 / 18,456 / 25,232 bytes (plain / tramp / dup).
  - N=1000: beam 127,756 / 183,684 / 257,356 bytes; atoms +1314 / +2314; code memory 725,880 / 1,034,072 / 1,450,072 bytes.
  - ExpT 12,040 -> 24,040; Dbgi spec delta 33,566 - 29,545 = 4,021 bytes.
  - The derived ratios in the brief are right: +55,928 B (about 56 B per alias), +129,600 B for dup (2.32x), +42% and +100% code memory, 17.3 / 11.7 = 1.48x load time.
- **Load-time variance (median of 15 fresh VMs, 4 runs including run_all).**

  | Case | Plain | Trampoline | Dup |
  |---|---|---|---|
  | N=10 (2 runs) | 421, 477 us | 429, 530 us | — |
  | N=100 | 1.03-1.10 ms | 1.26-1.45 ms | 1.69-1.82 ms |
  | N=1000 | 7.8-8.8 ms | 11.5-12.1 ms | 16.7-17.6 ms |

  N=10 was not rerun, so its range comes from the saved `.out` and the run_all run only. The ordering plain < tramp < dup held every time.
- **Misstated numbers.** The brief says "N=10 407 -> 466 us; N=100 1.14 -> 1.42 ms; N=1000 8.4 -> 11.7 ms (dup 17.3)".
  - The saved `p5_measure.out` says 477 -> 530; 1060 -> 1328; 8804 -> 11750; dup 16686.
  - So the brief's figures come from an unsaved earlier run. They are within noise of what I measured, and the conclusions are unaffected.
  - "Roughly 3 us per alias" is consistent: (11.7 - 8.4) ms / 1000 = 3.3 us.
- **Mutation.** I made `dup` a trampoline. The p5 assertion went red (`127756 < 183684 < 183684 -> false`, exit 1).
- **Caveat.** The forms are synthetic (2-clause map patterns plus specs), not bsc output. The brief says this plainly.

### (c) Collision claims — PASS for the erlc facts. Two are tautological as probes.

- **Reproduced.** Running erlc myself via the p4 harness, I got:
  - Duplicate `get_id/1`: `function get_id/1 already defined`.
  - `module_info/0`: `already defined`, with `erl_lint.erl:530` listing `{module_info,0},{module_info,1}` as reserved. Lines 1633-1637 are the `redefine_function` check. Both citations are correct.
  - Duplicate `init/1` in a gen_server module: `already defined`.
  - `arity_distinct` compiles clean.
  - Export without a definition: `function new/1 undefined`.
- **Mutations.**
  - Making the two colliding aliases distinct turned p4 red (2 ASSERT FAILs, exit 1).
  - Flipping `callback_ok` to expect an error turned it red.
- **Weakness.** `acronym_collision` and `callback_double_define` hand-write duplicate definitions, so erlc refusing them is trivially true. What the probes establish is "erlc refuses it". Whether a bsc alias pass would produce the duplicate is a code-reading claim. For `Init` that reading is correct:
  - `compiler/src/bs_otp.erl:40-49` has `{'Init',1,init,mandatory}` in the GenServer table.
  - `callback_name/3` is at lines 83-89.
  - `bs_emit.erl:117` `name/2` calls `emitted_name/3` (line 131), which uses `callback_name`. So `Init` already emits as `init`, and an alias pass keyed on the source name would collide. The brief's claim matches the source.
- **Cited line numbers.** `bs_emit.erl:76` is the export list (lines 76-77), `:117` is `name/2` and `:131-135` is `emitted_name`. All correct.

### (d) Census of uppercase-initial exports — PASS

- My own Elixir script over the same globs (`/usr/lib/erlang/lib/*/ebin` and `/usr/lib/elixir/lib/*/ebin`) found:
  - 1,669 beams and 48,523 exports.
  - 289 uppercase-initial exports, of which 270 are `MACRO-` (excluded).
  - That leaves 19 authored: `diameter_types` 14, `wxImage` 1, `wxMenu` 1, `wxRegion` 2, `wxWindow` 1. None are in `Elixir.*` modules.
  - 19 / 48,523 = 0.039%, as the brief says.
- **Framing caveat.** 14 of the 19 are in one generated module (`diameter_types`). The census covers only the installed OTP and Elixir libraries, not Hex packages.
- **Mutation.** The p8 vacuity guard (at least 1000 beams) is reasonable. I did not mutate it.

### Other probes

- **p2: PASS.** `compiler warnings: ""`, `Code.format_string!` is stable on the quoted form, and Macro.to_string prints it quoted. `defdelegate ... as: :New` works. Its assertions compare observed values to literal expected maps. That is a legitimate check, not circular.
- **p2b: PASS, with a weak assertion.** I re-ran `o.Id` independently and got `CompileError: invalid alias: "o.Id"`; `o."Id"` and `o[:Id]` return 7. The probe's exit code only requires that some spelling returns 7. The `o.Id` failure is printed, not asserted. Elixir's own error text says "wrap the function or field name in double quotes", so the quoting hint exists for fields.
- **p3: PASS.** I re-derived 106 distinct names (49 module dirs, 89 files).
  - I planted `GetID`/`GetId` in a copy of the corpus. The acronym rule reported the collision and the probe exited 1.
  - **Undercount.** The probe regex excludes `(` in the return type (`[^()=\n]*?`), so tuple-returning public functions are skipped. `public (:noreply, State) HandleInfo(...)` and `EncodeResponse` are missing from the 106. `Init`, `HandleCall` and `HandleCast` are caught only through other declarations.
  - So the corpus has at least 108 names. This does not change "no collision" but it understates the corpus. The brief says "regex, not a parse" and "multi-line signatures could be missed" but does not name this case.
- **p4:** see (c).
- **p5:** see (b). The `call_only` assertion is real: the asm output shows `{call_only,1,{f,2}}`.
- **p6: CIRCULAR in its report line, though the observation is true.**
  - `grep -q "$f"` with `f=bad_alias` also matches `bad_alias2`. I deleted `bad_alias` from `dm.erl`, and the probe still printed `OBSERVED: bad_alias -> reported`.
  - On the unmutated file, the Dialyzer text itself shows `Function bad_alias/0 has no local return` and `dm:total('not_an_int') ... differs in the 1st argument`. So the claim ("spec-less alias still rejected for an integer() argument") stands on the raw output, not on the OBSERVED line.
  - Only an `integer()` argument was probed, as the brief says.
- **p7: assertion gate broken.**
  - The trace result is real: `alias name appears in trace: trampoline=false duplicate=true`.
  - I mutated `calc/1` to do a non-tail call, which gave `trampoline=true` and printed `UNEXPECTED {true,true}`. The process still exited 0. The cause is `init:stop(1)` followed immediately by `halt()` in the `-eval`, so the original run is also rc 0.
  - A first mutation (`case ... of {A,B} -> {A,B}`) was optimized back into `call_only` by the compiler, so the trampoline claim is about compiled `call_only` output, which holds.
  - Claim 5's "p7 has internal assertions" is true in print only. run_all would not catch a regression.
- **p8:** PASS (see (d)).

## Task 3: claims table and citations

| Claim | Established? |
|---|---|
| 1, 2, 3 | Yes (p1, p2, and my own one-liners) |
| 4 | Yes. I reproduced it; the probe only prints it |
| 5 | Yes for p1/p3/p4/p5. Mutations went red. Not for p7 (exit code) or p6 (substring) |
| 6 | True but tautological, since the stand-in defines `new/1` |
| 7 | Yes. `p3` derives `get_id` for both; `p4` shows erlc refuses |
| 8 | Yes (`erl_lint.erl:530,1633-1637` read) |
| 9 | Yes with the caveat above: the erlc half is tautological, the source half is verified |
| 10 | Yes |
| 11 | Yes for sizes and atoms. Load times differ slightly from the brief's printed figures (see (b)) |
| 12 | Yes (`call_only`; absent alias frame; present dup frame) |
| 13 | Correctly disclaimed |
| 14 | Yes, on the raw Dialyzer output |
| 15 | Yes (19 / 48,523, reproduced independently) |
| 16 | 106 reproduced, but the true figure is at least 108 |
| 17, 18 | Read, not executed, and labelled as such. `bs_emit.erl:76,117,131-135` and `bs_otp.erl:40-49,83-89` are correct. `bs_lexer.xrl:150` is `{UPPER}{ALNUM}*` and `ALNUM = [a-zA-Z0-9_]` (line 16), so `_` and digits are allowed |
| 19 | Yes. `22-how-opinionated.md:89-100` says there is no attribute grammar, and the grammar alternation is `bs_parser.yrl:76-83` |
| 20 | Verified by me, see below |
| 21-26 | Honestly labelled unprobed or inherited |

### Citation spot-checks

- **`LANGUAGE.md:3324-3325`:** correct. Line 3324 is `:Shop.New(1)  # SyntaxError...`, and 3325 is `apply(:Shop, :New, [1])  # the way in`.
- **`wayfinder/prototypes/10c_gleam_atoms.gleam:74-75`:** correct. The text is "1. Fieldless variants ARE bare atoms; variants with fields are tagged tuples; PascalCase becomes snake_case."
- **Ticket 10 section 7 (line 318 heading, 334-335):** says "Fieldless variants compile to atoms, variants with fields to tagged tuples, PascalCase to snake_case. The constructor *is* the declaration site."
- **Gleam precedent: I independently confirm it is about variant constructors, not functions.** Both sources say so, and ticket 10 §7 uses it to argue that Gleam is nominal. Ticket 62 lines 116-119 reads it as "Gleam downcases when it emits to the BEAM", which is a misreading on its face. The brief's "different mechanism" claim is supported by the repo text. I could not test Gleam itself, so the brief's UNPROBED label is right. (The brief cites ticket 62 "lines 114-119"; the sentence is at 116-119.)
- **Ticket 32:** line 41 is the write-cost/read-cost constraint. Lines 44-46 are the question text ("the declaration carries both spellings (Gleam's approach)"), not the decision. The decision text is at 203-208 ("Both spellings are written ... There is no snake_case <-> PascalCase rule anywhere", 1,920 of 1,924). The brief's citation of 204-208 is right; the 44-46 citation is the question, which the brief presents as "ticket 32 chose".
- **`15-error-model.md:416-424`:** matches the Elm text.
- **Ticket 62a:** the file is `wayfinder/prototypes/62a_from_the_outside.sh`. The brief refers to it by bare name "62a", which is fine.
- **Misquote.** The brief says Elixir's error is "syntax error before: ...". Elixir 1.14.0 actually prints "unexpected ( after alias New. Function names and identifiers in Elixir start with lowercase characters or underscore". Neither message mentions quoting, so the "does not hint at it" point stands, but the quoted text is wrong for 1.14.
- **Stated as measured but unexecuted:** nothing found. The brief marks the read-only items (17, 18, 19), the inherited items (21, 25) and the unprobed items (20, 22, 23, 24, 26) as such.

## Unverified here

- Quoted-call behaviour on newer Elixir (the ticket cites 1.19.5).
- What real bsc emits.
- Gleam and Elm claims.
- Dialyzer on map-typed (record) arguments.
- Tooling above the compiler (Credo, ElixirLS, IEx autocomplete).
