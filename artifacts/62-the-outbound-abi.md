# Decision brief: ticket 62, the outbound ABI (ENG-252)

Ticket: `wayfinder/issues/62-the-outbound-abi.md`. Status when read: open. The only open
sub-decision is **function-name casing for Elixir callers**. The `Kind` contract was answered
2026-08-25 and is `LANGUAGE.md` §12. The module-prefix question is closed and is not touched here.

Every number below comes from a probe in `artifacts/probes/62/`, run against the current bsc,
OTP 28, Elixir 1.20.4 (it reports "compiled with OTP 27" while running on 28) and Gleam 1.18.1. The probe index is at the end.

## Three findings that change the question

1. **The ticket's Elixir claim is true but incomplete, and the missing form is cheap.**
   `:Shop.New(1)`, `:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)` and `:"Elixir.Shop".New(1)`
   are all still `SYNTAX_ERROR` on 1.20.4, so the ticket's table reproduces. But the ticket never
   tried a **quoted function name**, and `:Shop."New"(1)` parses and runs on 1.20.4. So do
   `&:Shop."New"/1`, `3 |> :Shop."New"()`, a quote/unquote macro building the same remote call, and
   `defdelegate new(id), to: :Shop, as: :New`. What stays out of reach is `import :Shop`
   (probe 62-01, output file `62_01_elixir_call_forms.out`). "Elixir callers use `apply/3`" is no
   longer the whole of candidate 1. I could not run the ticket's older Elixir, so I cannot say
   whether the quoted form is new to 1.20.

2. **The Gleam precedent in the ticket is about something else.** Ticket 10, line 335, is about
   *constructor tags*: "Fieldless variants compile to atoms, variants with fields to tagged tuples,
   PascalCase to snake_case". It is not about function names. Gleam function names are written
   snake_case in source and emitted unchanged. `pub fn New(...)` is a Gleam syntax error ("I'm
   expecting a lowercase name here"). Gleam never emits two names for one function. So what Gleam
   offers candidate 2 is a **derivation rule** (below), not a precedent for aliases (probe 62-02).
   Elm has no BEAM backend, so it has no analogue and I did not probe it. Erlang has none either:
   it quotes atoms freely. Elixir has no emission analogue, only the caller-side `defdelegate as:`.

3. **Candidate 2 would be the language's first snake_case rule, and tickets 32 and 35 say there is
   none.** Ticket 32 §3: "There is no snake_case ⇄ PascalCase rule anywhere in the language". Ticket
   35: `HandleCall` is a *fixed table* in `bs_otp`, because "`handle_call` is not a spellable name".
   Ticket 32's reason (a mapping can't spell `'PKCS-1'` or `valid?`) concerns the *inbound* inverse
   map. Outbound, PascalCase to snake_case is total over the lexer's identifier set. Even so, B#'s
   own identifiers can contain `_`, so the derived map is not injective (decision 2). Adopting
   candidate 2 means amending that sentence, not just adding a feature.

## The sub-decisions, and which gates which

1. **Do B# modules ship snake_case aliases at all, or do they teach the quoted call?** This gates
   everything below. Candidate 3 (rename the convention) is part of this question.
2. **If aliases: what does the derivation do when two names collide, or an alias lands on
   `module_info`?** Gated by 1. The choice between a per-letter and an acronym-aware rule is part
   of this one.
3. **If aliases: wrapper function or second export of one label?** Gated by 1, and measurement
   nearly answers it. Whether to copy the `-spec` is a sub-point.

Ask 1 alone. I recommend A below.

---

## Decision 1: do B# modules ship snake_case aliases?

The module used throughout is the real `compiler/examples/Shop` (`public Order New(int id)`,
`public atom Which(Doc d)`). What an Elixir developer writes against it:

### A. Accept, and teach the quoted call in LANGUAGE.md §12

```elixir
:Shop."New"(1)                       # parses, runs: %{Kind: :"Shop.Order", Id: 1, Total: 0}
[1, 2] |> Enum.map(&:Shop."New"/1)   # parses, runs
3 |> :Shop."New"()                   # parses, runs

defmodule MyApp.Shop do              # one line per function, Elixir's own idiom for a renamed target
  defdelegate new(id), to: :Shop, as: :New
  defdelegate which(d), to: :Shop, as: :Which
end
MyApp.Shop.new(8)                    # runs: %{Kind: :"Shop.Order", Id: 8, Total: 0}
```

**Compiler delta: none.** §12's current text says `apply(:Shop, :New, [1])` is "the way in". It
would gain the quoted form, which is shorter and works with captures and pipes.

**Evidence** (probe 62-01): the quoted form, capture and pipe all run. `Code.format_string!` keeps
the quoted spelling. A quote/unquote macro building `:Shop.New` evaluates correctly, so macro
authors are not blocked. A control run of `:Shop."Nope"(1)` raises `UndefinedFunctionError`.
`import :Shop; New(1)` is a `SyntaxError`, and `import :Shop, only: [new: 1]` fails because `new/1`
does not exist, so **importing the functions bare is the one thing A cannot give an Elixir caller**.

**Strongest counterargument.** The ticket's own worry stands: this is the likeliest way anyone tries
B#, and a first-time Elixir caller meets a syntax error on the *obvious* spelling. The quoted form is
a workaround, not a spelling anyone guesses. Nothing improves for editor completion or `import`.

### B. Emit snake_case aliases beside the PascalCase exports

What B# source stays unchanged and what the beam gains (rule: per-uppercase-letter, see decision 2):

```
module Shop
public Order New(int id)      // exports 'New'/1  AND  new/1
public atom Which(Doc d)      // exports 'Which'/1 AND  which/1
```
```elixir
:Shop.new(1)                          # runs  (control: the unaliased beam raises UndefinedFunctionError)
&:Shop.new/1 ; 3 |> :Shop.new()       # run
import :Shop, only: [new: 1]; new(4)  # runs
:Shop.which(%{Kind: :"Shop.Order", Id: 1, Total: 2})   # :order
```

**Compiler delta (concrete):**
- `bs_otp` (or a sibling): one function `snake_alias/1`, name to atom, applied to the *emitted* name.
  It is skipped where the emitted name is already lowercase, which covers the callbacks `HandleCall`
  to `handle_call`, `Init` to `init` and so on. The simulation had to special-case this: all 27
  example modules compile only because Counter's three callbacks are skipped (probe 62-03).
- `bs_emit:forms/1`, the export attribute at `bs_emit.erl:76`:
  `[{name(F,Bs), A} || ...] ++ [{alias(F), A} || ...] ++ [{type_atoms_name(), 0}]`.
- One generated function per exported function, emitted after `file_group` and before
  `validator_forms`: `{function, ?A, Alias, A, [{clause, ?A, Vars, [], [{call, ?A, {atom, ?A, Name}, Vars}]}]}`.
  The probe's `alias_xform.erl` is this delta in miniature, applied to the `.abstr` bsc writes.
- A check in `bs_check` for the collisions of decision 2.
- `--api` and diagnostics must hide the aliases, as they already hide `bs@type_atoms`
  (ticket 87, `LANGUAGE.md:3136`).

**Measured cost, 27 modules in `compiler/examples`** (probe 62-03). The sizes come from
`compile:forms`, whose output differs from bsc's shipped `.beam` in all 27 modules, in the `CInf`
chunk only (about 140 bytes smaller per module). The "byte-identical 27 of 27" control used
`compile:file` with `from_abstr`, so it does not make these sizes the shipped artifact's. The shipped
total is 54,908 bytes; the delta is the same on both sides. Through bsc's real `from_abstr` path the
verifier measured 54,908 to 59,868 (+4,960, about +9.1%) and exports 176 to 268:

| quantity | before | after | delta |
|---|---|---|---|
| `.beam` bytes (wrapper, `compile:forms`; shipped baseline is 54,908) | 51,240 | 56,224 | +4,984 (about +9.1% of the 54,908 shipped total), about 54 bytes per alias |
| export-table entries | 176 | 268 | +92, exactly the author-visible PascalCase functions |
| `ExpT` chunk | 2,220 | 3,324 | +1,104 |
| `Code` chunk | 8,004 | 9,462 | +1,458 |
| `AtU8` chunk | 4,375 | 4,984 | +609 |
| `Dbgi` chunk (debug_info) | 24,007 | 25,834 | +1,827, which is 37% of the growth |
| Shop alone | 2,456 | 2,852 | +396 bytes, exports 11 to 19 |

*Method:* `beam_lib:all_chunks` summed over every module, deterministic. **Module load time was not
resolvable, and compile time is conservatively called so.** `code:load_binary` over the 27-module set, 80 rounds times 5
repetitions, median of rounds, best repetition: three full runs gave baseline 12.1 / 12.4 / 17.5 ms
against wrapper 14.0 / 14.1 / 16.4 ms. The run-to-run noise (other sessions share this machine) is
larger than the effect, so the honest statement is **under about 0.1 ms per module, not
distinguishable from noise**. For `compile:forms` time, the minimum of the compile loop rose about 10% with aliases in both the
original and the verifier's run (verifier: 103.6 to 114.5 ms; original: 134.6 to 156.0 ms), which is
plausible for more forms. So "not resolvable" is conservative for compile time: do not read it as "no
cost". The size numbers are the reliable cost; load time is not evidence either way.

**Behaviour** (probe 62-04):
- The alias compiles to `{call_only,1,{f,4}}`, a jump to the original's label.
- A `function_clause` crash through `which/1` shows the same stack as through `'Which'/1`:
  `[{'Shop','Which',1}, ...]`, with **no alias frame**. Control: a deliberately non-tail wrapper
  `nt(A) -> R = 'Shop':'Which'(A), {R}` does show an extra `{alias_trace,nt,1}` frame.
- Tail calls survive: 1,000,000 tail calls through an exported alias end at 2,624 bytes of process
  memory, as does the direct loop. Control: a non-tail recursion of the same depth reaches 16,583,424.
- Internal B# calls still call `'New'` directly (`bs_emit.erl:117`, `name/2`), so nothing inside B#
  pays for the alias. This is a reading of the source, not a probe result.
- `Kind` checking is unchanged: the guard sits on the exported original, and the alias calls it.
  This follows from the design, not from a probe; 62-04 only shows `function_clause` raised in
  `'Which'` when reached through the alias.

**Strongest counterargument.** It adds the first snake_case rule to a language whose tickets 32 and
35 deliberately have none, and it **publishes a second name for every function, permanently**. Both
names become part of the foreign ABI the clean-room spec owes a section. An author can no longer
rename `New` to `Create` without breaking callers of two names. Elixir already reaches the same
functions with `defdelegate` (A), so the aliases buy only the `import`, plus saving one line per
function.

### C. Change the language's convention to snake_case function names

I did not write this as code that compiles, because **three measured facts make it a different
language**:

- `LANGUAGE.md:2440` (F46): "a lowercase name followed by `(` is a call through a bound value".
  `rule(cents)` is a closure call. Lowercase named functions would make `new(1)` mean two things.
- `LANGUAGE.md:2927-2935`: the three dot-forms are told apart by the **token class** of the left
  side. `o.Status` is a projection and `List.Map(x)` is a call, because uppercase means "name".
  `uident` is `[A-Z]` plus `ALNUM*` in `bs_lexer.xrl:150`.
- Ticket 35 already built a table because `handle_call` "is not a spellable name".

**Size** (probe 62-05, real lexer over the 161 of the 165 tracked `.bs` files under
`compiler/examples`, `aoc`, `handoff/audition-switch`, `compiler/bin/fixtures` and
`wayfinder/prototypes`; the 4 under `artifacts/probes` are not counted): **161 files, 249 distinct
function-like names, 1,221 call-like tokens** (`Name(`, which includes qualified calls such as
`List.Map(`; without them 1,195 tokens and 242 names), plus the 10 compiler-known operations
(`List.Map`, `Float.FromInt`, `Term.Compare`, ...). Of the 27 compiled example modules, 92 of the
95 exported functions are PascalCase. The rest of the prose in `LANGUAGE.md`, `TOUR.md` and the
tickets quotes B# too, and I did not count it.

**Strongest counterargument for C.** BEAM convention is overwhelmingly lowercase. In the installed
OTP, only 19 function names start uppercase, all in generated modules (`diameter_types`,
`wxImage`, `wxMenu`, `wxRegion`, `wxWindow`); in Elixir's stdlib, 0 (probe 62-08). B# would be the
outlier on every BEAM interface. But the cost is the grammar, not a rename.

### Recommendation for decision 1

**A, plus a sentence in §12 teaching `:Shop."New"(1)` and `defdelegate ... as:`.** It costs nothing
in the compiler, the ticket's premise ("callers use `apply/3`") is out of date, and the alias design
brings real work: a first-of-its-kind rule, a collision check, a permanent second ABI name. If David
disagrees, decision 2 is already worked out. Per `CLAUDE.md`, one occurrence of a failure gets a
sentence, not a mechanism; if a second Elixir adopter hits the import wall, do B.

---

## Decision 2 (only if B): what does the derivation do on a collision?

B# identifiers are `[A-Z][a-zA-Z0-9_]*` (`bs_lexer.xrl:14-16`), and a real `bsc` accepts all of
these in one module (probe 62-06): `GetX` and `Get_x`, `HTTPGet` and `HttpGet`, `Md5Sum`, `New2`,
`New/1` and `New/2`, `ModuleInfo`, `Length`, `End`, `Self`. Two rules were tried. Gleam's rule is
per-uppercase-letter (probe 62-02, from the emitted `.erl`: `HTTPGetError` becomes
`h_t_t_p_get_error`, `XMLHttp` becomes `x_m_l_http`, `ABc` becomes `a_bc`, `AbC` becomes `ab_c`,
`Md5Sum` becomes `md5_sum`, `New2` becomes `new2`). The other is acronym-aware (`HTTPGet` becomes
`http_get`).

| name | per-letter | acronym-aware |
|---|---|---|
| `HTTPGet` | `h_t_t_p_get` | `http_get` |
| `HttpGet` | `http_get` | `http_get` (collides with the above) |
| `GetX` / `Get_x` | `get_x` / `get_x` (collide) | collide |
| `Md5Sum`, `New2` | `md5_sum`, `new2` | same |
| `ModuleInfo` | `module_info` (collides with the BEAM's own) | same |
| `Length`, `Now`, `Size` | `length`, `now`, `size` (accepted by erlc) | same |

(This is a lookup of measured outputs, not a menu.)

**Without any check**, OTP refuses the aliased module: `redefine_function` for `get_x/1`,
`http_get/1` (only under the acronym-aware rule) and `module_info/1` (`erl_lint.erl:1974`; probe 62-06 section d). So a collision is
loud, not silent. The choice is where it is reported.

### 2a. Per-letter rule, collision is a compile error at the declaration

```
module Names
public int GetX(int n)    GetX(n)  -> n
public int Get_x(int n)   Get_x(n) -> n + 1
// error: `Get_x` and `GetX` both export `get_x/1` to Elixir and Erlang callers
```
Delta: after `Exports` in `bs_emit:forms/1` (or in `bs_check`, which already owns the callback-name
checks), build `#{{Alias, Arity} => [Name]}`; any bucket over 1, or an alias equal to `module_info`
or to an emitted callback name, is a diagnostic naming both. About 20 lines. Over every identifier of
length at most 5 on the alphabet `{A,B,a,b,1,_}` (3,110 names), the per-letter rule leaves 2,634
distinct aliases, and **all 332 collisions involve `_`**. Restricted to names without `_`, it is
injective: 0 collisions in 1,562 names. Across the real 27 modules, 0 collisions under either rule,
and no function name in all 161 repo files contains `_`, adjacent capitals or digits (probe 62-05),
so **no corpus evidence prefers either rule**.

*Strongest counterargument:* `HTTPGet` becoming `h_t_t_p_get` is ugly, and an Elixir developer would
never guess it.

### 2b. Acronym-aware rule, same compile error

Same delta, a longer `snake_alias/1` (about 15 lines against 5). The nicer `http_get` costs
injectivity even without `_`: 396 collision groups in the same 1,562 underscore-free names, so
`HttpGet` and `HTTPGet` could never both exist in one module. *Strongest counterargument:* the rule
turns a typographic choice into a permanent restriction on what B# authors may name two functions.

### 2c. Per-letter rule, and names containing `_` get no alias

Delta: the same, with `snake_alias/1` returning `none` for any name containing `_`. No new error,
and the alias set is injective by construction. But a function can then have the Erlang spelling and
no Elixir one, and the author finds out only when a caller complains. *Strongest counterargument:* a
silent absence is the failure shape this repo's rules avoid.

### Recommendation for decision 2

**2a.** It is the only variant that keeps an exact "every public function has exactly one snake_case
twin" statement, and it follows the repo's stance of refusing at the declaration. Alias names that
equal an auto-imported BIF (`length/1`, `size/1`, `now/0`) are accepted by erlc, so no special case
is needed there; `module_info` is the one reserved collision, and it is covered by the same check.
Elixir reserved words (`end`, `fn`, `do`, `when`, `not`, ...) parse after the dot in 1.20.4 (probe
62-07), so no keyword escape is needed either.

---

## Decision 3 (only if B): wrapper function or second export of one label?

```erlang
%% wrapper: what the delta in decision 1B emits
which(A1) -> 'Which'(A1).        %% compiles to {call_only,1,{f,4}}: a jump
```
versus one code label exported under two names, which cannot be written in abstract format. I
patched the `ExpT` and `AtU8` chunks of the real `Shop.beam` by hand (probe 62-04, section 4). The
module loads, `which/1` is exported, and a crash through either name prints the label's own
`func_info` name `'Which'`. So the shared label works on OTP 28 but gives **no observable gain**:
the stack is the same, the wrapper adds no frame, and the shared label saves an estimated 16 bytes of
`Code` per alias (inferred from the wrapper's own cost, 1,458/92; not measured on the patched beam). It also means post-processing the `.beam` after `compile:file`, which today is
bsc's only OTP call (`bsc.erl:846`). **Wrapper.**

The `-spec` question is the sub-point. Copying it to the alias costs +672 bytes over 92 aliases
(`Dbgi`, +1.3 percentage points of beam size, probe 62-03 `mode=spec`) and keeps §12's "a `-spec`
for every function whose type is known" true for the snake_case name. **Copy it**, because Dialyzer
users in Erlang are the audience for specs and 7 bytes per alias is small.

---

## Probe index

| probe | claim | result | control |
|---|---|---|---|
| `62_01_elixir_call_forms.sh` / `.out` | Unquoted dot forms on a PascalCase export are syntax errors on Elixir 1.20.4; other call routes work | `:Shop.New(1)`, `:"Elixir.Shop".New(1)`, `&:Shop.New/1`, `Shop.New(1)` are `SYNTAX_ERROR`. Quoted `:Shop."New"(1)`, its capture, pipe, `apply`, `:erlang.apply`, `Kernel.apply`, `make_fun`, quote/unquote macros, `defdelegate as:` all parse and run. `import :Shop` cannot reach `New` | `:lists.reverse([1])` parses; a malformed string reports `SYNTAX_ERROR`; `:Shop."Nope"(1)` raises `UndefinedFunctionError` |
| `62_02_gleam_casing.sh` / `.out` | Gleam does not downcase function names; it downcases constructor tags per uppercase letter; `a/b` becomes `a@b`; a Gleam caller can run `@external(erlang,"Shop","New")` | Functions are emitted as written; `h_t_t_p_get_error`, `x_m_l_http`, `a_bc`/`ab_c`, `md5_sum`, `{new2,_}`; module `a@b`; the call to `Shop:New(3)` ran and returned the map | `pub fn New` is a Gleam syntax error; `Shop:Nope` crashes with `undef` |
| `62_03_alias_cost.sh` / `.out` (+ `alias_xform.erl`, `alias_measure.erl`) | Alias cost over all 27 example modules | +4,984 bytes (about +9.1% of shipped), +92 exports, chunk breakdown; spec copy +672 bytes more; load and compile time not resolvable (noise larger than effect) | Baseline rebuilt from `.abstr` via `compile:file` is byte-identical to bsc's `.beam`, 27 of 27 (but the measured sizes use `compile:forms`, which differs in `CInf`) |
| `62_04_alias_stack_and_label.sh` / `.out` (+ `alias_trace.erl`) | Wrapper is a `call_only` jump with no extra frame and keeps tail calls; one label can be exported under two names | `call_only`; identical stacks; 2,624 bytes after 1M tail calls; patched beam loads and `which/1` works | Non-tail wrapper shows the extra frame; non-tail recursion grows to 16,583,424 bytes |
| `62_05_census.sh` / `.out` (+ `census.erl`) | Size of candidate 3 and the aliased population | 161 files, 249 distinct names, 1,221 call-like tokens; 92 of 95 exports PascalCase; 10 compiler-known operations; no name in the repo has `_`, adjacent capitals or digits | A known file counts as `['Fib'], 2 heads, 5 call-like`; the three regexes fire on known inputs |
| `62_06_alias_derivation.sh` / `.out` (+ `alias_derive.erl`, `src/Names/names.bs`) | Derivation collisions and reserved names | `GetX`/`Get_x`, `HTTPGet`/`HttpGet` (acronym rule), `ModuleInfo` all make OTP refuse the module; exhaustive enumeration: per-letter 332 groups (all with `_`), acronym-aware 788; 0 collisions on the real 27 modules | The baseline `Names` module compiles; both rules are shown side by side so a rule that never collided would show 0 |
| `62_07_elixir_with_aliases.sh` / `.out` | With aliases, Elixir gets plain dot syntax, capture, pipe, `import`; reserved words parse after the dot | All run; `:Shop.end(1)` and 14 other keywords parse | The unaliased beam: `:Shop.new(1)` raises `UndefinedFunctionError` and `import ... only: [new: 1]` fails |
| `62_08_pascalcase_prior_art.sh` / `.out` | No BEAM standard library uses PascalCase function names | OTP: 19 exports in 5 generated modules out of 1,345 beams. Elixir: 0 of 447 | `lists.beam` exports `reverse/1`; the bsc `Shop` beam shows 8 |

All probes run from the repo root; each prints its claim in its header. I did not modify anything
under `wayfinder/`, `compiler/` or the docs.

## Not verified

- **Elixir older than 1.20.4.** The ticket measured an older Elixir. I re-ran every ticket form on
  1.20.4 and the SYNTAX_ERRORs reproduce, but I cannot say whether the quoted form was available
  before, and could not test it.
- **Elm.** No BEAM target, so no analogue; I did not run the Elm toolchain.
- **Gleam compiler source and `gleam/io` stdlib** are not installed (hex.pm is blocked), so the
  Gleam claims are read from emitted `.erl` and a successful build, not from compiler source.
  Probe 62a's Gleam section cannot run here for the same reason (`gleam new` pulls the stdlib);
  62-02 uses a no-dependency project and `erlang:display`.
- **Alias delta is simulated, not implemented.** `alias_xform.erl` transforms the `.abstr` bsc
  already writes; no change to `compiler/src` was made, so the `bs_check` collision diagnostic and
  `--api` hiding are described, not built or tested.
- **Load and compile time.** Measured but not resolvable: the three load-time runs overlap
  (baseline 12.1-17.5 ms against 14.0-16.4 ms for 27 modules) because the machine was shared.
- **Dialyzer.** I did not run it against aliased modules; the `-spec` recommendation rests on size
  and on §12's wording, not on a Dialyzer result.
- **Census is heuristic.** `Name(` token counting over the real lexer includes some foreign-call
  and qualified-call tokens (1,195 tokens and 242 names without the qualified ones), and does not count prose or code blocks in `*.md` files.
- **Hex packages** (anything outside the installed OTP and Elixir trees) were not scanned for
  PascalCase function names.

## Verification

Verdict: **VALID-WITH-CAVEAT**. Full report: [`62-the-outbound-abi.verification.md`](62-the-outbound-abi.verification.md).
The headline findings and the recommendation stand; the one numerical error was the size baseline.

Corrections applied:

1. Size baseline: sizes come from `compile:forms`, which differs from the shipped beam in `CInf` in
   all 27 modules; shipped total 54,908, not 51,240; delta +4,984 stands (+4,960 via the real
   `from_abstr` path, exports 176 to 268); percentage about +9.1%, not +9.7%; "sizes are of the
   shipped artifact" removed.
2. Census scope: 161 of 165 tracked `.bs` files (4 under `artifacts/probes` excluded); counts include
   qualified calls (1,195 tokens / 242 names without them).
3. "About 16 bytes of `Code` saved per alias" reworded as an estimate.
4. "Kind checking is unchanged" and "internal calls use `name/2`" marked as design and source-reading
   claims, not probe-backed.
5. Compile time: the minimum rose about 10% in both runs, so "not resolvable" is conservative.
6. `http_get/1` is refused by OTP only under the acronym-aware rule.
7. `bsc.erl:843` corrected to `:846` for `compile:file`.
8. Elixir reports "compiled with OTP 27" while running on 28.

The verifier's extras:

- The 62-04 tail-call memory loop uses a hand-written module, not a transformed B# beam (the verifier's
  non-tail control also goes red).
- The 16-bytes-per-alias shared-label saving is inferred, not measured.
- No collision-free aliased `Names` variant was compiled.
- Counter's callbacks being skipped was not flipped to see the failure.
