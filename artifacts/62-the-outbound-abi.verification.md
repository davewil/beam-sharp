# Verification of `artifacts/62-the-outbound-abi.md` (ticket 62, ENG-252)

Independent re-run, 2026-10-06. Toolchain: OTP 28, Elixir 1.20.4 (it reports "compiled with OTP 27"), Gleam 1.18.1, bsc from `compiler/src`. Scratch dir: `scratchpad/verify62/`. Nothing under `compiler/`, `wayfinder/`, the brief or the probes was edited.

## 1. Fresh re-run of every probe against the captured `.out`

| probe | diff vs captured `.out` | note |
|---|---|---|
| 62-01 | identical | |
| 62-02 | 2 lines (`Compiled in 0.41s` vs `0.54s`, `0.40s` vs `0.46s`) | gleam build wall-clock only |
| 62-03 | 6 lines, all timing | every byte, chunk and export number identical |
| 62-04 | identical | |
| 62-05 | identical | |
| 62-06 | identical | |
| 62-07 | identical | |
| 62-08 | identical | |

62-03 timing: captured load median 17,528 / 16,404 / 18,195 us (baseline / wrapper / wrapper+spec). Mine: 12,980 / 13,724 / 13,306 us. The sign of baseline against wrapper flips between runs, so the brief's "not distinguishable from noise" holds for load time. Compile time is a different case. In both runs the minimum is about 10% higher with aliases (mine 103.6 ms to 114.5 ms, captured 134.6 to 156.0). That is plausible for more forms, and the brief's "not resolvable" is conservative, not wrong. The brief's "12.1 / 12.4 / 17.5 vs 14.0 / 14.1 / 16.4" come from earlier runs that I cannot see. They are consistent with my run's spread.

## 2. Claim-by-claim

### Elixir (Finding 1, Decision 1A)

- **Backed by 62-01 and by my own direct run.** I ran each form on a fresh bsc-built `Shop`. `:Shop."New"(1)`, `Enum.map([1,2], &:Shop."New"/1)` and `3 |> :Shop."New"()` all return the map. `defdelegate neu(id), to: :Shop, as: :New` works (`D.neu(7)` returns `Id: 7`). `Code.string_to_quoted` gives errors for `:Shop.New(1)`, `&:Shop.New/1` and `:"Shop".New(1)`. A file containing `IO.inspect(:Shop.New(1))` fails with `SyntaxError`, so it still errors. The error text says the `(` after alias `New` is unexpected.
- The quote/unquote macro, `Code.format_string!`, and `import :Shop` failing are all in the `.out`.
- The `:Shop."Nope"(1)` control raises `UndefinedFunctionError`.
- **Small omission.** Single-quoted `:Shop.'New'(1)` also parses, with a deprecation warning. It is not mentioned in the brief and does not matter.
- **Not verifiable.** "Elixir older than 1.20.4" is honestly flagged as not verified.

### Gleam (Finding 2)

- I built a fresh project with these constructors: `URLParser`, `JSONValue(Int)`, `X2Y`, `Plain` and `Ab1C`. The emitted `.erl` has `-type t() :: u_r_l_parser | {j_s_o_n_value, integer()} | x2_y | plain | ab1_c`. The function `parse_url` is exported as written (`-export([parse_url/1, make/0])`). So function names are not downcased and constructor tags are downcased per uppercase letter. Verified.
- `pub fn Make` gives "I'm expecting a lowercase name here". Verified. camelCase `parseUrl` is also rejected ("not a valid function name"), so Gleam never has a function name with a capital.
- Ticket 10, line 335 (read it): "Fieldless variants compile to atoms, variants with fields to tagged tuples, PascalCase to snake_case." The context is "Gleam has no atom literal... can afford it because it is nominal... The constructor is the declaration site." That is about constructors, not function names. The brief's reading is correct. Ticket 62 (lines 115-119) cites "ticket 10 §7" as a precedent for aliasing function names, so the brief's correction of that citation is right.
- Probe 62-02 section (e), the Gleam `@external(erlang,"Shop","New")` caller, ran and returned the map. The `Shop:Nope` control crashes with `undef`.

### Alias cost (62-03)

- **The delta is reproduced and unchanged.** +4,984 bytes, 176 to 268 exports, ExpT +1,104, Code +1,458, AtU8 +609, Dbgi +1,827, Shop 2,456 to 2,852, exports 11 to 19. The spec copy costs +672 bytes. The brief's "54 bytes per alias", "7 bytes per alias" and "+1.3 percentage points" check out arithmetically (4,984/92 = 54.2, 672/92 = 7.3, 672/51,240 = 1.31).
- **The brief's "+9.7%" and "before 51,240" are wrong (see section 3, item A).**
- The simulation does add the three things a compiler change would. `alias_xform:xform` appends the export attribute entries, a `{function,0,Alias,A,[clause calling Name]}` wrapper per author export, and with `mode=spec` a copy of the `-spec`. The annotation is line `0`, which matches `-define(A, 0)` at `bs_emit.erl:21`, so the Line chunk is faithfully unchanged.
- It skips names where `derive(N) =:= N`. This is what spares Counter's lowercased callbacks. It matches the brief's statement and the delta description.
- **The measured beams are recompiled from the transformed forms and the result is used.** 62-07 writes the transformed beam to disk, and Elixir loads it and calls the alias. The same call on the plain beam raises `UndefinedFunctionError`, so the aliased code is what ran.
- **Independent check on the real build path.** I wrote the transformed forms to `.abstr` files and compiled them with `compile:file(..., [from_abstr, debug_info, report_errors, report_warnings])`, which are bsc's own options (`bsc.erl:843-846`). Over the 27 modules the result is 54,908 to 59,868 bytes (+4,960) and exports 176 to 268. That is within the `CInf` source-path-length noise of the probe's +4,984, so the delta is real.
- **debug_info and options.** Baseline and variant use the same `comp/1` (`[debug_info,binary,return_errors]`) in `alias_measure.erl`. The delta is therefore not an artefact of mismatched options. The Dbgi growth (+1,827, 37% of the total) is genuine, because bsc also ships `debug_info`.

### Stack, tail calls and shared label (62-04)

- `which/1` compiles to `{call_only,1,{f,4}}`. I confirmed this over every alias, not only Shop's. I compiled the transformed `.abstr` of all 27 modules to assembly with `'S'`. All 92 alias functions are a lone `call_only` (ignoring `%` annotations). Zero exceptions.
- **I broke the stack probe on purpose.** I built a non-tail variant of the same transform (`R = 'Which'(A), {R}`) and loaded it as `Shop`. The stack through `which/1` then shows an extra `{'Shop',which}` frame. The tail transform shows `['Which', caller...]`. So the stack check goes red for a non-tail wrapper built by the same transform and is not vacuous. The probe's own `nt/1` control is a hand-written module rather than the transform, so my check is the stronger one.
- **Tail-call memory.** The captured 2,624 bytes after 1M calls through an alias, against 16,583,424 for non-tail recursion, reproduces. The caveat is that the loop uses a hand-written `looptest` module, not a transformed B# beam, and its "wrapper non-tail would grow" is asserted rather than run. I ran that control: a 1M-deep non-tail alias returns a result nested 1,000,000 tuples deep, where the tail alias returns a flat 2,624. So the memory probe would also go red.
- **Shared label.** The hand-patched `Shop.beam` loads and `which/1` works. The crash trace names `'Which'` for both entries. Verified. "Saves about 16 bytes of Code per alias" is not measured. It is inferred from the wrapper's own cost (1,458/92 = 15.8) and is not backed by a probe measuring the patched beam.

### Collisions (62-06)

- OTP refuses the aliased module. The captured output shows `redefine_function` for `get_x/1` and `module_info/1` under the per-letter rule, plus `http_get/1` under the acronym rule. `ModuleInfo` yields `module_info`, which collides with the module's own `module_info/1`. Verified. The brief's `Without any check` paragraph lumps `http_get/1` in without saying it applies only to the acronym rule. The table does say so.
- Enumeration numbers are all in the `.out`: 3,110 names, 2,634 distinct, 332 groups, 0 of 1,562 without `_`, 788 groups for the acronym rule, 396 groups without `_`. The brief's wording ("all 332 collisions involve `_`") follows from the 0 on underscore-free names.
- **Untested precondition.** The "OTP accepts the aliased module" case is shown only for the 27 real modules (62-03 and 62-07 compile them), not for a collision-free `Names` variant. This is a minor gap.
- `Length`, `Now`, `Size` as aliases: probe 62-06 (g) lists them as BIF-named, and the 27 aliased modules compiled. That backs "accepted by erlc" in practice.
- `bs_lexer.xrl:14-16` and `:150` are correct.

### Census (62-05)

- **Independent recount, different method.** I used a Python regex over `git ls-files '*.bs'` excluding `artifacts/` (comments and strings stripped, no lexer). It found **161 files**. A `Name(` token regex that allows a preceding `.` gives **1,221 tokens and 249 distinct names**, exactly the brief's figures. Without `.Name(` qualified calls it gives 1,195 and 242. So 249 and 1,221 include qualified calls such as `List.Map(`, which the brief admits under "Not verified: Census is heuristic". No name contains `_`, a digit, or two adjacent capitals. Confirmed.
- **The scope description is wrong.** The brief says "every `.bs` in the repo". The repo has 165 tracked `.bs` files. The probe's six directory globs cover 161. The 4 left out are `artifacts/probes/59/*` (3 files) and `artifacts/probes/62/src/Names/names.bs`. Neither probe set's files change the result, but "every" is not accurate. Untracked `compiler/_build/...` copies are also excluded, correctly.
- 92 of 95 exports PascalCase: the probe reads the export tables, and the 3 lowercase ones are `handle_call/3`, `handle_cast/2` and `init/1`. The "10 compiler-known operations" match `bs_check:reserved_table/0` as printed.

### Prior art (62-08)

- **OTP: 19 uppercase-first exports.** I recounted differently, with `*/ebin/*.beam` under `erlang/lib` (1,311 beams) rather than the probe's recursive glob (1,345). The result is the same: 19, in `diameter_types`, `wxImage`, `wxMenu`, `wxRegion` and `wxWindow`. Those are generated modules, so "all in generated modules" is fair. The probe filters on `$A..$Z` only. Wider "non-lowercase" first characters bring in 439 names, almost all `'#get-...'` record accessors from `diameter_gen_*`. Those are not PascalCase names and do not change the claim.
- **Elixir: 0.** I rescanned the 447 beams: no export name begins with an uppercase letter once the `MACRO-` prefix is removed. The probe's `MACRO-` exclusion is therefore correct and harmless. The brief's "Elixir's stdlib, 0" is correct as stated, with the macro namespace excluded. It does not say so in the main text, only in the probe.
- **Scope.** Hex packages are not scanned, as the brief says.

### Source references

All read and correct: `bs_emit.erl:76` (export attribute), `bs_emit.erl:117` (`name/2`, "the one place a B# function name becomes an Erlang one"), `LANGUAGE.md:2440`, `2927-2935`, `3130` (apply is "the way in"), `3136` (`bs@`), `erl_lint.erl:1974` (`redefine_function`), tickets 32 (line 204) and 35 ("not a spellable name"), and ticket 87 (`bs@type_atoms`). Minor drift: the brief says `bsc.erl:843` is bsc's only OTP call. Line 843 is the `Options` list and `compile:file` is at 846. It is the only `compile:` call in the file.

## 3. Brief claims to correct

A. **"+9.7%" and "before 51,240" describe the wrong baseline.** The brief says the baseline "rebuilt from `.abstr` is byte-identical to bsc's own `.beam` for 27 of 27, so the sizes are of the shipped artifact". That control compiles with `compile:file(P, [from_abstr, ...])`. The measured sizes use `compile:forms(F, [debug_info, binary, return_errors])`. I checked: `compile:forms` output differs from bsc's beam in **27 of 27** modules, and only in the `CInf` chunk (compile-info: `from_abstr` and the source path). It is 132 to 148 bytes smaller per module. The shipped total is **54,908**, not 51,240. The absolute +4,984 is unaffected, because both sides share the same missing `CInf`. I reproduced it through the real `from_abstr` path as +4,960. The right percentage is **about +9.1%** of the shipped beams (4,984/54,908 = 9.08%, or 4,960/54,908 = 9.03% by the real-path build). Fix the table's "before/after" and the percentage, and reword "the sizes are of the shipped artifact" to "the delta is measured; the baseline is the shipped total minus about 140 bytes of `CInf` per module". The probe's own `.out` prints the 27 of 27 line, which is true of what it tests but is not the guarantee the brief draws from it.
B. **Census scope.** Replace "over every `.bs` in the repo" with "over the 161 `.bs` files under `compiler/examples`, `aoc`, `handoff/audition-switch`, `compiler/bin/fixtures` and `wayfinder/prototypes`". The 4 files under `artifacts/probes/` are not counted.
C. **"Saves about 16 bytes of `Code` per alias"** (Decision 3) is an inference from the wrapper's cost, not a measurement. Say "an estimate".
D. **"Kind checking is unchanged: the guard sits on the exported original"** has no probe. It follows from the design, since the alias calls the original, and 62-04 shows `function_clause` raised in `'Which'` through the alias. Say so.
E. **"Internal B# calls still call `'New'` directly (`bs_emit.erl:117`)"** is source-reading, not a probe. It is correct (`name/2` is the single funnel).
F. **Compile time.** "Not distinguishable" is conservative. Both runs show about +10% on the minimum of the compile loop when aliases are added. This is not a defect, but it should not be called unmeasurable if the claim is used as "no cost".
G. **"All 27 example modules compile only because Counter's three callbacks are skipped"** is true by the code (`derive(N) =/= N` filter) but no probe flips it. I did not run that flip. It is minor.
H. **Collision paragraph**: say that `http_get/1` is refused only under the acronym-aware rule.
I. **`bsc.erl:843`** should be `bsc.erl:846` for `compile:file` (843 is the `Options` list).
J. **Elixir "compiled with Erlang/OTP 27"** prints in 62-01 while the run is on OTP 28. Harmless, but "OTP 28, Elixir 1.20.4" is slightly inexact for the Elixir runtime.

Nothing in the brief is unbacked beyond items C, D, E and G.

## 4. Per-probe verdict

| probe | verdict | reason |
|---|---|---|
| 62-01 Elixir call forms | **VALID** | Reproduced, plus my own direct run of the quoted form, capture, pipe, `defdelegate as:`, and the `:Shop.New(1)` `SyntaxError`. The controls (`:Nope`, malformed string, lowercase) work. |
| 62-02 Gleam casing | **VALID** | Reproduced with my own fresh project (different names). The emitted `.erl` shows functions untouched and constructor tags downcased per uppercase letter. `pub fn New` is refused. Ticket 10 line 335 is about constructors. |
| 62-03 Alias cost | **VALID-WITH-CAVEAT** | The delta (+4,984, 92 aliases, chunk breakdown) is not an artefact of options and is reproduced through the real `from_abstr` path. The baseline is about 140 bytes per module below the shipped beam (`CInf`), so the percentage is overstated (9.7% vs 9.1%) and the "shipped artifact" wording is wrong. Timing is noise, as the brief says. |
| 62-04 Stack and label | **VALID-WITH-CAVEAT** | `call_only` holds for all 92 aliases. My non-tail variant of the same transform turns the stack check red. The tail-call memory loop uses a hand-written module, not a transformed B# beam, though a non-tail control I ran also goes red. The 16-byte saving is inferred. |
| 62-05 Census | **VALID-WITH-CAVEAT** | 161 files, 249 names and 1,221 tokens reproduced exactly by a lexer-free regex count. "Every `.bs` in the repo" is wrong (4 probe files excluded), and the counts include qualified-call tokens. |
| 62-06 Alias derivation | **VALID** | Collisions are real: bsc accepts the colliding names and OTP refuses the aliased module. The exhaustive counts are reproduced. The one gap is that there is no collision-free aliased `Names` variant. |
| 62-07 Elixir with aliases | **VALID** | The unaliased control fails and the aliased beam passes. It tests an Elixir property the aliases enable, not the simulation itself, so there is no circularity risk. |
| 62-08 Prior art | **VALID** | 19 in OTP, 0 in Elixir, both confirmed by a different scan. The `MACRO-` exclusion is harmless. |

No probe is CIRCULAR or UNREPRODUCIBLE.

## 5. Overall verdict

**VALID-WITH-CAVEAT.** All of the brief's headline findings stand:

- the quoted form `:Shop."New"(1)` and `defdelegate` work;
- the Gleam precedent is about constructors, not function names;
- the alias cost is +4,984 bytes over 27 modules, with 92 aliases, each a pure `call_only` jump with no extra frame;
- collisions are refused by OTP and not silent;
- the census numbers are right;
- OTP has 19 uppercase-first functions and Elixir stdlib has none.

The recommendation does not depend on anything I found wrong. The one numerical error is the baseline behind "+9.7%". The correct figure is +9.1%. The rest are wording and scope fixes (A through J above).
