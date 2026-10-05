# Decision brief — ticket 62 (ENG-252): function-name casing for foreign callers

Scope: the one open decision in `wayfinder/issues/62-the-outbound-abi.md` (function-name casing). The
`Kind` documentation is answered (LANGUAGE.md §12) and the module-prefix question is settled; neither is
reopened. Nothing in the repo was edited. Probes: `artifacts/probes/62/` (`run.sh` re-executes everything;
raw output in `out/`; `verdict.sh` prints HOLDS/REFUTED/INCONCLUSIVE per claim; `CHANGELOG.md` logs every
probe edit and why). The experimental compiler is `probes/62/compiler-alias.patch` (4 KB, applies to the
repo's `compiler/src`, built in scratch; the repo's compiler is untouched).

**Headline.** The ticket's premise, *"Elixir cannot call a PascalCase export"*, is **half wrong**:
`:Shop."New"(1)` is ordinary Elixir, runs, is compile-time checked, and survives the formatter (p02, p04).
What Elixir cannot do is write the name *unquoted*. That moves option 1 ("accept") from "callers are pushed
to `apply/3`" to "callers write two quote marks", and a one-line `defdelegate` gives them snake_case names
with no B# change at all (p15).

## 1. Sub-decisions

Already decided and binding here (grepped, not assumed):

- **Ticket 32 §3**: *"There is no snake_case ⇄ PascalCase rule anywhere in the language"*
  (`wayfinder/issues/32-ffi-surface.md:204`), restated in `compiler/src/bs_otp.erl:8` and ticket 35.
  That was decided for *inbound* names, on the evidence that arbitrary Erlang names (`'PKCS-1'`) have no
  spelling. Outbound the domain is B#'s own grammar, so the 32 counterexamples cannot occur; a collision
  class they never had does (see §3). Option B below would be the first mapping rule in the language.
- **Ticket 35**: a B# function name is PascalCase *by construction* (`uident = [A-Z]{ALNUM}*`,
  `bs_lexer.xrl:150`; ticket 35 line 130). Behaviour callbacks already lower through a hand-written table
  (`bs_otp.erl`), so a module that declares `behaviour GenServer` exports `handle_call`, **not**
  `HandleCall` (p17: `Counter exports: [{bs@type_atoms,0},{handle_call,3},{handle_cast,2},{init,1}]`).
  LANGUAGE.md §12 line 3120 ("exported PascalCase, exactly as written") is therefore already false for
  callbacks and does not say so (§13 line 3264 does).
- **Ticket 40 §3** (line 308): private is the default; only `public` is exported. **Ticket 87**: the compiler
  may export a function the author did not write (`bs@type_atoms/0`); `bs@` is the compiler's prefix.
  **Ticket 50**: `!` and `?` cannot appear in a B# function name, so any derived alias is `[a-z0-9_]+`.

Open, in the order they gate each other (ask the first alone; the rest follow):

1. **Gating: does a foreign caller get a second, snake_case export per function?** Accept as is / emit
   aliases / change B#'s convention.
   - *Change B#'s convention* is not offered as an option. It contradicts ticket 35's mechanism (the lexer
     tells function from type by case) and p16 measured the radius: 161 `.bs` files, 362 signatures, 604
     clause heads rewritten, plus `bs_lexer.xrl:150/153` and every `uident` production (50 lines in
     `bs_parser.yrl`). The ticket already ranked it "largest blast radius"; this is the number.
2. *If aliases:* **derivation rule**, and what happens on collision.
3. *If aliases:* **scope**: every `public` function, or opt-in.
4. *If aliases:* **the alias's `-spec`** and **thin delegation vs duplicate body**.
5. **Private functions**: never aliased (not exported). Measured, not a choice (p06 Clash4).
6. **Clean-room spec owes**: under A, a correction to §12; under B/C, a derivation (or syntax) section, a
   collision diagnostic, a reserved-alias list, and §12's "exactly as written" sentence rewritten.

## 2. Executed facts

Each row: probe, what was run, real output. **Bold REFUTED / NOT REPRODUCED** marks ticket claims.

| # | Probe | Result |
|---|---|---|
| E1 | `p01` re-runs `wayfinder/prototypes/62a_from_the_outside.sh` unmodified | Rows 1-6 (`:Shop.New(1)`, `:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)`, `:"Elixir.Shop".New(1)` all `:SYNTAX_ERROR`; `:"BSharp.Shop".new(1)` and `apply` parse), Erlang `'Shop':'New'(1)`, plain-map record (`is_struct? false`), wrong tag and Elixir struct → `FunctionClauseError`: **all reproduce**. Note `Totals` is a *file* of `Shop.Reports`, not an export (exports: `Restate`, `Counted`, `Fully`); the row is still a syntax error. |
| E2 | `p01` Gleam block of 62a | **NOT REPRODUCED as written**: `gleam new` pulls `gleam_stdlib`, `error sending request for url (https://repo.hex.pm/packages/gleam_stdlib)`. Redone without deps in E9. |
| E3 | `p02`: quoted-call syntax, each form parsed **and run** against the real `Shop` beam | `:Shop."New"(1)` → `{:ok, %{Kind: :"Shop.Order", Total: 0, Id: 1}}`; `:"Shop"."New"(1)` ok; `mod = :Shop; mod."New"(2)` ok; `&:Shop."New"/1` then `f.(4)` ok; `1 |> :Shop."New"()` ok; `alias :Shop, as: S; S."New"(1)` ok; `:"Shop.Reports"."Restate"(3)` → `{:ok, 9}`. Still syntax errors: unquoted capture `&:Shop.New/1`, `import :Shop, only: [New: 1]; New(1)` and `"New"(1)` (import itself compiles; no unqualified call can be written). **Ticket §1 "Elixir cannot call a PascalCase export": REFUTED as stated** (verdict T4). |
| E4 | `p03`: real parser text for `:Shop.New(1)` | `unexpected ( after alias New. Function names and identifiers in Elixir start with lowercase characters or underscore.`; for `:Shop.New` (no parens): `atom cannot be followed by an alias. If the '.' was meant to be part of the atom's name, the atom name must be quoted.` The ticket's "reads `.Capitalized` as an alias" **holds**, and Elixir's own message names the fix (quote it). `:Shop._New(1)` parses; `:Shop.New_(1)` does not. |
| E5 | `p04`: `elixirc` with `Shop` on the path | `:Shop."Nw"/1 is undefined or private`; `:Shop."New"/2 ... Did you mean: * "New"/1`. Compile-time xref sees through the quotes. Formatter: `:Shop."New"(1)` unchanged, `:Shop."new"(1)` → `:Shop.new(1)`. Elixir 1.19 also warns *"found quoted call "http_get" but the quotes are not required"* (p07), so quotes are only tolerated where needed. |
| E6 | `p15`: `defdelegate new(id), to: :Shop, as: :New` against the **unmodified** beams | Compiles; `MyApp.Shop.new(4)` → `%{Kind: :"Shop.Order", Total: 0, Id: 4}`; a typo'd `as: :Nwe` warns `:Shop."Nwe"/1 is undefined or private`. |
| E7 | `p05`: Gleam 1.18.1, no deps, generated `.erl` read from `build/dev/erlang/p05/_gleam_artefacts/` | Constructors: `-type colour() :: red \| h_t_t_p_get \| to_j_s_o_n.` from `Red HTTPGet ToJSON`; `{circle, float()}`, `{right_triangle, ...}`, `{order, ...}`; module `a/b` → `a@b.erl`. **A rule per capital, not acronym-aware.** |
| E8 | `p05`: can Gleam name a PascalCase *function*? | `pub fn New(...)` → `error: Syntax error ... I'm expecting a lowercase name here`; `Foo_bar` same; `fooBar` → `Invalid function name ... Try: foo_bar`; variant `Dark_Green` → `Invalid type variant name ... Hint: Type variant names start with an uppercase letter and contain only lowercase letters, numbers, and uppercase letters. Try: DarkGreen`; `src/Shop.gleam` → `warning: Invalid module name` (file ignored). **Ticket 10 §7 (`wayfinder/issues/10-atoms-in-a-csharp-skin.md:335`) and ticket 62 candidate 2 ("Gleam downcases PascalCase to snake_case when it emits"): REFUTED for functions** (Gleam cannot spell one; nothing is downcased); **true only for type constructors**, and there the rule is injective *because* Gleam forbids `_` in variants: `HttpGet`→`http_get`, `HTTPGet`→`h_t_t_p_get` (p05 neg5, both compile, distinct atoms). |
| E9 | `p05`: `@external(erlang, "Shop", "New")` run against a real bsc beam | Generated `ext.erl`: `shop_new(Id) -> 'Shop':'New'(Id).`; `ext:make(3) -> #{'Kind' => 'Shop.Order','Total' => 0,'Id' => 3}`. Ticket 62's "compiles (call not run)" **holds, and now it is run**. |
| E10 | `p06` A: patched compiler, `BS_ALIAS=thin`, rule S, module `Casing` | Every name aliases and the alias returns what the original does: `HTTPGet→http_get`, `ToJSON→to_json`, `Add2→add2`, `Vec3Dot→vec3_dot`, `GetHTTPResponse→get_http_response`, `IOList→io_list`, plus BIF/keyword-named `Spawn→spawn`, `Abs→abs`, `Do→do`, `End→end`, `Nil→nil`, `True→true`, `When→when`... (all 22 compile under `compile:file`). |
| E11 | `p07`: Elixir calling those aliases | All 22 `:Casing.<alias>(1)` **parse unquoted and run** (`{:ok, 2}`), including `do`, `end`, `fn`, `nil`, `true`, `when`, `and`, `not`, `case`: after a `.` Elixir accepts reserved words. My pre-registered expectation that some would still need quotes is **wrong**. `import :Casing, only: [http_get: 1]; http_get(1)` → `{:ok, 2}` (unqualified call, impossible without aliases, E3). |
| E12 | `p06` B: collisions; baseline `bsc` vs patched | Baseline accepts all of `FooBar`+`Foo_Bar`, `HttpGet`+`HTTPGet`, `FooBAR`+`FooBar`, `Module_Info` (exit 0). Rule S: `alias_collision FooBar Foo_Bar foo_bar`, `alias_collision HttpGet HTTPGet http_get`, `alias_collision FooBAR FooBar foo_bar`, `alias_shadows_existing Module_Info module_info 1` (the BEAM's own `module_info/1`). Public `FooBar` + **private** `Foo_bar`: no error. `ALNUM` includes `_` and digits (`bs_lexer.xrl:16`), so B# can write all of these; *no total rule over this alphabet is injective*. The patch raises an Erlang error (a crash), not a diagnostic. |
| E13 | `p06` C: alias vs OTP callback names | Module with **no** behaviour and `public Init(int)`: baseline exports `[{'HandleCall',2},{'Init',1},{'Start',2}]`; with aliases adds `{handle_call,2},{init,1},{start,2}`, and `gen_server:start('Capture', 7, [])` becomes `{error,{bad_return_value,7}}` (it *called* the alias) instead of the baseline's `undef`. This is the capture that `bs_otp.erl`'s header says the language refuses ("a helper that shares a callback's name is never silently captured", F10). Aliases would need an exclusion list. |
| E14 | `p14`: rules S and G over every public name in the repo's 161 `.bs` files (252 signatures, 155 distinct names) | Zero within-module collisions under either rule; **zero names with adjacent capitals, an underscore, or a digit**; the two rules agree on all 155. The hard cases in §3 are not exercised by any existing program. |
| E15 | `p09`: `beam_disasm` of the thin alias | `[line,label,func_info,label,call_only]`, `{call_only,1,{'Sz3','ScoreAt1Value',1}}`, `alias has allocate (a frame)? false`. A tail call: a jump, no frame. |
| E16 | `p13`: crash through the alias | thin: `[{'Sz3','ScoreAt1Value',[<<"x">>]}, ...]` (alias frame absent), Elixir text `no function clause matching in :Sz3."ScoreAt1Value"/1`; dup: `[{'Sz3',score_at1_value,...}]`. Under thin a caller's crash report names the Pascal function. |
| E17 | `p12`: `Code.Typespec.fetch_specs(:Casing)` | thin (alias carries a copy of the `-spec`): specs for `Add2, HTTPGet, add2, http_get`; `thin_nospec`: only `Add2, HTTPGet`. `bsc --api` output is byte-identical with and without aliases (p08: `api identical`, 243 B both): aliases are invisible to B#'s own view. |
| E18 | `p17` | see Sub-decisions: callback modules already export snake_case only. |

## 3. Neighbour survey

- **Erlang.** Atoms are quoted freely: `erl_scan.erl:626-627` (`scan1([$'|Cs]...) -> scan_qatom`) and
  `erl_scan.erl:1601-1625` (`scan_qatom` builds `{atom,Anno,A}` from any characters). `'Shop':'New'(1)`
  needs nothing (p01). `erl_lint.erl:642` lists the predefined `module_info/0,1` any alias must avoid.
- **Elixir.** No `.ex`/tokenizer source is installed (beams only), so there is **no file:line**; the
  evidence is behavioural: parser text in E4, quoted calls in E3, xref in E5. The parser treats `.Name`
  as an alias token (E4) and offers quoted calls (`Mod."Fun"(args)`) for exactly this case (E3).
- **Gleam.** No compiler source installed; evidence is the generated `.erl` and the compiler's own error
  text (E7-E9). Gleam never has a PascalCase function; its only case-to-snake rule is on constructors,
  over an alphabet with no underscore, and is per capital (`h_t_t_p_get`).
- **C# / F# naming interop.** `dotnet` is not installed: **not measured**, nothing asserted.
  (Elm targets JS, not BEAM: not relevant, not run.)

## 4. Measurements

All from the patched compiler (`BS_ALIAS=none|thin|thin_nospec|dup`; `thin` = `snake(A..) -> 'Pascal'(A..)`
plus a copied `-spec`; `dup` = the function's clauses duplicated under the alias name). Test modules are
`N` public two-clause functions with a boundary guard (`gen_sz.sh`); the corpus run uses the repo's real
examples. `-spec` and debug info live in the `Dbgi` chunk because `bsc` compiles with `debug_info`
(`bsc.erl:843`).

**Size and export table** (`p08`, `p08b`; bytes, deterministic):

| N public fns | none | thin | thin, no alias spec | dup | exports (none → alias) |
|---|---|---|---|---|---|
| 1 | 1240 (382 stripped) | 1332 (407) | 1328 (407) | 1348 (417) | 4 → 5 |
| 10 | 2944 (831) | 3584 (1017) | 3548 (1017) | 3952 (1077) | 13 → 23 |
| 100 | 20648 (5040) | 26980 (6905) | 26584 (6905) | 31176 (7410) | 103 → 203 |

At N=100 thin adds **63 B/function** (+30.7%; +37.0% stripped), dup **105 B/function** (+51%). The growth is
`AtU8` (+18 B/alias for the alias atom: 1553 → 3336), `ExpT` (+12 B/export: 1240 → 2440), `Code` (+17 B,
thin; +55 B, dup) and `Dbgi` (+16.5 B thin with spec, +12.5 B without: the spec copy costs ~4 B/alias
after compression). Export count is exactly `2×public + 3` (`module_info/0,1` and `bs@type_atoms/0`):
ticket candidate 2's "two exports per function" **holds**.
**Real corpus** (22 beams from `compiler/examples`, small bodies): none 45,980 B, thin 50,804 (**+10.5%**),
dup 53,140 (+15.6%); stripped 13,285 → 14,733 (+10.9%) → 15,554 (+17.1%). `Counter` (all public functions
are callbacks) is unchanged. Thin is cheaper than dup on every module except `Label` (stripped).

**Load time** (`p11`; `erlang:prepare_loading` timed, purge outside; R=3 rounds × 150 loads, fresh VM per
cell; `none2` is a byte-identical second copy of the baseline, the noise floor): at N=100, median µs:
none 507-570, none2 522-557, **thin 709-720 (+~150, +27%)**, **dup 1025-1041 (+~500, +90%)**. At N=10: none
139-143, thin 147-160, dup 190-203: thin is inside noise, dup is not. At N=1 nothing separates. `finish_loading`
is a ~2-3 ms fixed cost with ±0.5 ms spread: no difference resolvable there. Disk read, release boot and
`code:atomic_load` were not measured.

**Call cost** (`p10`; `Sz10:'ScoreAt1Value'(5)` vs `Sz10:score_at1_value(5)` through a literal remote call;
20 M calls per timed run, min of 3, 9 interleaved rounds, two loop copies per target so placement bias
cancels; the `none` row, where "snake" is the same Pascal function, is the null control). Per-iteration
cost is ~6-7 ns, loop overhead ~5 ns. Effect = snake minus Pascal, ns/call:

| attempt | null (none) median [min..max] | thin | dup |
|---|---|---|---|
| gated attempt (spread 0.88 ns, passed) | 0.03 [-0.09..0.79] | **1.42 [0.92..1.81]** | 0.77 [0.39..1.11] |
| earlier clean run | 0.00 [-0.23..0.26] | 1.40 [1.15..1.81] | 0.79 [0.55..1.08] |
| attempts 1 and 2 of the final script | spread 2.69 / 1.25: gate failed | 1.48 / 1.21 | 0.91 / 0.76 |
| first run.sh run on a busy host | -0.34 [-1.74..2.23] | 1.85 [-0.06..4.09] | 1.57 [0.57..7.36] |

Reading: **thin ≈ +1.2 to +1.5 ns per call**, above the null spread in the two clean runs (a jump through
`call_only`, E15). dup's ≈ +0.8 ns is above the null in one clean run and inside it in the other, and I
did not isolate its cause (code placement is the likely one); do not read it as real. The busy-host run
could resolve neither and is kept (`out/p10_run1_noisy_in_run_sh.out`) rather than hidden. JIT only
(`emu_flavor=jit`); no interpreter build measured. Against a real Elixir caller's work this is below
anything else on the call path, but it is not zero.

**`.api` / `-spec`**: `bsc --api` unchanged (E17). Dialyzer/ElixirLS read `-spec`, and with `thin` they see
the alias typed (E17); with `thin_nospec` they see only the Pascal name.

## 5. Options

Same B# source in A and B; C changes one line.

### Option A — accept as is, correct §12, document the two spellings

```csharp
module Shop

record Order { Id: int, Total: int }

public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```

```elixir
:Shop."New"(1)                              # works, compile-time checked (E3, E5)
:Shop.New(1)                                # unexpected ( after alias New (E4)
defmodule MyApp.Shop do                     # a snake_case facade, one line per function (E6)
  defdelegate new(id), to: :Shop, as: :New
end
```

*Compiler delta*: none. *Spec delta*: LANGUAGE.md §12 lines 3128-3131 say `:Shop.New(1)  # SyntaxError ...`
and `apply(:Shop, :New, [1])  # the way in`, and "costs Elixir its call syntax"; owed a correction naming
`:Shop."New"(1)` and the facade, plus the callback exception (E18). *Cost to callers*: two quote marks per
call; no unqualified calls (`import` cannot help, E3); no `&:Shop.New/1` (use `&:Shop."New"/1`).
**Strongest counterargument:** every Elixir call site and every code review carries quotes that look like
a mistake to a reader who does not know why, Elixir 1.19 *warns* when quotes are not needed so a team
cannot cargo-cult them, and the "adopt B# incrementally inside an Elixir codebase" story the ticket names
as the likeliest way in now depends on each adopter writing a facade (or quoted calls) by hand.

### Option B — emit a derived snake_case alias for every `public` function

Same B# source. Elixir: `:Shop.new(1)`, `&:Shop.new/1`, `import :Shop, only: [new: 1]; new(1)` (E11); Erlang
keeps `'Shop':'New'(1)`.

*Compiler delta (built in the patch, 95-line `bs_alias.erl` plus a 3-line hook `forms(M) -> bs_alias:add(forms0(M))`
in `bs_emit.erl:30`)*: after `bs_emit:forms/1` builds the form list, for each exported `{N,A}` that is not
`bs@…`, compute `snake(N)`; emit `snake(A1..An) -> 'N'(A1..An).`, add `{snake,A}` to the `export`
attribute, and copy the `-spec`. Rule S: boundary before an uppercase that follows a lowercase letter or
digit, or that ends an acronym; `_` kept; lowercase. Measured cost: §4 (thin: +10.5% beam on the corpus,
+63 B/function, +~150 µs load at N=100, +~1.4 ns/call, crash frames name the Pascal function).
*Not built, and owed*: a collision **diagnostic** instead of a crash (E12: `FooBar`/`Foo_Bar`/`FooBAR`,
`HttpGet`/`HTTPGet`); a reserved list (`module_info`, and every name in `bs_otp`'s callback tables, E13,
or an alias makes `Init/1` a live `gen_server` callback in a module that never said `behaviour`); a gate
with `--self-test`; ticket 32/35's sentence "no snake_case ⇄ PascalCase rule anywhere" amended to "no
*inbound* rule"; §12 rewritten; tests in an F-file. Gleam's rule (`h_t_t_p_get`) is the wrong thing to
copy: it is unreadable on acronyms and injective only because Gleam forbids `_`, which B# does not.
**Strongest counterargument:** it buys one thing, *unquoted* `:Shop.new(1)` and unqualified calls after
`import`, and Elixir can already call every export (E3) or wrap it in one line (E6); in exchange the
language gets its first name-mapping rule (reversing ticket 32's stated stance for the outbound
direction), a collision class the grammar permits and the corpus never exercises (E14), a callback-capture
hazard (E13), a doubled export surface in every `module_info`, `xref` and Dialyzer listing, and 10% more
beam on every module whether or not any Elixir code ever calls it.

### Option C — the author writes the foreign spelling, per function (opt-in, no derivation)

```csharp
module Shop

public Order New(int id) as :new        // PLACEHOLDER syntax; not designed here
New(id) -> Order{ Id = id, Total = 0 }

public Order Pay(Order o)               // no `as`: no alias, Erlang and quoted Elixir only
```

This mirrors what ticket 32 decided for the inbound direction (*"both spellings are written: the Erlang
atom in quotes, the beam-sharp name in the declaration"*). *Compiler delta*: one grammar production and one
`#fn` field in `bs_parser.yrl`/`bs_check.erl:41`; emission identical to B's thin alias but only for marked
functions (the 4-line alias form in `bs_alias.erl`); the collision check stays (two authors' spellings can
still clash, and the author may write `init`), but it is over names the author chose, so the diagnostic can
name both. No derivation rule, no acronym/underscore/digit cases, size cost proportional to what is marked.
*Not measured*: parser cost, and any grammar/ambiguity effect of a trailing `as`. **Strongest
counterargument:** it is new surface for something Elixir callers can already do themselves (E6), it puts a
foreign-caller concern into every signature a library author wants callable (read cost on every signature,
ticket 32's standing "write cost is near-free, read cost is not"), and the author must choose and keep
consistent a snake_case name per function, which is exactly the mechanical step B automates.

## 6. Recommendation

**Option A**, with the §12 correction. The ticket weighed B against "callers use `apply/3`". That
comparison was wrong: quoted calls work and are checked (E3, E5), and a facade is one line per function
and needs nothing from B# (E6). What remains for B is unquoted call syntax and `import`, bought with the
first mapping rule in the language, an unprotected collision class, a callback-name hazard (E13) and a
measurable cost on every module (§4), none of it driven by a program in the corpus (E14). If an adopter
later shows unquoted names matter, C is the next step, because it mirrors ticket 32 and avoids the
derivation question; B's all-public derivation is the one I would not start with. This is a recommendation;
the choice is yours.

## 7. What I could not verify

- **C# / F#** naming interop: no `dotnet`. Not measured.
- **Elixir and Gleam compiler sources**: not installed; no file:line for either. Elixir behaviour is from
  real parser/compiler output; Gleam's from generated Erlang and error text.
- **62a's Gleam block as written**: needs `hex.pm` (blocked); only the no-deps redo (E7-E9) ran.
- **Dialyzer** was not run; "Dialyzer sees the alias spec" is inferred from `-spec` presence (E17), not
  from a Dialyzer run. **IEx/ElixirLS tab-completion** of aliases: not measured (my first attempt measured
  nothing and was removed, CHANGELOG).
- **Option C**'s parser cost and syntax: not built.
- The patch implements aliases at the Erlang-forms level in `bs_emit`; a real implementation might
  place the collision check in `bs_check` with a `bs_diag` message. Collision *diagnostic quality* is not
  evaluated; the patch crashes.
- **Timing** is one shared 4-core VM, OTP 28 JIT only. Call-cost differences are ~1 ns and needed a noise
  gate plus retries to resolve (one earlier run could not, and is kept). dup's call-cost effect is
  unresolved. Load-time `finish_loading`, disk read and `code:atomic_load` are not measured.
- **Sizes** use two-clause one-liner functions (the best case for dup) and small example bodies; large
  real modules would widen the dup/thin gap.
- The `Kind`-tag / struct friction (ticket §2, §3) is unchanged by every option and was not re-measured
  beyond E1.
