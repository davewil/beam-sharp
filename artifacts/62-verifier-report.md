# Verifier report: ticket 62 brief (outbound ABI, function-name casing)

Scratch and re-run outputs: `/tmp/claude-0/verify62/`. No brief, probe, compiler or Linear edits. Author `.out` files untouched.

## Overall: PASS WITH CAVEATS

Every claim reproduces and every negative control fails as it should. Two numeric details in the brief do not match any saved output. Neither changes a conclusion.

## 1. Re-run of every probe

All six `.sh` probes exited 0 and `07_name_table.exs` ran. Each output was diffed against the saved `.out`, after masking temp-dir names.

| Probe | Status | Diff |
|---|---|---|
| 01_rerun_62a | REPRODUCED | none (the offline `gleam new`/hex failure in step 4 reproduces too) |
| 02_gleam_call | REPRODUCED | only the build time (0.42s vs 0.50s) |
| 03_elixir_workarounds | REPRODUCED | none |
| 04_gleam_names | REPRODUCED | only the build time |
| 05_alias_cost | REPRODUCED for the size, export and atom figures. DIFFERS on the load-time block | see below |
| 06_alias_from_elixir | REPRODUCED | none |
| 07_name_table | REPRODUCED | none |

**05 load-time block.** The numbers (microseconds, min/median/max) differ in each of three runs:

- Saved `.out`: base 436/1591/6191, wrap 525/1482/59939, copy 513/1644/7304.
- My re-run: base 388/1581/30778, wrap 481/1564/6104, copy 521/1596/16646.
- **The brief** quotes base 466/847/2821, wrap 458/1030/6566, copy 470/1216/7055. These appear in no saved `.out` (grep of `*.out` for 466, 2821 and 6566 finds nothing). They came from an earlier, unsaved run.
- The brief's conclusion ("spread wider than any difference; no claim") holds in all three runs. But the table does not trace to a saved artifact.

**05 byte totals depend on the temp-dir path.** The base is 54,860 B in the author's run. Re-running the author's own escript on my output dir gives base 52,092, wrap 57,104 (+9.6%), copy 61,516 (+18.1%). My independent script gave a base of 50,880 and +4,972 B of aliases (+9.8%).

- The alias increment is stable at about 5,000 B, and Shop is +400 B in every run.
- Debug-info or source-path metadata makes the absolute base vary by about 5%. The brief's "+9.2%" is really "+9% to +10%".
- Export entries (176 to 268), `external_size` (2741 to 3825, +39.5%) and atoms (483 to 573) are exact in every run, including mine.

**Wording nit.** The brief says "27 example modules that compile standalone". The script prints "26 compiled, 1 not compiled standalone". The one failure is the directory `Shop/Collections`. Its module `Shop.Collections.Ints` is emitted anyway as part of Shop's import closure, so 27 modules are measured. The substance is fine.

## 2. Does each probe test its claim?

| # | Verdict | Evidence |
|---|---|---|
| 1 | CONFIRMED | Uses `Code.string_to_quoted`, a real parse. `:Shop.New`, `:"BSharp.Shop".New` and `:"Elixir.Shop".New` give SYNTAX_ERROR. Control: `:Shop.new(1)` and `:"BSharp.Shop".new(1)` parse. |
| 2 | CONFIRMED | Erlang `'Shop':'New'(1)` returns the map. |
| 3 | CONFIRMED | Gleam built and called the real `Shop.beam` and returned `order`. See the controls in section 3. |
| 3b | CONFIRMED | The hex resolution failure is in the 01 output. |
| 4 | CONFIRMED, and it does contradict the ticket | Six forms were executed via `Code.eval_string`: `:Shop."New"(1)`, `m."New"(1)`, `&:Shop."New"/1`, `apply`, `:erlang.apply`, `Function.capture`. Each returns the map. The ticket text (lines 35-44) and LANGUAGE.md 3128-3131 say Elixir cannot call a PascalCase export, and that "apply is the way in". |
| 5 | CONFIRMED | `ShopWrap.__info__(:functions)` is generated from `:Shop.module_info(:exports)`, and `ShopWrap.new(4)` runs. The "~6 lines" is accurate: it is the `for` block. |
| 6 | CONFIRMED, with the caveat the brief already states | Alias beams are made by editing `.abstr` (simulated). The export list shows both name sets. `:Shop.new(1)` and `which` run. Erlang equality is true. Control: on the unmodified bsc beam, `:Shop.new(1)` raises UndefinedFunctionError and the Erlang equality check raises `undef`. |
| 7 | CONFIRMED | The 04 output shows `h_t_t_p_get`, `to_j_s_o_n`, `a_b_c` and `a1_b`. `pub fn Foo()` gives "expecting a lowercase name". Scope is variant tags only, as the brief says. |
| 8 | CONFIRMED | Phase 1 errors are at 15:3 (`Get_2`) and 17:51 (`Foo_bar`). |
| 9 | CONFIRMED (see the caveats in section 1) | My independent script (own alias builder, own counts) gives 95 functions, 27 modules, exports 176 to 268, and `external_size` 2741 to 3825. The "Counter gains nothing" claim is true: its exports are only `handle_call/3`, `handle_cast/2`, `init/1`, `module_info/0,1` and `bs@type_atoms/0`. |
| 10 | CONFIRMED | The collision groups match the brief's table: E collides on `ABC`/`Abc`, `FooBar`/`Foo_bar` and `GetX`/`Get_X`; G collides only on `FooBar`/`Foo_bar`. E is the real `Macro.underscore`. |

**Extrapolation in claim 10.** Gleam bans underscores, so G's behaviour on `Get_X` (`get__x`) is the author's extension of the per-capital rule. It was never observed in the Gleam binary. The brief labels G "gleam-style", which is fair, but "G was asserted equal to the real gleam binary on 13 names" covers only underscore-free names.

## 3. Circularity hunt

| Suspect | Finding | Negative control (run) | Result |
|---|---|---|---|
| 07 `gleam_actual` is a hard-coded copy of the 04 output, and the assert compares G to that copy rather than running gleam | Weak but not circular. I diffed the map by eye against `04_gleam_names.out`: all 13 entries match. | A mutated G (no capital splitting) was checked against E | Differs from E on `HTTPGet` as expected. The assertion can fail. |
| 03 `ev` wraps in `rescue` and could mask errors | The `{:raised, ...}` branch is surfaced in the output rather than hidden | `:Shop."Nope"(1)` | `{:raised, UndefinedFunctionError}` |
| 03 positive rows could pass against a stale beam | The beam is freshly built into a mktemp dir | Same fresh build, in `nc/ebin` | The positive row returns the map. |
| 02 Gleam "ran": could the result be hard-coded? | `caller:main()` is evaluated in `erl` against the compiled Gleam beam plus the B# beam | Wrong function name (`Neww`), lowercase `new`, and no `ebin` on the path | All three give `undef`. The positive call returns the map. |
| 06 alias beams made by `.abstr` editing | Disclosed in the brief | Real bsc beam, no alias | `:Shop.new(1)` raises. |
| 01 `|| true` or grep-on-echo patterns | None found in any probe script | none needed | |
| 05 cost measured on a different artifact than the claim | The "wrap" variant is a synthetic wrapper; there is no `-spec`, and the brief says so. Alias derivation only affects atom lengths. | Independent re-implementation | Same ~5 KB increment. |

No circular probe found.

## 4. File:line citations (opened and checked)

- `bs_emit.erl:74-77` is the exports plus `type_atoms_name()`. OK.
- `bs_emit.erl:118` is the comment "The one place a B# function name becomes an Erlang one". The definition is on line 118-119. OK.
- `bs_emit.erl:132-136` is `emitted_name`. OK.
- `bs_otp.erl:40ff` is the callbacks table. OK.
- `bs_otp.erl:83-89` is `callback_name`, keyed by name and arity. OK.
- `bs_lexer.xrl:14-16` is UPPER, LOWER, ALNUM (with `_`). OK. `:150` is uident and `:153` is lident. OK.
- LANGUAGE.md:2927 is "no snake_case ⇄ PascalCase mapping anywhere". OK.
- LANGUAGE.md:3265-3266 is "compiler-known table, not a rule". OK.
- LANGUAGE.md:3103 is the section 12 header. OK. The range 3103-3290 ends inside a table, which is harmless.
- LANGUAGE.md:3128-3131 matches the SyntaxError and "the way in" text. OK.
- Ticket 62 lines 35-44 are the "no module prefix fixes it" block. OK. Line 27 holds "gleam 1.18.1". OK.
- Ticket 32 line 204 ("There is no snake_case ⇄ PascalCase rule") and ticket 35 line 22 are OK.
- Ticket 10 line 335 reads "PascalCase to snake_case". OK.

All citations are accurate. I did not check the claim that `t.bs:4:12` (a lowercase function head is a syntax error) was run in-session. It is a transcript claim with no probe, and Option C does not depend on it.

## 5. Cost-number recomputation

My script `/tmp/claude-0/verify62/mine.escript` rebuilds the wrappers from the `.abstr` files with its own naming code. Results:

| Figure | Mine | Brief |
|---|---|---|
| modules | 27 | 27 |
| public functions | 95 | 95 |
| export entries | 176 to 268 | 176 to 268 |
| `external_size(exports)` | 2741 to 3825 | 2741 to 3825 |
| atoms | 483 to 573 (author's script re-run) | 483 to 573 |
| wrapper byte increment | +4,972 B | +5,020 B |

Percentage figures differ slightly because the base size depends on the path length (section 1).

## Verdict

- **Claims 1-8:** PASS.
- **Claims 9, 10:** PASS. Byte percentage is "about +9% to +10%". The load-time numbers in the brief are not from the saved `.out`; the conclusion is unaffected.
- **Brief's central finding** (the ticket overstated the cost; `:Shop."New"(1)` works) is solid and independently confirmed.

Recommended brief fixes, not applied:

1. Replace the load-time numbers with those from the saved `.out`, or re-save the `.out`.
2. Say "+9% to +10%, path-dependent base".
3. Say "26 compiled standalone, 27 measured".
4. Note that G's underscore behaviour is extrapolated.
