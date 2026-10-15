# Verification of artifacts/62-the-outbound-abi.md

Verifier run, HEAD dc5683d (brief authored at 019533d; no `bs_emit.erl` or LANGUAGE.md change since). Elixir 1.18.5, OTP 28, gleam 1.19.2. All reruns and extras are in `artifacts/verify/62/` (rerun_*.out, fmt.out, keys.out, dz/, mixproj/, gl/, bench_rerun.out). No brief, probe, .out, ticket or compiler file was touched. The patched compiler was only built in mktemp copies. Note: the probes print to stdout and do not write `<probe>.out` themselves, as the brief's index says. The .out files are redirections.

## 1. Probe table

| probe | verdict | notes |
|---|---|---|
| 62_elixir_syntax.sh | REPRODUCED | byte-identical to saved .out |
| 62_elixir_compiled_caller.sh | REPRODUCED | byte-identical (Nope warns, New/pipe/capture silent, 500, defdelegate 500) |
| 62_erlang_caller.sh | REPRODUCED | byte-identical |
| 62_gleam_case.sh | REPRODUCED | only the mktemp path in 4 error messages differs |
| 62_blast_radius.sh | REPRODUCED | identical, control prints (1,[7,0,7]) |
| 62_alias_prototype.sh | REPRODUCED for all deterministic rows (A, B, C: 106->186 exports, 54,456->58,796 bytes, +8.0%, Awk 1564->1952). Timing rows DIFFER, see below. | |
| 62_alias_eunit.sh | REPRODUCED | stock Failed 5 / Passed 1443; patched Failed 13 / Passed 1435; the same 8 patched-only failures; the same 5 shared environment failures |

### Timing and size claims, my own runs

- **Beam size.** Awk.beam is 1568 stock and 1956 patched in my build (+388, as claimed). The 23-module +8.0% reproduces exactly.
- **Compile time.** My n=9: stock min/median/max 333/385/404 ms, patched 359/408/455. The probe's own rerun: stock 386/416/506, patched 375/413/474. The direction flips between runs, so "indistinguishable" is right.
- **Call cost (1e7 calls, n=7 per run, 3 reruns of the bench plus the probe rerun). The brief's "alias ~5% over direct, duplication free" does NOT reproduce as a stable direction.**

| run | direct min/med | alias min/med | dup min/med |
|---|---|---|---|
| saved .out | 42.8 / 44.0 | 45.2 / 47.6 | 42.3 / 45.2 |
| probe rerun (eunit running alongside) | 47.6 / 50.3 | 45.6 / 57.2 | 41.8 / 42.8 |
| mine #1 | 49.1 / 50.3 | 54.6 / 60.2 | 54.0 / 54.3 |
| mine #2 | 49.3 / 52.6 | 44.8 / 54.7 | 41.4 / 41.6 |
| mine #3 | 50.4 / 53.2 | 54.1 / 57.7 | 54.7 / 58.2 |

  Identical code (dup) swings between about 41 and 55 ms. Medians of direct/alias/dup are within roughly 25% of each other, with no consistent order. Defensible conclusion: the alias wrapper costs on the order of 1 ns per call or less, indistinguishable from placement and JIT noise. The specific "0.24 ns / ~5%" and "duplication is free" figures are one lucky run, not a measurement. Machine load was 3-6 (other agents). This does not hurt the recommendation, since it weakens a point against option 2 only by a nanosecond.

## 2. Circularity review

- **Elixir syntax/compiled probes.** Not circular. Expected values are not hard-coded. The probe has both a negative control (`:Shop."Nope"(1)`, which warns and raises) and a stock Shop. The "no warning on New" claim was independently reproduced in a Mix project (below).
- **Alias patch.** Fresh stock copy: `patch -p1 --dry-run` is clean. +39/-2 lines, one file (`compiler/src/bs_emit.erl`): an `alias_table/1` (snake-case derivation and drop-on-collision), one extra `-export` list element, and one `alias_form/3` local wrapper per alias. Brief says "~45 lines"; this is 41 changed lines, close enough. Stock vs patched on the same Awk input (`stock_vs_patch_awk.out`): stock exports exactly the 7 PascalCase names plus `bs@type_atoms`/`module_info`; patched adds `get_order get_url2 http_get new plain to_json x2_y`. So a stock control does exist for the key row; section B of the prototype lacks its own stock control, but `62_erlang_caller` (stock `'Shop':new(1)` is undef) and section C (stock 106 vs patched 186 on identical inputs) cover it. Not circular. The patched compiler producing the aliases is by construction (the patch writes them). The probe is a cost measurement, not evidence that the aliases are good.
- **Eunit.** The probe compares stock and patched suites run in the same environment, and subtracts shared failures. I additionally ran `otp_tests, visibility_tests, heads_tests` in my own stock and patched copies: stock "All 44 tests passed", patched 6 failed. So those failures are the patch's. The otp_tests assertions at `compiler/test/otp_tests.erl:66` and `:87` are as the brief quotes. Ticket 35 line 44 and 94 do say "one function, two spellings ... a naming rule by another route". Ticket 35 chose a rename with no wrapper, so the PascalCase export is gone. The brief's Option 2 counterargument ("ticket 35 already established that the compiler may export a different spelling") is therefore stronger than ticket 35 supports. Ticket 35 *replaced* the name inside a declared behaviour and explicitly refused a general two-spelling rule. The brief says this in Finding 5, so it is not hidden.
- **Blast radius.** The regex "control" fixture (Awk, 7/7) is trivial single-line signatures and cannot catch multi-line signatures or over-matching, so it is a weak control. The brief does call the numbers a lower bound.
- **Gleam probe.** No circularity. The expected claim is refuted or confirmed by the compiler's own errors.
- No swallowed-error-reads-as-success found. `|| true` appears only on the optional `Shop/Reports` build, and the later `Restate` row proves it built.

## 3. Headline claim: `:Shop."New"(1)` works in Elixir 1.18.5 — CONFIRMED (with qualifications)

My runs: `fmt.out`, `keys.out`, `mixproj/`, `dz/`.

- `elixir -e`/script, compiled module, pipe, capture `&:Shop."New"/1`, `m."New"(1)`: all work (reproduced by the probe; also reproduced in a real Mix project, `mix run` -> `{:order, 3}`, `500`, `500`).
- **`Code.string_to_quoted`** gives `{{:., _, [:Shop, :New]}, _, [1]}`, a plain remote call.
  - **Formatter.** `Code.format_string!` and `mix format --check-formatted` leave `:Shop."New"(1)` unchanged (idempotent).
    - `'New'` is rewritten to `"New"`; `:Shop. "New"(1)` and `:"Shop"."New"(1)` are normalized to `:Shop."New"(1)`.
    - The AST is the same after formatting for all 11 cases I tried.
    - `Macro.to_string` also round-trips to the quoted form.
    - So the formatter does not break it.
- **Compile warnings in a Mix project (`mix compile`).**
  - Clean compile, zero warnings, when the B# beam is on the code path as a proper dep app.
  - A typo `:Shop."Nwe"(id)` warns "undefined or private".
  - Wrong arity `:Shop."New"(id, id)` warns "Did you mean".
  - Unquoted snake `:Shop.new(id)` warns "undefined or private".
  - `defdelegate neww(id), to: :Shop, as: :Nwe` warns (so the shim is also checked).
  - `defdelegate pay2(a, b), to: :Shop, as: :Pay` (wrong arity) warns.
  - `--warnings-as-errors` fails on these.
  - **`mix xref callers :Shop` lists the file**, so the call is visible to xref.
- **Qualification: if the B# beam is NOT on the code path at Elixir compile time, every quoted call warns** ":Shop."New"/1 is undefined (module :Shop is not available...)". This is the same as any external module, but a real B# beam must be put in an app's ebin. My first attempt via `Code.prepend_path` in `mix.exs` failed this way. A short doc note helps.
- **Dialyzer** (OTP dialyzer, PLT of erts/kernel/stdlib; dz/dialyzer_A.out, dialyzer_B.out). Works against the quoted form, and the B# beam carries `raw_abstract_v1`, so it can be analysed.
  - With the B# beam in the analysis: "Call to missing or unexported function 'Shop':'Nwe'/1", "'Shop':'New'/2" are caught. A call with a wrong argument type ("not an int") is caught against B#'s emitted `-spec`. That is a point for B# emitting specs on the PascalCase export, and a reason an alias must carry specs too.
  - Without the B# beam, all Shop calls are "Unknown functions".
- **Not a complete win (extra finding, not in the brief).** Maps B# returns have PascalCase atom keys (`Kind`, `Total`, `Id`). In Elixir, `o.Total` is a CompileError (alias), and `o."Total"` is OK, as are `o[:Total]` and `%{Total: t} = o`. This applies to the Kind contract and any record field, independent of function naming, so an alias option would not fix it. Elixir's own error message for `o.Total` says "wrap the function or field name in double quotes", but for `:Shop.New(1)` it says only "Function names ... start with lowercase" and does not mention quoting. A first-time Elixir user hitting the unquoted form is steered toward a dead end, so docs must carry the quoted form. `import :Shop, only: [{:New, 1}]` followed by `New(1)` or `"New"(1)` is a syntax error, so unqualified calls are impossible. Callers must always qualify, or go through a `defdelegate` shim.
- **Source citations (fetched v1.18.5 raw from GitHub; tokenizer 1843 lines, parser.yrl 1335, matching the brief).**
  - `elixir_tokenizer.erl:664` `_ when Kind == alias ->` is correct.
  - `:912` `handle_dot([$., H | T] = Original, ...) when ?is_quote(H)` is correct.
  - `:933` `check_call_identifier(...)` is correct.
  - `:988` `is_unnecessary_quote` is correct.
  - `elixir_parser.yrl:471` `dot_alias -> matched_expr dot_op alias : build_dot_alias(...)` is correct.
  - All citations accurate. The quoted-name path makes a `paren_identifier`, any atom, as the brief says.
  - The brief's phrase "after a `.`" for line 664 is loose, since the alias token rule applies to every capitalised token. The result is the same.

### Gleam (own project, `gl/`)
- `pub fn NewOrder` -> "I'm expecting a lowercase name here". `pub fn newOrder` -> "Invalid function name ... Try: new_order". `pub fn New` -> same lowercase error. `Shop.gleam` -> "Invalid module name" warning, no `Shop.beam`.
- A type with `Circle(Int) HTTPServer(Int) GetURL2 Plain` gives data `[{circle,1},{h_t_t_p_server,2},get_u_r_l2,plain]`. Exports are only `all/0`, `get_order/2` and `module_info`. Exactly the brief's claim (constructors become snake_case atoms, functions rejected, no aliases).

### Blast-radius spot check (independent method)
Compiled every directory under compiler/examples containing `.bs` with the real compiler and counted `-export`s from the beams (minus `module_info`, `bs@type_atoms`): 31 beams, **112 public exports** (7 `exemplars/25*` dirs do not compile standalone, so they are uncounted). A separate awk count of `public ...(` signature lines gives 126; clause-head regex 359 matches exactly (same pattern idea, so not independent). The author's 115 is within about 3% of the compiler's 112 and about 9% below the loose line count of 126. Same order of magnitude; "a lower bound" is fair. Files: 75 `.bs` under compiler/examples, which matches.

## 4. Extra probes that the recommendation leans on
1. **Typical Elixir caller experience** (Mix project, quoted calls, pipes, captures, case-matching on `%{Kind: ..., Id: i}`, a `defdelegate` snake_case shim module with `@doc`) compiles with zero warnings and runs against the B#-compiled `Shop.beam`. Verified.
2. **Tooling:** formatter (stable), `mix xref callers`, compiler typo/arity checks (including through `defdelegate`), Dialyzer typo, arity and type checks all work with the quoted form. Not tested: ElixirLS, Credo, ExDoc.

## 5. Corrections to the brief
- The "alias call ~5% / duplication free" timing figures are noise-level and not reproducible as an ordering; say "about 1 ns or less, indistinguishable from noise".
- "Not measured: Dialyzer / formatter / xref" can now be answered: all work with the quoted form (above). Section "What would change my mind (b)" is largely closed.
- Add to the docs: the beam must be on the code path (app ebin) at Elixir compile time or every call warns; PascalCase map keys (`o."Total"`) also need quotes; no `import` route.
- The ticket 35 counterargument under Option 2 overstates the precedent (it was a rename with no wrapper and explicitly rejected two-spelling as general).
- The patch is +39/-2 lines (41 changed), not "~45".
- Probe index says each probe "writes `<probe>.out`"; they print to stdout.

## Bottom line

**YES WITH CORRECTIONS.** Option 1 (accept, document the quoted form, `defdelegate` shim) is supported. The headline claim reproduced and survives formatter, `mix compile`, xref and Dialyzer. The load-bearing corrections are minor: the alias call-cost numbers are noise, the dev-ergonomics docs need the code-path and PascalCase-map-key notes, and the ticket 35 precedent is weaker than the counterargument claims.
