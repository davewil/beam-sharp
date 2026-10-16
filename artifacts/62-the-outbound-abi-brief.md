# Decision brief — ticket 62: what B# looks like from the outside (function-name casing)

**Linear**: [ENG-252](https://linear.app/davewil/issue/ENG-252) · **Ticket file**: `wayfinder/issues/62-the-outbound-abi.md`
**State**: OPEN. This brief resolves nothing. **Independent verification**: `artifacts/verification/62-verifier.md`.

The ticket's `Kind`-tag question is already answered (`LANGUAGE.md:3274`, "Being called from Erlang and Elixir"); the module-prefix question is answered and closed.
What remains is **function-name casing**: B# exports `'New'/1`, and Elixir cannot parse `:Shop.New(1)`.

## The question, as a program

```elixir
# Elixir calling the emitted examples/Shop beam
:Shop.New(1)                      # SYNTAX_ERROR
:Shop."New"(1)                    # %{Kind: :"Shop.Order", Id: 1, Total: 0}      <- the ticket does not mention this
apply(:Shop, :New, [1])           # same
```

## Sub-decisions

1. Is the PascalCase export a defect to fix, or a spelling to document?
2. If aliases: derived by rule, or declared per function?
3. What do aliases cost, and what do they collide with?

## Findings (executed; `probes/62/`)

- **Correction to the ticket**: Elixir has a quoted-call form, `:Shop."New"(1)`, which parses and runs against the **real** `bsc`-emitted `examples/Shop` beam
  (`p3_real_beams.exs`, `p3_result.txt`; Elixir 1.19.5 on OTP 28.0; the same call parses on Elixir 1.14, `p1_elixir_parse.exs`). The ticket lists only `apply/3` as the workaround
  and calls option 1 "awkward"; it is awkward, not impossible, and needs no `apply`. The three rejected spellings (`:Shop.New`, `:"BSharp.Shop".New`, `:"Elixir.Shop".New`) are re-confirmed as syntax errors
  (the Elixir tokenizer rejects `( after alias New`, `elixir/lib/elixir/src/elixir_tokenizer.erl:1384`).
- A B# record argument works as a plain tagged map (`:Shop."Which"(%{Kind: :"Shop.Order", …})` → `:order`); an Elixir struct raises `FunctionClauseError` (as documented).
- **Gleam**: `@external(erlang, "Shop", "New")` compiles and the call runs (`g.call()` → `{ok,1}` against a stand-in module, `p2_gleam_emitted.erl.txt` shows `'Shop':'New'(A)`).
- **Gleam does not downcase functions.** The ticket (via 10 §7) cites Gleam as precedent that "PascalCase becomes snake_case" when emitting to the BEAM. Executed: `pub type Shape { RoundThing(Int) }` emits `{round_thing, 1}`
  (`probes/62/p2_gleam_emitted.erl.txt`); the conversion is `to_snake_case` applied to **record and constructor names** (`gleam/compiler-core/src/erlang.rs:132` and `:383`). Gleam functions are authored in snake_case and emitted unchanged, and Gleam emits **one** export per function.
  So the precedent covers type constructors, not the alias-export candidate.
- **B# already declined a derivation rule**: `compiler/src/bs_otp.erl:7-8`: *"A snake_case<->PascalCase derivation cannot spell `'PKCS-1'` or `'OTP-PKIX'`, so the language has no such rule"*
  (F10). Callback names (`HandleCall` → `handle_call`) are a hand-written table.

## Options

### Option 1 — accept the PascalCase export; document the quoted call

No compiler delta. `LANGUAGE.md` §12 gains the line `:Shop."New"(1)` and nothing else. Evidence: the call runs today.
*Strongest counterargument:* every Elixir call site carries quotes, which reads as a foreign-language tax, and it makes incremental adoption inside an Elixir codebase visibly second-class. That was the ticket's own worry; the quoted form shrinks it but does not remove it.

### Option 2 — emit a derived snake_case alias for every public function (prototype F)

```erlang
-export(['New'/1, new/1, ...]).
new(A1) -> 'New'(A1).
```

Compiler delta: `snake_aliases/2`, `snake_form/3` and a regex deriver in `bs_emit.erl` (21 changed lines, `artifacts/patches/62-F-snake-aliases.diff`); skips callback-renamed functions.
Measured on `examples/Shop` (8 public functions): `Shop.beam` 2548 → 2952 bytes; `Code` chunk 398 → 529, `ExpT` 136 → 232, `AtU8` 173 → 218; `:Shop.new(1)` and `:Shop.which(%{Kind: …})` work from Elixir and agree with the PascalCase export (`p5_result.txt`).
Corpus check (`p4_derive_corpus.py`): 114 public names in 72 modules (the verifier showed its regex misses functions whose return type contains `(`; a looser one finds 118 names in 82 files, same conclusion); the naive and acronym-aware deriving rules never disagree and never collide inside a module — **but the corpus contains no acronym or digit name**, so this says nothing about `ParseJSON` or `Utf8Length`. Across all 22 non-exemplar example directories the aliases add +8.0% total beam bytes (54380 → 58752, verifier).
**Prototype F is not behaviour-preserving** (verifier): a module declaring both `ParseJson` and `ParseJSON`, or `Parse_json` and `ParseJson`, compiles unpatched and fails under F with `function parse_json/1 already defined`; an alias that collides with an OTP callback is silently dropped (`Handle_call/3` gets none) rather than reported. A real implementation needs a collision rule, which is the specification work Option 2 hides. Two further collisions found: `HandleCall`/`HandleCast`/`Init` derive to `handle_call`/`handle_cast`/`init`, which are the *OTP callback exports* (F is built to skip these); and `Band` derives to the Erlang reserved word `band` (still callable when quoted).
*Strongest counterargument:* it reverses F10's stated stance (no derivation rule) for one direction of the same mapping, doubles the exports of every public function (+404 bytes for 8 functions here), and the rule is unspecifiable for acronyms and digits without choosing, which the clean-room spec would then owe.

### Option 3 — an explicit per-function alias, no derivation

```csharp
public Order New(int id) export new           // spelling is a guess
```

Compiler delta (**not prototyped**): a signature clause in the parser, an alias map in the checked module, and the same emitter hook as F with `S` taken from the declaration instead of derived. No rule to specify; only the author's names are exported.
*Strongest counterargument:* new surface syntax on the signature for a problem Option 1's quoted call already solves, and every author must remember to add it; an unmarked function is still PascalCase-only.

## Recommendation

**Option 1 now.** It costs nothing, the capability gap the ticket feared does not exist (quoted call), and F10 already recorded why a derivation rule is not wanted.
If Elixir adoption proves to be the goal, take **Option 3** rather than 2: it keeps F10's "no inferred names" rule, is the only one that handles `PKCS-1`-style names, and exports only what an author chose.
Option 2's measured costs are small, but its open edge (acronyms, digits, reserved words, callback names) is exactly what F10 refused to carry.

## Caveats

- Run on OTP 28.0 (repo pins 28.5); Elixir 1.19.5 emits a regex-recompile warning on 28.0, harmless to these probes.
- Elm has no BEAM backend and is not applicable. The Gleam external call was run against a stand-in `Shop` module (hand-built `p0_mk.erl`), not the B# beam; the Elixir calls were run against the real beam.
- The size delta is for one module; it scales with the number of public functions, not bytes of code.

## Verifier (independent re-run; full report `verification/62-verifier.md`)

**CIRCULAR: no** for the evidence on the three headline claims: the quoted-call and syntax-error results come from Elixir's own parser (1.14 and 1.19.5) and real `bsc` beams, p5 fails on the unpatched beam (so it genuinely depends on F),
and the Gleam output reproduces. Weaknesses the verifier named, all reflected above: p4's regex under-counts; p5's "alias agrees with PascalCase" is true by construction (it proves callability, not semantics);
F's collision handling was never probed by my stored probes and fails on the two programs listed. Its extra probes: acronym/digit/BIF-named aliases (`parse_json`, `utf8_length`, `base64_encode/3`, `length`, `abs`, `spawn`) all callable from Elixir;
a lowercase hand-written function name is a syntax error in B# (so that clash cannot occur); `'Probe':band(1)` is an Erlang syntax error unquoted, `'band'` works, and an Erlang caller already had `'Band'`, so the alias gives Erlang nothing.
