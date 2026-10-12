# Decision brief: ticket 62, the outbound ABI (ENG-252)

**Status: DRAFT FOR HUMAN REVIEW — ticket remains open.** Nothing in the repo was edited except `artifacts/`.
Toolchain: OTP 28, Elixir 1.18.5, gleam 1.19.0 (ticket measured 1.18.1), bsc built from the working tree.
Probes: `artifacts/probes/62-NN/{run.sh,out.txt}`; every `out.txt` is from an actual run.

## 0. Headline: the ticket's premise is stale

The ticket (and `LANGUAGE.md` §12) say a PascalCase export is un-callable with Elixir dot syntax and
`apply/3` is "the way in". **That is false.** Elixir's *quoted-call* form calls it with dot syntax and
no `apply` (62-01/out.txt):

```
:Shop."New"(1)    -> {:ok, %{Kind: :"Shop.Order", Total: 0, Id: 1}}
:Shop.'New'(1)    -> same
2 |> :Shop."New"()          # pipes
&:Shop."New"/1              # captures, works in Enum.map (62-02/out.txt)
```

The ticket's six measured spellings are all **confirmed** (re-run, 62-00): `:Shop.New(1)`,
`:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)`, `:"Elixir.Shop".New(1)` are SYNTAX_ERROR;
`:"BSharp.Shop".new(1)` parses; `apply(:Shop,:New,[1])` runs. The *prefix* verdict stands
(no module prefix helps). What the ticket missed is that the **function-name quoting** helps.

Other deltas against the ticket: (1) every module now also exports `bs@type_atoms/0` (ticket 87;
62-00 export list); (2) the prototype's Gleam step now fails *here* only because `gleam new` adds a
`gleam_stdlib` dep and hex.pm is blocked, not a regression (62-00 step 4); (3) the Gleam call that
"was not run" now **was run** and works (62-03); (4) the ticket's "Gleam downcases PascalCase" precedent
is true only for *constructors/atoms*, never for function names (section 3).

## 1. Sub-decisions and the gating one

1. Casing of exported function names (the only open item).
2. If aliases: derivation rule vs author-written name; collision policy.
3. Whether `LANGUAGE.md` §12 should teach `apply` or the quoted call (follows from 1).

Prefix question and Kind-contract documentation: settled in the ticket, **not contradicted** by any probe.

**Gating question, alone:** *Is Elixir's quoted-call spelling `:Shop."New"(1)` an acceptable outbound
story, or must B# also export a name Elixir can write as `:Shop.new(1)`?* Everything else (rule,
collisions, spec duplication) exists only if the answer is "must".

## 2. How the Elixir spelling works (parser-level evidence)

Sources fetched from github tag v1.18.5 (the install ships only `.beam`; `/nix/store/pp8k.../lib/elixir`
has no `src/`), saved to `probes/62-01/exsrc/`, lines quoted from the fetched files:

- `elixir_tokenizer.erl:1226-1228` — `tokenize([H|T]) when ?is_upcase(H) -> ... {alias, ...}`: a leading
  capital makes an *alias* token, so `.New` is `dot_alias`.
- `elixir_tokenizer.erl:1381-1384` — `handle_terminator(... {'(' ...}, [{alias,_,Alias}|Tokens])` raises
  "unexpected ( after alias New. Function names ... start with lowercase" (this is the exact SYNTAX_ERROR text in 62-01).
- `elixir_parser.yrl:470-471` — `dot_alias -> matched_expr dot_op alias`; calls are only
  `dot_paren_identifier` (`yrl:484-485`), never `dot_alias`.
- `elixir_tokenizer.erl:912` — `handle_dot([$., H | T] ...) when ?is_quote(H)`: after a `.`, a quoted
  string is tokenized as a call (`check_call_identifier`, line 933) — the rescue. 62-02's token dump
  shows `{paren_identifier,{1,7,34},'New'}` for `:Shop."New"(1)` vs `{error, "unexpected ( after alias New"}`.

Elixir's own compiler endorses it: calling `Shop."New"(1)` (wrong module atom) warns
`Did you mean: * :Shop."New"/1` (62-02/out.txt). `Code.format_string!` keeps `:Shop."New"(1)` and
rewrites `'New'` to `"New"`. No warning is emitted for the quoted call.

Traps measured: `Shop."New"(1)` resolves `Shop` as alias `Elixir.Shop`, i.e. **not** B#'s atom `Shop`
(UndefinedFunctionError, 62-01); `&:Shop.New/1` is SYNTAX_ERROR but `&:Shop."New"/1` works;
`m = :Shop; m.New(1)` fails, `m."New"(1)` works. The Elixir-written equivalent is routine:
`def unquote(:New)(x)` compiles, Erlang calls it, Elixir calls it only quoted (62-05).
OTP ships PascalCase exports today (`diameter_types:'OctetString'/3` at
`diameter-2.6.1.2/src/base/diameter_types.erl:32`, 14 of them); Elixir reaches them only via
`:diameter_types."Unsigned32"(:encode, 7, %{})` (62-09). So the Elixir ecosystem already has this idiom.

## 3. Neighbour languages

| Language | Function-name rule | Evidence |
|---|---|---|
| Erlang | any quoted atom; `-export(['New'/1])` fine; Elixir calls it with the quoted form | 62-05; diameter_types.erl:32 |
| Elixir | can *define* `def unquote(:New)`, `def unquote(:"weird name")`; cannot call them unquoted | 62-05 |
| Gleam | **rejects** `GetById` ("expecting a lowercase name") and `getById` ("Try: get_by_id"); even an `@external` binding must be snake_case on the Gleam side; the foreign name is a string, so PascalCase foreign names are fine | 62-04 B, 62-03 |
| Gleam module path | `deep/nested` -> file `deep@nested.beam`; entry `demo@@main` | 62-04 A2 |
| Gleam *constructors* | PascalCase -> snake_case atom: `RightTriangle(1,2)` = `{right_triangle,1,2}`; **`HTTPError` = `h_t_t_p_error`** | 62-04 A3 |
| Elm | compiles to JS, not BEAM; not probed: `elm make` needs `elm/core` from the package server (blocked) | 62-08 |
| C#/F# | *knowledge only*: .NET exports PascalCase and callers across languages use it as written; no alias convention | not probed |

The ticket's "Gleam downcases when it emits" (ticket 10 line 335) is about **type constructors** (grep'd at
`wayfinder/issues/10-atoms-in-a-csharp-skin.md:335`: "PascalCase to snake_case" for variants). Gleam never
converts a function name; it forbids the shape. So there is no neighbouring precedent for deriving a
function alias, and the one derivation Gleam does ship is non-injective-looking and ugly on acronyms.

Grep'd decisions this touches: ticket 32 (`32-ffi-surface.md:204`) decided *"There is no snake_case <->
PascalCase rule anywhere in the language"*, on **inbound** evidence ('PKCS-1' cannot be spelled). Outbound
the spellability objection does not apply (every B# identifier maps), but the *decision text* is
language-wide, so option B must say it is a deliberate carve-out. `bs_otp.erl:7-9` repeats it in the
compiler: "These are tables, not a naming rule."

## 4. Options

### Option A — accept PascalCase, document the quoted call (no compiler change)

```elixir
shop = :Shop."New"(1)                    # one call
orders = Enum.map(1..3, &:Shop."New"/1)  # capture
shop |> then(&:Shop."Pay"/1) ...         # captures work
:Shop."Which"(shop)                      # => :order
```
Erlang unchanged: `'Shop':'New'(1)`. Gleam: `@external(erlang, "Shop", "New")` (62-03 ran it:
`#{'Total'=>0,'Kind'=>'Shop.Order','Id'=>3}`, `order`, `42`).

**Compiler delta: none.** Doc delta: `LANGUAGE.md` §12 "Function names" paragraph replaces `apply(...)
# the way in` with the quoted call (and keeps `apply` as the dynamic fallback); the `:Shop.New(1)`
SYNTAX_ERROR line stays as the warning. Cost measured: zero bytes, zero compile time.

**Strongest counterargument:** a caller must know to quote *every* call; the natural spelling fails with
a parser error whose hint ("start with lowercase") points away from the fix, so the first-time adopter
inside an Elixir codebase still hits a wall (and `Shop."New"` with the Elixir alias looks right but
is silently the wrong module atom). Whether that hurts adoption is not measurable here.

### Option B — derived snake_case alias exports (`New` -> `new`)

```elixir
:Shop.new(1)          # parses and runs (62-10 section 1)
:Shop.which(shop)     # => :order
```
**Compiler delta** (prototype `62-06/alias.patch`, ~45 lines in `bs_emit.erl`, applied to a *copy*):
an `alias_table/3` beside the export list (`bs_emit.erl:76`), an `alias_forms/3` emitting per alias a
tail-calling wrapper `new(A1) -> 'New'(A1).` plus, optionally, a duplicated `-spec`; the `snake/1` rule
(lower->Upper inserts `_`; an acronym run splits before its last capital only when a lowercase follows:
`HTTPGet -> http_get`, `GetID -> get_id`). BEAM has no export aliasing, so a wrapper function is the only way.

Measured (62-06/out.txt; the "none" baseline is the patched compiler with `BS_ALIAS` unset, verified byte-identical to the unpatched one except the CInf chunk; 5-run load, 9-run compile; Shop output in 62-10):

| N public fns | .beam none | + aliases, no spec | + aliases, with spec | exports (none/alias) | ExpT chunk |
|---|---|---|---|---|---|
| 1 | 1008 B | 1100 (+9%) | 1104 | 4 / 5 | 52 -> 64 B |
| 10 | 1856 B | 2460 (+33%) | 2488 | 13 / 23 | 160 -> 280 B |
| 50 | 5740 B | 8696 (+51%) | 8844 (+54%) | 53 / 103 | 640 -> 1240 B |

~59 bytes per alias, ~3 bytes more per duplicated `-spec`. **Compile time** (bsc incl. VM start, N=50):
none min 420 / median 453 ms; no-spec 409 / 446; spec 405 / 446 — indistinguishable. **Load time**
(`code:load_binary`, median of 5x500): 3.0-3.6 ms in every cell, no trend (dominated by purge/delete).
**Call cost** of alias vs direct, 2M remote calls: only one run is recorded (direct 92.7 ms, alias 126.0 ms); the verifier's re-run
gave 90.8 vs 105.6 ms. The alias was slower in every recorded run; the size of the wrapper's cost is unresolved (verification/62.md). **Dialyzer** (erts-only PLT, G50): "passed successfully"
in all three modes, 0.08-0.13 s analysis; spec duplication is not a problem, but this tests a trivial module.

Collision behaviour (62-10 sections 2-3): `GetId` and `GetID` both derive `get_id`; the prototype keeps the
first and prints `alias-collision get_id/1 ('GetID')`, so `get_id(1)` silently returned 2, not 3. A real
implementation must error. In a `behaviour GenServer` module `Init/HandleCall/HandleCast` already lower to
`init/handle_call/handle_cast` (`bs_otp.erl:40-44`), so their aliases collide with the lowered names and
must be skipped. **Corpus** (62-07/out.txt): 121 module files, 111 modules, 233 public function declarations
by regex (undercount: 263 `^public` lines, files without a `module` line skipped — these are the 30 public declarations in `compiler/examples/exemplars/25a`–`25g`; including them still gives 0 collisions, and adds more callback-named functions such as `Init` and `HandleCall`), 147 distinct names;
**0 derived-name collisions**; 0 names with an acronym run or digits; 129 of 147 are single words (alias = lowercase).
Two modules (`Counter`, `Req`) contain callback-named functions that need the skip rule. Zero collisions
reflects a corpus that has never needed an acronym, not that the rule is safe.

**Strongest counterargument:** it reverses, outbound, a decision recorded as language-wide
(`32-ffi-surface.md:204`), doubles the public export surface forever (Erlang tooling, xref and docs see
`New` and `new`), makes the alias name a de facto ABI (renaming `GetById` breaks two spellings), and the
rule has an acronym edge (`GetID` vs `GetId`) that Gleam itself gets wrong (`h_t_t_p_error`). And Option A
already makes dot syntax possible.

### Option C — author-written alias per function (opt-in)

Same emitted cost per alias as B (wrappers measured above), no derivation rule, no collisions the author
did not write, matches ticket 32's "both spellings are written" principle. **Syntax is undesigned** (I did not
probe or grep for an attribute form; do not read this as measured). Compiler delta: a declaration form, a
symbol-table entry for the alias, a duplicate-name diagnostic. **Strongest counterargument:** every
exported function in an Elixir-facing module needs a second hand-written name — it adds a language construct
to avoid typing quotes. "Change the convention to snake_case functions" (the ticket's third candidate) is
not costed: `32-ffi-surface.md:196-198` records that the casing rule reads `Ets.Lookup` as a call
*because both segments are uppercase* and a lowercase name "would have lexed as a field projection", so it
collides with the record-dot design, not just taste.

## 5. Recommendation

**Option A now: document the quoted call and delete the claim that Elixir cannot dot-call B#.** Reasons:
(1) the problem the ticket set out to fix is solved by the language already, at zero cost; (2) Option B
reverses a recorded language-wide decision for an ergonomic gain over a spelling that is already
formatter-stable, capturable and pipeable; (3) B's one measured hazard (acronym collisions; callback-name
clashes) is real work, while its size cost is modest (+59 B per alias) and compile/load cost is not
visible. Revisit B or C if an actual Elixir adopter's code shows the quoting is the blocker. If B is ever
chosen, require an error on derived-name collision and skip callback-lowered names.

This is a recommendation, not a decision; the ticket stays open and no `LANGUAGE.md` text was changed.
`LANGUAGE.md` §12 currently says `apply(:Shop, :New, [1])    # the way in` and, at the end of that
subsection, that the casing is open: both statements need review whichever option is chosen.

## 6. Not decided / not measured

- Whether quoted calls deter real adoption (no adopter data); C#/F# claims are knowledge only.
- Elm (`62-08`): the toolchain cannot fetch `elm/core`, so no run; irrelevant to the BEAM anyway.
- Wrapper call cost: two runs disagree in sign, so no figure is claimed.
- Dialyzer on a realistic module with records; xref/doc tooling behaviour with duplicate exports.
- Option C syntax. How the quoted call interacts with Elixir macros, `mix xref`, LSP go-to-definition.
- Record/Kind contract (frictions 2 and 3): not re-opened. Re-run only to confirm the numbers (62-00: wrong
  tag and struct both `FunctionClauseError`).
- The Gleam probe uses `ERL_LIBS` pointing at a `lib/shop/ebin` directory; without it `gleam run`
  gives `undef Shop.New`. A real mixed project's wiring was not tried.
- The corpus regex is not the compiler's own export table (cross-check only for Shop: 8 names match).

## 7. Probe index

| Probe | Claim checked | Result |
|---|---|---|
| `62-00/run.sh` | ticket's prototype 62a, unmodified, on current toolchain | Elixir/Erlang results identical to ticket; new `bs@type_atoms/0` export; third module `Shop.Collections.Ints`; Gleam step fails only on blocked hex |
| `62-01/run.sh` | every Elixir spelling, AST and runtime | `:Shop.New(1)`, `Shop.New`, `:"Elixir.Shop".New`, `&:Shop.New/1`, `m.New(1)` = SYNTAX_ERROR; `:Shop."New"(1)`, `:Shop.'New'(1)`, `&:Shop."New"/1`, `apply`, `Kernel.apply`, `:erlang.apply`, `m."New"(1)` work; ticket's "Elixir calls `apply`, the way in" (LANGUAGE.md §12) is falsified; its prefix verdict stands |
| `62-02/run.sh` | quoted call in a compiled file: warnings, formatter, pipe, capture, tokens | works, no warning, formatter-stable; alias trap `Shop."New"` = wrong atom |
| `62-03/run.sh` | Gleam actually calls `@external(erlang,"Shop","New")` | RUN: prints map, `order`, `42`; `undef` without ERL_LIBS |
| `62-04/run.sh` | Gleam name rules, `@@`/`@` module naming, constructor snake-casing | `GetById`/`getById`/`HTTPGet` rejected; `deep@nested.beam`; `RightTriangle`->`right_triangle`, `HTTPError`->`h_t_t_p_error` |
| `62-05/run.sh` | Elixir `def unquote(:New)`, Erlang `-export(['New'/1])` | both compile; Erlang calls Elixir's; Elixir needs quoted call; `Weird.New(1)` = parse error |
| `62-06/run.sh` (+`alias.patch`, `measure.escript`) | alias cost: size, exports, compile, load, call, dialyzer | table in section 4B |
| `62-07/run.sh` (+`corpus.py`) | derived-name collisions across repo B# | 0 collisions, 147 names, 129 single-word |
| `62-08/run.sh` | Elm PascalCase function | cannot run (no `elm/core`, network); not evidence |
| `62-09/run.sh` | OTP's own PascalCase exports | 14 in `diameter_types`; callable only quoted |
| `62-10/run.sh` | alias prototype from Elixir; collisions; behaviour clash | `:Shop.new(7)` works; `GetId`/`GetID` silent collision; `init`/`handle_call` clash skipped |
