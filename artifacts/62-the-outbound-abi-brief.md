# Decision brief: ticket 62 (ENG-252), the outbound ABI, function-name casing

Prepared for a human decision. Nothing here is resolved, and nothing in `wayfinder/`, `compiler/` or Linear was touched.
Probes: `artifacts/probes/62/` (each `pN-*.sh` has its captured `pN-*.out`). Prototype patch: `artifacts/probes/62/alias-emit.diff`.
Environment: OTP 25.x, Elixir 1.14.0, scratch `bsc` (OTP 25 build, wrong diagnostic columns, semantics unchanged). **The repo pins OTP 28 and the ticket measured Elixir 1.19.5; neither was available.**

## 1. The question

What spelling of a B# function's name does an Erlang or Elixir caller see, given that B# functions are PascalCase by lexer construction (`UPPER ALNUM*`, `bs_lexer.xrl:150`)? The ticket's three candidates are: accept, emit snake_case aliases alongside, or change the B# convention.

## 2. Stale premises (read these first, they change the shape of the decision)

1. **"Elixir cannot call a PascalCase export" is false for the quoted form.** `:Shop."New"(1)` parses and runs on Elixir 1.14 (p1). It also works as `mod = :Shop; mod."New"(1)`, inside a compiled `defmodule`, as a capture `&:Shop."New"/1`, and in a pipe `1 |> :Shop."New"()`. `mix format` keeps the quotes (`Code.format_string!` leaves `:Shop."New"(1)` unchanged, p5 C). Only the unquoted `:Shop.New(1)` is a syntax error ("unexpected ( after alias New"). Ticket 62 §1 and `LANGUAGE.md` §12 (lines 3188-3191: "`apply(:Shop, :New, [1])  # the way in`") present `apply/3` as the only route. Not tested on Elixir 1.19, but the quoted-call form is old syntax, and it is the repo's claim being contradicted, not mine.
2. **The Gleam precedent is about something else.** Ticket 62 cites ticket 10 §7: Gleam "downcases PascalCase to snake_case when it emits to the BEAM". The sentence in `wayfinder/issues/10-atoms-in-a-csharp-skin.md:333-335` reads "Fieldless variants compile to atoms, variants with fields to tagged tuples, PascalCase to snake_case. The constructor *is* the declaration site." That is **constructor-to-atom-tag** (`Red` becomes `red`, `Circle(Float)` becomes `{circle, F}`), which `10c_gleam_forge.erl` exercises with `gleamprobe:describe(red)` and `area({circle, 2.0})`. Gleam *function* names are written lowercase in the source (`pub fn key_find`, `32a_gleam_external.gleam:4`; `pub fn lookup`, `18c_gleam_ffi_trust.gleam:44`), so there is no function-name downcasing for a precedent to rest on. **UNVERIFIED-NOT-EXECUTED** (Gleam is not installed and cannot be); the only repo-local evidence is the prototype sources above, and the generated `gleamprobe.erl` is not committed. So candidate 2's "a neighbouring BEAM language already ships this" is not established for functions.
3. **62a's Gleam line** (`@external(erlang, "Shop", "New")` compiles) is **UNVERIFIED-NOT-EXECUTED** here. The ticket itself says the call was not run. `62a_from_the_outside.sh` section 4 self-skips without gleam and no output is committed.
4. **62a's export listing is out of date.** The ticket's PascalCase export list omits `'bs@type_atoms'/0` (ticket 87, ENG-398), which every module now exports (p1 shows it). An alias set is therefore a *second* kind of compiler-added export, and `LANGUAGE.md` §12's "exported PascalCase, exactly as written" would need a second sentence.
5. **Ticket 32 already decided "there is no snake_case/PascalCase rule anywhere in the language"** (`32-ffi-surface.md` decisions entry, and `parser.yrl:167-169`: "nothing is renamed and no case mapping exists"). That was the inbound direction and its reason (a mapping cannot spell `'PKCS-1'` or `fetch!`) does not apply outbound, where the source alphabet is restricted. But candidate 2 as written *is* a case-mapping rule, so the ticket should say why outbound differs. **Ticket 35** is the nearest precedent: `bs_otp:callbacks/1` and `callback_name/3` rename `HandleCall/3` to `handle_call/3` from a fixed table, scoped by mechanism (a fixed callback table), not by a general naming rule (paraphrase; the earlier draft put a quotation here that does not occur in ticket 35).
6. Version note: 62a measured OTP 28 / Elixir 1.19.5 / gleam 1.18.1. Every number below is OTP 25 / Elixir 1.14.0.

## 3. Sub-decisions, in gating order

**G. Is idiomatic Elixir callability (dot syntax, `import :Shop`) a goal of the language, or is the contract just "a `.beam` with documented exports"?** Gates everything. If the contract is "documented exports", Option A suffices (the quoted form works) and the rest is moot. If Elixir ergonomics is a goal, then:

1. **Scope**: every public function (blanket) or per-function opt-in. Gated by G.
2. **Spelling**: derived by a rule, or written by the author. Gated by (1): a blanket scope needs a rule; opt-in does not.
3. **Collisions and skips**: what happens when two names map to one alias, or the alias equals an existing export. Gated by (2), and only exists under a rule.
4. **Clean-room cost**: the alias set is observable through `module_info(exports)`, so it becomes part of what an independent implementation must reproduce to agree with the oracle. Gated by (1).

## 4. What was measured

**Corpus (p2).** 27 of 35 module directories under `compiler/examples` compiled in the scratch build (8 failed: `Signalbox` internal error, and 7 `exemplars/25*` directories which, per their README, do not compile under the real compiler either, so these are not scratch-build artefacts). They export **94 public functions, 80 distinct names**. Under the simple rule R1 (insert `_` before each capital but the first, downcase) there are **0 collisions**. Three names alias to auto-imported BIFs (`Size`, `Now`, `Length`) and one to an operator word (`Band` becomes `band`). The real corpus has **no acronyms and no digits**, so it cannot discriminate between rules; that is why p3 uses synthetic names.

**Rule hazards (p3).** Three rules on synthetic names: R1 (insert `_`), R2 (acronym-aware), R3 (downcase first letter only, giving `hTTPServer`).
- R1 gives `HTTPServer` becomes `h_t_t_p_server`, `GetXML` becomes `get_x_m_l`. Ugly, but R1 is *almost* injective. **It is not injective: `XY` and `X_y` both become `x_y`** (p3, last two names; I added the pair after first run, so the pair was deliberately constructed, not found in any real code).
- R2 reads better (`http_server`, `get_xml`) but **collides on constructed pairs (none occurs in the 275 real names the verifier checked)**: `GetXML`/`GetXml`/`Get_Xml`, `ToJSON`/`ToJson`, `ParseURL`/`ParseUrl`, `FOO`/`Foo`, `AB`/`Ab`. Any such pair in one module would make the alias set ambiguous.
- R3 never collides, and is not snake_case.

**Reserved words and BIFs (p3).** Defining and exporting functions named `length`, `now`, `apply`, `spawn`, `node`, `self`, `send`, `exit`, `size` and the keywords `if end and not rem div fun case receive try after when of catch begin band` **compiles in Erlang** when nothing calls them unqualified. The control (a module that calls its own `length/1` unqualified) is refused: "ambiguous call of overridden pre R14 auto-imported BIF length/1". The emitted wrapper calls the PascalCase name, so it never trips that. Elixir parses every one of 38 such spellings as `:Shop.<name>(1)`, including `if`, `end`, `do`, `fn`, `nil`, `true`; and `:bifs.length([1,2,3])` reaches the module's function rather than `Kernel.length` (p3). Erlang callers must quote the keyword ones (`shop:and(1)` is a syntax error, `shop:'and'(1)` parses).

**Alias emission works (p4).** With the patch (`BS_ALIAS=wrap`): `:Shop.new(1)` returns the order map; `import :Shop, only: [new: 1]; new(2)` works; `module_info(:exports)` lists both `New: 1` and `new: 1`, the 8 author functions becoming 16 export entries, 19 in total with `bs@type_atoms`/0 and `module_info` (p4). Controls: the unpatched build raises `UndefinedFunctionError` for `:Shop.new(1)`, and `:Shop.nonexistent_alias(1)` raises in all builds. `import :Shop` cannot bring in the PascalCase originals (CompileError/SyntaxError, p1).

**Stack traces (p4).** A wrapper alias is a tail call, so a crash through `:Shop.which(bad)` is attributed to `examples/Shop/shop.bs:18: :Shop."Which"(...)`: the alias leaves no frame. A duplicated-body alias shows `:Shop.which(...)` as the frame, so one source function reports under two names depending on route.

**Dialyzer (p7).** With the alias carrying a copied `-spec`, a bad call through the alias gets the same contract-violation warning as the original. **With no spec on the alias the warning still fires but is weaker** ("differs in the 1st argument from the success typing") and loses the contract text. Control: unpatched build reports `Call to missing or unexported function 'Shop':new/1`. The correct call is silent in every variant.

**Cost (p6, OTP 25).** Synthetic modules of 5 and 200 public three-clause functions. `wrap` = alias is a one-clause local-call wrapper; `dup` = alias is a full copy of the clauses.

| | beam bytes | exports | compile ms (median, min-max, n=11, in-process) | load us (median of 10 VMs, min-max) |
|---|---|---|---|---|
| 5 fns, none | 1952 | 8 | 16.8 (14.4-35.1) | 705 (689-882) |
| 5 fns, wrap | 2228 (+14%) | 13 | 22.8 (16.6-28.2) | 726 (703-784) |
| 5 fns, dup | 2456 (+26%) | 13 | 27.3 (19.6-53.3) | 778 (468-1052) |
| 200 fns, none | 38980 | 203 | 297.8 (266-399) | 2522 (2410-2992) |
| 200 fns, wrap | 49476 (+27%) | 403 | 413.1 (331-577) | 3129 (2824-4726) |
| 200 fns, dup | 60008 (+54%) | 403 | 646.9 (489-862) | 4885 (4322-7520) |

At 5 functions the wrap deltas on compile and load sit inside the run-to-run spread. **At 200 functions the percentages are not stable:** the verifier's two re-runs gave compile +52% and +38% (author +39%) and load +10% and +19% (author +24%), and in one re-run the load ranges overlapped. Read the 200-function cost as roughly 'compile +40–50%, load +10–25%, beam +27%'; only the beam size is deterministic. The Erlang compile step alone is about +40%. Call overhead, 5M calls per run, 10 fresh VMs: direct PascalCase 17.7 ns (16.7-21.1) and 18.3 ns on the unpatched build, wrapper alias 18.9 ns (17.7-20.8), duplicated alias 18.4 ns (17.2-24.9). **Below noise**: the spread between runs is larger than any difference between rows. (No slower-path control was run in the call test; the script originally said it had one, I corrected the label.) The compiler pipeline timing includes the cost of `erlc` handling twice the functions; I did not separate B# front-end time from the Erlang compile step.

**Neighbours (p5).**
- Elixir stdlib: `Enum` 76 names, 4 end in `?`, 1 in `!`; none upper-initial. Elixir exports `?`/`!` names as plain atoms (`:all?`, `:fetch!`). `Kernel` has 59 upper-initial exports, but they are `MACRO-` internal names and operators, not API.
- Erlang/OTP 25: 1118 beams, 37,611 exported names. **5 upper-initial exports in total, all in `wx`** (`wxWindow:'Destroy'`, `wxMenu:'Destroy'`, `wxImage:'Destroy'`, `wxRegion:'Xor'` twice). Another 19,072 contain an uppercase letter *inside* (`zlib:deflateInit`, `crypto:macN`, the `snmp_*` and `wx*` families): camelCase is common, but a lowercase initial keeps it callable. Control: a module with `'New'/1` and `'_x'/0` is correctly listed by the scan. So an upper-initial export is rare in the Erlang world, and the one library that has them (wx) is a binding to a C++ API, which is B#'s own situation in reverse.

## 5. Options

### Option A: accept, document the quoted form

```csharp
module Shop
record Order { Id: int, Total: int }
public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```

```elixir
order = :Shop."New"(1)                 # parses and runs, Elixir 1.14 (p1)
orders = Enum.map(1..3, &:Shop."New"/1)
1 |> :Shop."New"() |> :Shop."Pay"()
```

```erlang
Order = 'Shop':'New'(1).
```

**Compiler delta: none.** Doc delta: `LANGUAGE.md` §12 lines 3188-3191 replace "`apply(:Shop, :New, [1])  # the way in`" with the quoted call, and say `import :Shop` cannot bind the names. Ticket 62 §1 gets a correction.

**Strongest counterargument.** It still reads as foreign: `:Shop."New"(1)` is neither `Shop.new(1)` nor an alias, there is no `import :Shop` route (bare `New(1)` is a syntax error after import, p1), and an Elixir team adopting B# module by module will see quotes at every call site. The quoted form is also something nobody has put in front of a real Elixir codebase; I only showed it parses and runs.

### Option B: the author writes the Elixir-facing spelling, per function

Illustrative surface only (my spelling, not decided; compare ticket 32's "the declaration carries both spellings"):

```csharp
module Shop
record Order { Id: int, Total: int }

[export: "new"]                      // hypothetical: one more name for an exported function
public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }

public Order Pay(Order o)            // no attribute: Erlang/B# name only
Pay(o) -> o with { Total = 500 }
```

```elixir
order = :Shop.new(1)                 # works (p4 patch demonstrates the emission)
:Shop."Pay"(order)                   # the one the author did not alias
```

**Compiler delta.** (1) One grammar production for the attribute and a place on the `#fn` record. (2) A check in `bs_check`: alias is a valid lowercase atom name, not equal to any export or callback-renamed name of the same arity, not duplicated, and not starting with `bs@`. (3) `bs_emit`: append the alias to the export list and emit the one-clause wrapper plus a copied `-spec`; the prototype `alias_post/1` in `alias-emit.diff` is about 45 lines and already does the emission, minus the derivation. (4) `--api` and the REPL's `:exports` decide whether to show the alias (not probed). (5) A scenario row in the features doc and a gate that emits the alias and fails when it is missing. Cost per aliased function is the wrap row above.

**Strongest counterargument.** It is surface area for a benefit that only some functions need, and the author writes every name twice, which is exactly the ceremony ticket 32 priced as "write cost, near-free". Worse for the clean-room goal: a new attribute is a new thing the spec owes and every alternative implementation must reproduce, and nothing in the repo yet shows a caller who needs it.

### Option C: blanket derived alias (the ticket's candidate 2)

```csharp
module Shop
public Order New(int id)            // exports 'New'/1 and new/1
public int ParseURL(binary s)       // exports 'ParseURL'/1 and parse_u_r_l/1 under R1
```

```elixir
:Shop.new(1)
:Shop.parse_u_r_l("x")              # R1; R2 would give parse_url but collides, see p3
```

**Compiler delta.** The rule, one function in `bs_emit` (R1 is 6 lines in the prototype), plus: skip when the alias equals the name (callbacks such as `handle_call`, `init`); skip names starting `bs@`; skip when the alias is already an export (the prototype keeps first-writer-wins); a **diagnostic** for collisions, because R1 collides on `XY` vs `X_y` and R2 on `GetXML` vs `GetXml`. Wrapper emission as Option B. Every public function pays the wrap cost.

**Strongest counterargument.** It is the one option that contradicts a settled decision: ticket 32's "no snake_case/PascalCase rule anywhere in the language" and the parser comment "no case mapping exists". The Gleam precedent offered for it is, as far as the repo shows, about constructor tags, not function names (stale premise 2). Measured, it doubles the export table (203 to 403 at 200 functions), adds about 27% to the beam and about 24% to load time at 200 functions (3129 vs 2522 us, ranges 2824-4726 vs 2410-2992), roughly 39% to compile time in this pipeline, and a rule that reads well (R2) is ambiguous while the rule that never collides (R3) isn't snake_case, with R1 failing on a contrived but legal pair.

### Not offered as an option

Changing B#'s own convention to snake_case functions (candidate 3): `uident` is the lexer's only way to tell a call from a field projection (ticket 26's casing rule, ticket 32 §2) and ticket 35 settled that function names are PascalCase (ticket 35:237 says the callback rename is justified "on *mechanism* rather than preference"). Nothing measured here argues for reopening it.

## 6. Recommendation (the human decides)

**Option A now, with the doc correction, and defer B until a concrete Elixir adopter exists.** The ticket's own motivation, "awkward to adopt incrementally inside an existing Elixir codebase", rests on `apply/3` being the only way in, and that is false (stale premise 1). The remaining awkwardness is real but small, and every alias option adds an observable export set the clean-room spec must pin down and a second spelling in stack-trace and `module_info` output. If David decides Elixir dot-syntax with lowercase names is a goal (sub-decision G), choose **B over C**: it is consistent with 32 and 35 (author-written, no rule), it has no collision problem, and the emission cost is paid only where wanted.

Cheapest next step regardless of choice: have someone with Elixir 1.19 re-run `p1-elixir-call.sh` to confirm the quoted form there.

## 7. Not measured / could not run

- Gleam: nothing executed. Both Gleam claims (function-name downcasing; `@external(erlang, "Shop", "New")` compiles) are **UNVERIFIED-NOT-EXECUTED** (sources: ticket 62 and `10-atoms-in-a-csharp-skin.md:334-336`, `62a_from_the_outside.sh` section 4).
- Everything on OTP 28 and Elixir 1.19.x. All numbers are OTP 25 / Elixir 1.14.0, scratch `bsc` build.
- 8 of 35 example directories did not compile in the scratch build, so the corpus is 27 modules.
- The alias patch is a prototype by environment variable (`BS_ALIAS`), not a compiler design; the surface for Option B is my illustration.
- `bsc --api`, `ibs :exports`, `-on_load`/hot-upgrade interaction, and Dialyzer on a full PLT (only erts/kernel/stdlib) were not examined.
- Compile-time delta mixes B# front-end work with the Erlang compile step; I did not separate them. Compile times in the 200-function rows had wide spread (e.g. 331-577 ms).
- Real-world Elixir usage of quoted-name calls (how annoying it is in practice) is not measured; only that it parses, formats and runs.
- IEx autocomplete and ExDoc behaviour with PascalCase exports: my autocomplete probe was malformed and I report no claim from it.
