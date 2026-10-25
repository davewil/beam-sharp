# Verification of brief.md (ticket 62), independent re-run

Scratch: /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/verify62/ (fresh bsc build of Shop, fresh .abstr for all examples, fresh aliased beams).
Toolchain confirmed: OTP 29, Elixir 1.20.4, gleam 1.19.1.

## Circularity flags (none fatal; the headline claims are not circular)
1. Probe 11 (+10.1% / +12.3%): REAL compiles, not computed. 11_alias_inject.exs reads the .abstr files, appends export/spec/function forms and calls compile:forms; I wrote the aliased beams out (OUT=), loaded them, and `'Shop':new(1)` and `'Shop':'New'(1)` both return the record. But (a) the baseline is a RECOMPILE of the .abstr with [debug_info], 51 508 B, not bsc's real output: bsc's actual 23 .beam files total 54 640 B (bsc uses compile:file from_abstr). Absolute deltas (+5 204 / +6 348 B) stand; against the real baseline the percentages are about 9.5% / 11.6%, so the brief overstates by ~0.6 pt. (b) The alias is injected by a model, not by bs_emit (brief says so). (c) The 23-module corpus is not scripted anywhere in probes/ (and excludes Shop.Reports); I rebuilt it and the .abstr are byte-identical to the stored ones.
2. Probe 14 (no per-call cost): no sensitivity control. The loop is dominated by a fun call plus 'Amount' itself; nothing shows the harness could detect a real wrapper cost (e.g. a non-tail alias). "Within noise" is true but weakly informative.
3. Probe 08a: the .out is hand-written text ("finding: ..."); the Names.bs line that produced the error was later deleted, so it is not re-runnable as stored. I re-derived it: `public int foo(int x)` gives `syntax error before: foo`. Claim holds.
4. 04b: stored .out has blank gutter lines stripped; the apply/3 silence is shown only by the absence of a warning for via_apply. Real, but not an explicit negative marker. Reproduced.
5. 02_62a_adapted.sh: the narrative lines ("Yes. Erlang quotes atoms freely", VERDICT) are heredoc text, not measured. The measured lines reproduce.
6. 19_dialyzer: how misuse.beam is built is not recorded. It needs +debug_info or dialyzer fails ("Could not get Core Erlang code"). With +debug_info the output matches. The -v1 / BROKEN files (13_v1, 13b_v1, 18_v1, 04_v1) are honest and the fixes do not favour the conclusion: the 13b fix is what produces the "local alias invisible to trace" finding, which counts AGAINST candidate 2 (and is plain OTP semantics: local calls are not traced).

## Per probe
REPRODUCED (identical, or differing only in timings/paths): 02, 03, 04, 04b (modulo blank lines), 05, 06, 07 (stored file lacks the second needle header), 08b, 09, 10, 11 x4 (sizes identical; compile ms vary), 12/12b/12c/12d (sizes, collisions, module_info error identical), 13 (crash-trace half and the 0/0 trace count), 13b (control 1 event; local alias 0; remote alias 1; unaliased module -> undef), 14 (within noise both ways), 15 (counts identical; stored file lacks last 7 lines), 16, 17, 18, 19 (needs +debug_info).
CANNOT RUN: 01 (needs rebar3; 02_adapt.diff shows 02 differs only in build/path lines). 08 sources need `--src-root 08_names` (the brief's "-o <out> 08_names/Names" form errors with "module directory itself").
DIFFERS: nothing material. 15 and 07 stored outputs are shorter than a fresh run.

## Load-bearing new claims, independently re-derived
- Quoted call works in Elixir 1.20.4: I wrote Acme.erl exporting 'New'/1 and 'Get_Id'/0 (own module, own names), erlc'd it. From a .exs: `:Acme."New"(1)` -> {:new,1}; `:Acme."Get_Id"()` -> 7; `(&:Acme."New"/1).(2)` works; `Code.string_to_quoted(":Acme.New(1)")` -> error "unexpected ( after alias New". Via `elixirc`: compiled Caller.a/1 calls `:Acme."New"(5)` -> {:new,5}; typo `:Acme."Nwe"(x)` gives compile warning "undefined or private". CONFIRMED.
- Gleam 1.19.1: own project: `pub fn MakeIt()` -> "Syntax error ... expecting a lowercase name here"; constructors XMLParser/Tcp4/IPv6 -> x_m_l_parser, tcp4, i_pv6 (naive rule). PascalCase module file (src/Foo/Bar.gleam) -> only a WARNING "Invalid module name" and the module is silently not built. CONFIRMED, with one wording correction: the brief's section 0 says Gleam "rejects ... module names at the parser"; it is a warning plus the file being ignored (section 3 of the brief words it correctly).

## Citations (sampled 20)
Correct: LANGUAGE.md:3325 (apply "the way in"); :3122; :3315 (the section heading); :3337 (comment); :2467 (F46 sentence); bs_otp.erl:6-8; bs_run.erl:367 (authors_exports) and :75; bs_repl.erl:38; bs_lexer.xrl:150,153 and 16; bs_emit.erl:75-77, 97-104, 117, 131, 2099; bs_parser.yrl:308-322; bsc.erl from_abstr (838-843; brief's 826-843 range is loose but fine); 32-ffi-surface.md:204; ticket 10:335; erl_scan.erl:629 and 1607; elixir_tokenizer 1528/1197 (from probe 07, reproduced).
Loose / wrong:
- LANGUAGE.md:3460 does not say "the language needs no snake_case <-> PascalCase mapping anywhere"; it says a mapping "was measured unable to spell 'PKCS-1' ... so the language has none". Same idea, different words; the brief groups it with 3122 as an identical sentence.
- LANGUAGE.md:1618 does not give "builtins stay lowercase (int, atom)"; it is about declared entries. The builtin table is at ~577.
- 35-behaviour-callback-names.md:130,238 quote: the "symbol table" sentence is at line 132 and reads "without a symbol table", not "with no". Paraphrase.

## Claims stated as measured with no (or mismatched) probe
1. Section 4.3 compile times: "Shop 4.9/5.0/5.1 to 5.6/5.7/5.8" and "Stream 27.9/28.2/29.8 to 28.0/28.8/42.5" appear in no stored output. The nearest strings are other modules (Wire, Math). The stored Shop lines read 4.7/4.9/7.7 -> 5.6/5.8/7.3 (macro local) and 4.8/5.0/5.2 -> 5.7/6.1/6.4 (remote); Stream is 27.7/29.0/40.3 -> 28.2/30.9/41.6. The "about +0.7 to 0.9 ms on a 5 ms module" conclusion is consistent with the real data, but the quoted figures were not produced by any probe.
2. Section 3: "no BEAM language I checked ships aliases to avoid it". Probe 18 (after the twin column was dropped) measures only how many Elixir stdlib exports need quoting; it measures no aliases, and no other language was checked (Gleam stdlib is unreachable here).
3. Section 4.6: "An alias without a copied -spec would show only the inferred success typing" is not probed (only the copied-spec case was run).
4. Section 4.4: "Observer's module view ... show both names" not probed (module_info(exports) only).
5. Section 4.2: that private_names/authors_exports/defined "must learn to hide" aliases is code reading, not tested. It is plausible: with aliases exported and filtered out of Exports, private_names (Defined -- Exports) would list them as private.
6. "survives mix format": probe used Code.format_string!, not mix format (same formatter engine).
7. Section 0: "survives mix format, gets a compile-time warning that apply/3 does not" -- reproduced.
8. Probe 15 counts are grep heuristics (`about`), fine as the brief words them.

## Verdict
The decision-bearing facts (quoted call works with the same module; gets xref warning; apply does not; Gleam rejects PascalCase functions and snake_cases constructors naively; collisions and module_info error under both rules; local alias invisible to global trace; sizes) all reproduce. The size percentages are mildly overstated (baseline mismatch) and the compile-time figures and the "no BEAM language ships aliases" sentence are not backed by a probe.
