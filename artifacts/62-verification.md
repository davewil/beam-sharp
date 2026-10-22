# Verification of artifacts/62-outbound-abi.md

Verifier run 2026-10-22. Fresh scratch dir `/tmp/claude-0/verify62/s` (SCRATCH override); the author's output.txt was not read or reused. `git status --short` afterwards: only `?? artifacts/`.

## Overall verdict

The brief's measurements reproduce, and its headline falsification is real. Two probes are weaker than the brief presents them (P6 and P4), and a few small text errors need fixing. Nothing found overturns the recommendation (Option A). Details below.

## Scratch bsc patches (audit)

I diffed the scratch copy against `compiler/`. Plain build: `rebar.config` (xrl_opts emptied, warnings_as_errors dropped), `bs_lexer.xrl` (`TokenLoc` becomes `{TokenLine,1}`, plus a stub `adjust_col/3`). Nothing else differs in `src/`; `bs_emit.erl` is byte-identical to the repo in the plain build.
The alias build differs from the repo only by the +32 lines in `bs_emit.erl` (export-list splice, `alias_forms`, `alias_list`, `snake`).
The patch cannot manufacture the P5 numbers. Both builds share the same lexer patch, the baseline is the unpatched emitter, and the measured delta is real forwarder code. The numbers are real, but they come from the author's own S2 rule on OTP 25. Under another rule the alias count would differ (75 of 78 functions got aliases).
The Signalbox failure is a genuine patch artefact: `erl_anno:anno_info({{14,1},1},location)` in `v3_core`.

## Per-probe verdicts

| Probe | Verdict | Notes |
|---|---|---|
| 00 toolchain | REPRODUCED | OTP 25 erts 13.2.2.5, Elixir 1.14.0, gleam 1.5.0, elm 0.19.3. Shop exports are PascalCase as claimed. |
| 01 call syntax | REPRODUCED, and can fail | All lines identical to the brief. See (a) below. |
| 02 record/Kind | REPRODUCED | The Elixir half runs through `:Shop."New"`, so it depends on 01; that is fine. |
| 03 Gleam | REPRODUCED | See (b) below. |
| 04 name-rule corpus | REPRODUCED, partly CIRCULAR | See below. |
| 05 alias cost | REPRODUCED | +8.3% bytes (49276 to 53348, plain total drifts about 0.3% between runs), exports 144 to 219 (+52%), functions 145 to 220, Shop 11 to 19 entries, flat_size 55 to 95. Compile time is within noise. |
| 06 collisions | REPRODUCED, weak as evidence | See below. |
| 07 tokenizer lines | REPRODUCED, with a nit | See below. |

### (a) `:Shop."New"(1)` and Elixir stability

My own extra tests on 1.14.0:
- **Variants.** `:Shop. "New"(1)`, `:Shop."New" (1)` and `:Shop.'New'(1)` all parse to the same AST as an ordinary call, `{{:., _, [:Shop, :New]}, _, [1]}`. `x = :Shop; x.New(1)` is a syntax error, as the brief says.
- **Quoted-call warning.** `:Shop."new"(1)` in a module emits "found quoted call "new" but the quotes are not required". So a quoted name is a deliberate, first-class tokenizer path, and the no-warning claim for `"New"` can go red.
- **Compile-time check of the target.** Elixir does check the target: `:Shop."Nope"/1` gives "is undefined or private", and `:Shop.new/1` gives "undefined, did you mean "New"/1". So the absence of a warning for `"New"` is real evidence, not an unchecked claim.
- **Built-in use.** `Kernel."+"(1,1)` runs, so quoted-function-name calls are an established general mechanism.
- **Source of line numbers.** I recovered the same `handle_dot` and `handle_terminator` structure from the beam's debug_info.
- **Confidence on later versions.** I cannot run Elixir 1.19.5. The quoted-call form is the documented way to call functions with names that are not plain identifiers, and the 1.14 tokenizer has a dedicated clause plus an "unnecessary quotes" lint for it. A parser-level removal would break `Kernel."+"`-style code and Erlang interop, so I put the chance that it still parses on 1.19.x at about 95%. This is inference from 1.14 behaviour, not a test. The brief's version flag is honest.
- **Not tested in the brief:** the formatter claim uses `Code.format_string!`, which is the same engine `mix format` uses. That is fine. The type-checker work in Elixir 1.18+ and later is not covered, but it is not a syntax question.

### (b) Gleam

All reproduced. Extra tests I ran:
- `doThing`, `do_Thing` and `Do_thing` are refused ("Invalid function name" or a syntax error); `do_thing` compiles. So non-snake_case function names are refused, as claimed.
- `ABC` vs `Abc`: the brief only shows `-type t() :: abc | abc`. I ran `case t { ABC -> 1  Abc -> 2 }` and `main()` returns `{1,1}`. That is a silent miscompile (`f(Abc)` returns 1). The brief understates it.
- The Gleam collision and constructor-snake-casing is 1.5.0 only (flagged by the brief).
- The brief's reading that ticket 10 line 335 ("PascalCase to snake_case") is about constructors is correct.

### Weak and circular spots

- **P4 (name rule corpus).** In the real corpus S1 and S2 never differ and there are zero collisions, so the corpus says nothing. The "collisions are reachable" evidence is the synthetic list `ABC/Abc`, `Get_Value/GetValue`, `ParseURL/ParseUrl`, which was chosen to collide. That is legitimate for showing reachability, but it is not evidence of likelihood (the brief does say this).
  Not in the brief: S1 had zero synthetic collisions on that list, so "a derivation rule collides" holds only for the acronym-aware rule. A rule that is injective on identifiers exists (S1: `ParseURL` gives `parse_u_r_l`). The brief's real counterpoint is that it is ugly, not that it collides. Option B's "strongest counterargument" overstates the point.
- **P6 (collisions).** The refusal is produced by the author's own naive patch. Its `Taken` set only checks alias vs original export; it does not check alias vs alias or reserved names, and it does not skip on conflict as it does for the first case. A patch that skipped colliding aliases would have compiled all three programs. So P6 shows "a naive emitter breaks", not "any emitter breaks". The brief says "naive", but then concludes "any derived-alias option must include a new diagnostic", which is a design opinion, not something measured. The line-0 location is just the forwarder anno being `?A`.
  Also: the module named `Ok` is a poor label for something that is refused.
- **P5 "+52% exports".** The baseline includes `module_info/0,1` for each module (44 of 144), so the percentage is lower than 52% if you count only author exports (75 on 100). The number is correct as computed, but the brief gives no hint it includes `module_info`.
- **P7.** The cited `elixir_tokenizer.erl:911` is the start of a `handle_dot/6` clause, but the quoted-call warning string itself sits at 917. `:1370` is the head of `handle_terminator/6`; the "unexpected ( after alias" string is at 1373. Both are off by a few lines from what the labels suggest. The brief says "clause of" and the debug_info numbers are the clause or function start, so this is accurate but misleading. They are also 1.14 numbers.

## (c) Option B numbers and the three collision programs

Reproduced as above. The collision programs reproduce (exit 1 under the alias compiler, exit 0 under the plain one). Two of the three (`ParseURL/ParseUrl`, `Get_Value/GetValue`) are collisions only under S2; the third (`ModuleInfo`) is a collision under any rule.

## (d) Kind contract table

Reproduced: right tag gives `:order`; wrong tag, an Elixir struct with identical fields, and no `Kind` all raise `FunctionClauseError`. The probe has genuine red cases. The "no Kind" row is an extra over the ticket.

## Citation checks

- `bs_lexer.xrl:150` (`uident`) and `:16` (ALNUM): correct.
- `bs_lexer.xrl:77-85`, reserved words: `raise` is at 79 and `fn` at 86. The range is close, but `fn` falls outside it by one line.
- `bs_otp.erl:40`, `bs_emit.erl:76`/`:118`/`:132`: correct.
- `bs_parser.yrl:308-312`: correct; the last tuple element is `[]` (type params).
- `LANGUAGE.md:3315-3328` and `:3324`: the section matches; `apply` is at about 3322. The file is at the repo root, not under `compiler/`.
- Ticket 32 `:204` and `:344`: the "no snake_case/PascalCase rule anywhere" sentences are there. The brief says this was written about the inbound direction; that is true (it is about `foreign` declarations). But Option B's "reverses the stated position of ticket 32" is then inconsistent with the brief's own reading. Say "sits in tension with" instead.
- Ticket 35 `:22` and `:240`: the "not a spellable name" wording is there (also at `:83` and `:131`).
- Ticket 10 `:335`: correct, and it supports the constructors reading.
- Ticket 62 quotes: the six-line block, the "Gleam downcases" paragraph, the "call was not run" note and the three candidates are quoted accurately.
- `erl_scan.erl:420-422` and `erl_lint.erl:530`: correct.

## Unsupported or imprecise claims

1. "22 of 23 modules" (P0, P4, P5, section 7): the example tree has 22 directories besides `exemplars`; 21 compile, and they yield 22 beams. The wording should be "21 of 22 example directories (22 beams)".
2. "Elixir ... uses the quoted form in every call shape I tried" is true, but none were tried inside macros, `with`, or other newer syntax. Minor.
3. Recommendation point 4, "C can be added without breaking any program" and "B cannot be retracted once programs call `:Shop.new`": reasoning, no probe. Option C is not built and the brief says so in the compiler-delta line and in section 7. But the Option C heading and the recommendation text do not carry "not built", so it is only labelled in two places, not everywhere.
4. Option B's "Elixir's own `Macro.underscore` collides the same pair": measured (ABC/Abc and ParseURL/ParseUrl) and correct.
5. "Gleam precedent does not exist" is correct for functions; the ticket's loose "downcases" meant constructors.
6. Section 7 says the author deleted stray files from the repo `examples/`. I cannot verify that, but the repo tree is clean now.

## Recommended edits to the brief

Fix the module count and the "reverses" wording, note that S1 does not collide on the synthetic names, note that `module_info` is in the export-percentage baseline, and say that P6 shows a naive emitter and not all emitters. Add "(described, not built)" to the Option C heading. Optionally state the stronger Gleam `{1,1}` result.
