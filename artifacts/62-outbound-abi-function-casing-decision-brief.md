# Ticket 62 — the outbound ABI: how an Elixir caller reaches a PascalCase export

**Ticket:** [62](../wayfinder/issues/62-the-outbound-abi.md) · **Linear:** [ENG-252](https://linear.app/davewil/issue/ENG-252)
**Brief written:** 2026-10-23 · **Status: DECISION OPEN — for David's review; nothing resolved.**
**Toolchain:** OTP 28.5 (built from source, the repo's pin), Elixir 1.19.5, Gleam 1.18.1, Elm 0.19.3, rebar3 3.27.0, `bsc` built from the working tree. Linux x86_64.
**Probes:** `artifacts/probes/62/` (each has a captured `*_output.txt`).
**Prototype delta:** `artifacts/probes/62/p62-alias-prototype.patch` (+55 lines to `compiler/src/bs_emit.erl`; applies cleanly to the working tree; not applied to the repo). To rebuild: copy `compiler/` to a scratch dir, `patch src/bs_emit.erl < p62-alias-prototype.patch`, `rebar3 escriptize`, `export ALIASBSC=<scratch>/_build/default/bin/bsc`. The patch reads `BS_ALIAS=off|deleg|delegspec|dup`. It aliases **derived** names only; the written form (option B) was never prototyped.

## What this brief changes about the ticket

Two statements the ticket leans on are wrong as written, and both matter to the choice.

1. **Elixir callers are not limited to `apply/3`.** Elixir has an ordinary call syntax for a capitalised function name:
   ```elixir
   :Shop."New"(1)                      # works, against the real bsc-emitted beam
   1 |> :Shop."New"()                  # works
   Enum.map([1, 2], &:Shop."New"/1)    # works
   alias :Shop, as: S; S."New"(1)      # works
   ```
   The ticket and `LANGUAGE.md` §12 (lines 3323–3326) present `apply(:Shop, :New, [1])` as "the way in" and do not mention the quoted form. The unquoted form really is a `SyntaxError`, as 62a measured. The quoted form is the one Elixir's own tokenizer builds for names that are not identifiers (`elixir-lang/elixir@d33fd8e lib/elixir/src/elixir_tokenizer.erl:946`, `handle_dot`). *(Probe 62b; controls inside.)*
2. **The Gleam precedent for aliases does not exist for functions.** Ticket 62 (lines 117–118) cites Gleam as downcasing PascalCase to snake_case on the BEAM. Ticket 10 (`wayfinder/issues/10-atoms-in-a-csharp-skin.md:335`) wrote *"PascalCase to snake_case"* in a sentence about **variants** (constructors), and that is what Gleam does. Ticket 62 read it as a statement about functions. Gleam rejects a PascalCase *function* name at parse time and passes every function name through unchanged apart from one reserved name. *(Probe 62c.)*

What remains true and open: **an imported function cannot be called.** `import :Shop, only: [New: 1]` is itself accepted, but no spelling of the call parses (62j). Every call site carries quotes.

---

## The gating question, alone

> **Is "an Elixir caller writes `:Shop."New"(1)` and cannot `import` it" a defect worth a compiler change, or a fact to document?**

The B# author sees nothing different either way. Here is the same B# source, which compiles today (probe 62n, `shared_source`), and the Elixir caller under each answer (both run: 62b, 62j):

```csharp
// probe: ok shared_source
module Shop

record Order { Id: int, Total: int }

public Order New(int id)

New(id) -> Order{ Id = id, Total = 0 }
```

```elixir
# Answer "document it" (today's compiler)
alias :Shop, as: S
order  = S."New"(1)
orders = Enum.map(ids, &S."New"/1)

# Answer "fix it" (prototype compiler, any alias design)
import :Shop, only: [new: 1]
order  = new(1)
orders = Enum.map(ids, &:Shop.new/1)
```

**If the answer is "document it", nothing else in this brief needs deciding.** If it is "fix it", the follow-on question is whether the author writes the alias (B) or the compiler derives it (C); the collision and default questions exist only under C.

---

## Options

### Option A — Accept, and correct the spec

No compiler change. `LANGUAGE.md` §12 shows the quoted call beside `apply/3` and states that `import` is unusable.

- **Compiler delta:** none. Spec delta: §12 lines 3315–3337, including the comment at 3337 (`ticket 62 holds the open decision on the casing`).
- **Evidence.**
  - Works against real bsc beams: direct call, nested module (`:"Shop.Reports"."Restate"(1)` → `3`), pipeline, capture, `alias ... as:` (62b).
  - Controls in 62b fail as they should: unquoted `:Shop.New(1)`, `Shop."New"(1)` (resolves to `Elixir.Shop`, a different module), a name that does not exist, and the unquoted-`import` call forms.
  - Formatter-stable (idempotent under `Code.format_string!`), and the Elixir 1.19.5 compiler cross-checks quoted calls against the real export table: a wrong arity gives `:Shop."New"/2 is undefined or private`, a wrong name gives `:Shop."Nope"/1 is undefined or private`, and the right call gives no warning (62i).
  - Elixir treats the quotes as *required* here. A quoted lowercase name draws "found quoted call but the quotes are not required" (`elixir_tokenizer.erl:960`, 62i `quoted_lower`); `"New"` draws nothing.
  - Erlang is unaffected, and so is Gleam: a Gleam `@external(erlang, "Shop", "New")` compiles **and runs** (62k; 62a only compiled it). The control, an absent name, fails with `undef`.
  - Capitalised exports are rare, so no Elixir convention exists for them: 14 of 21,600 exports in 996 OTP 28.5 beams start with an uppercase letter, all in the one module `diameter_types` (62l).
- **Strongest counterargument.** The ticket's own worry: B# inside an existing Elixir codebase is the likeliest adoption route, and every call site reads as a mistake — a quoted, capitalised function in a language whose style says lowercase — with no `import`, so an API is re-spelled at each call or captured through an `alias`. Nothing measured says this *blocks* anyone and nothing says it doesn't: ElixirLS, Credo and ExDoc behaviour on quoted calls was **not measured**.

### Option B — The author writes the alias

An opt-in, per-function second name written beside the signature. It follows ticket 32 §3's rule that *"both spellings are written"* (`wayfinder/issues/32-ffi-surface.md:201–205`): a name the author wrote has no failure case, which a derived name cannot promise.

The spelling is illustrative. **Today's compiler refuses it**, because the syntax is not built (62n runs the refusal, with the unmarked source above as its control):

```csharp
// probe: refused proposed_export_syntax
module Shop

record Order { Id: int, Total: int }

public Order New(int id) export "new"

New(id) -> Order{ Id = id, Total = 0 }
```

- **Compiler delta, concrete.**
  1. `bs_parser.yrl:308–322`: the four `signature` productions take an optional trailing `export STRING`, and the signature node carries it. **Never parsed or prototyped**; the lexer also needs the `export` word.
  2. `bs_check`: a duplicate check across written aliases and existing public names, same arity, reported in B# vocabulary through `bs_diag`. Without it erlc reports `function get_id/1 already defined` at line 0 (62h `acronym_pair`, shown with *derived* names).
  3. `bs_emit.erl:35` (`Exports`) and `:76` (export attribute), plus one call in `file_group` (`:98–105`): emit `alias(A1..An) -> 'Name'(A1..An).` and export it. That emission **is** prototyped (62d `deleg`), with derived names.
  4. A refusal for an alias that equals a name the BEAM generates (`module_info/0,1`, 62h).
- **Measured cost.** The prototype aliases every public function, so it bounds B's cost from above; B pays only for the functions an author marks.
  - Over 22 compiling example modules (62d): author-written exports 83 → 163 (80 aliases); loaded size with debug info stripped 16,220 → 17,756 bytes, **about 19 bytes per delegating alias**. With debug info (which embeds absolute paths, so the total varies by checkout) the figure is about 56 bytes per alias. `Code` chunk 10,099 → 11,469 (+13.6%), `ExpT` 1,916 → 2,876 (+50%). The `-spec` copy is invisible once stripped (it lives in debug info) and costs ~8 bytes per alias unstripped.
  - Call cost: median remote call 10.79 ns real vs 11.24 ns through the alias. The paired delta is **a consistent +0.1–0.2 ns (about 1–2%)**, above the same-function control (−0.01 ns) and below any practical effect; the min–max spread within a run is about 3 ns (62e). The alias is a tail call to a local function.
  - The delegating form carries **one** copy of the boundary guard: a forged record sent through the alias fails inside `'Squared'`. A full-duplicate alias carries two copies and fails inside `squared` (62f).
  - Compile time: whole examples tree, 15 interleaved rounds per mode, medians off 11,090 ms, deleg 11,195 ms, dup 10,941 ms. The same real compiler timed twice differs by 219 ms, so the alias modes sit inside that noise floor (62m). Each number is dominated by VM start-up.
- **Strongest counterargument.** It needs a **new declaration syntax**; the repo has no annotation form. And **an export is an ABI**: once `new` is published, retracting it breaks callers, so each alias is a permanent second public name, and nothing ties `"new"` to `New` when the function is later renamed. The author does extra work on every function that wants Elixir ergonomics, and it is exactly the work an agent author forgets.

### Option C — The compiler derives a snake_case alias for every public function

Zero author effort. `New`→`new`, `GetId`→`get_id`, `HTTPServer`→`http_server`. This module compiles today and, in the prototype, also exports `new/1` and `get_id/1` (62n prints both export lists):

```csharp
// probe: ok derived_alias_source
module Shop

record Order { Id: int, Total: int }

public Order New(int id)

New(id) -> Order{ Id = id, Total = 0 }

public int GetId(Order o)

GetId(o) -> o.Id
```

- **Compiler delta, concrete.** The emission of B (`bs_emit.erl:35, 76, 98–105`), plus a `snake/1` function (the prototype's is 12 lines), a collision check and a reserved-name check, both in `bs_check` and reported through `bs_diag`. `bs_otp:callback_name/3` (`bs_otp.erl:83–89`) is the in-repo precedent for renaming at emission, **but it is a table keyed by name and arity, not a rule**; ticket 35 chose the table on purpose.
- **Measured cost.** As B's upper bound above, applied to every public function.
- **What breaks without the two checks** (62h; the control, the real compiler, compiles every row):

  | program | derived alias, no checks |
  |---|---|
  | `GetId` and `GetID`, both `public`, same arity | erlc error `function get_id/1 already defined`, at line 0 |
  | `public int ModuleInfo(int x)` | erlc error `function module_info/1 already defined` |
  | `public int ModuleInfo()` | erlc error `function module_info/0 already defined` |
  | `Length` (a BIF name), `BehaviourInfo/1`, `BsTypeAtoms/0`, `GetId` public with `GetID` private, one name at two arities | compiles |

  The first three fail on programs that are legal today, so adopting C makes some existing programs invalid. `compiler/features/README.md:27` records the same hazard for 25c.

  Illustrative collision, compiles today and is what the check must refuse under C:

  ```csharp
  // probe: ok collision_source
  module Shop

  public int GetId(int x)

  GetId(x) -> x

  public int GetID(int x)

  GetID(x) -> x
  ```
- **Real-corpus collisions: 0, but that number is nearly vacuous.** A collision needs names that differ only in capitalisation, digits or underscores. The corpus contains **no** public name with an acronym run, a digit or an underscore (62g prints an empty list for exactly that), so it could not have collided. The hazard is real only in the synthetic case above.
- **Strongest counterargument.** It contradicts ticket 32 §3 as written, and my position is the same for B and C: *"There is no snake_case ⇄ PascalCase rule anywhere in the language"* (`32-ffi-surface.md:204`; repeated at `LANGUAGE.md:3122`). Option B conforms to that rule because the author writes the name. Option C is a rule, so choosing it means amending 32 §3. It would also introduce the language's first derived naming rule, one that is not injective (hence the collision refusal), and it **doubles the author-visible export list permanently** (83 → 163 in the examples), in every Erlang tool that lists exports.

### Why the ticket's third candidate (snake_case function names in B#) is not offered

This is my judgement, with the count behind it. Counted with the compiler's own lexer and parser (62g): **356 function declarations, 259 of them public, every public one uppercase-initial**, in 159 parsed files outside `artifacts/`. By group (public / all): `compiler/examples` excluding exemplars 100 / 116, `compiler/examples/exemplars` 27 / 77, other `compiler` 18 / 19 (together the 212 under `compiler/`), `wayfinder` 78 / 93 (prototypes and research), `aoc` 7 / 22, `handoff` 29 / 29. That is the cheap part. The expensive part is that function names are `uident` tokens in the grammar (`bs_parser.yrl:308–310`), and ticket 26 §3 chose to tell a field projection from a call *lexically, by casing*: `o.Status` against `List.Map` (`26-data-modelling.md:240`; ticket 32 repeats it at `32-ffi-surface.md:196–199`). Lowercase function names reopen that rule. Four files do not parse under the current grammar and are not in the count (listed in `62g_output.txt`); eunit-embedded sources and `LANGUAGE.md` blocks are not counted. A regex over the same tree gave 247 public signatures against the parser's 259; I did not find the cause of the 12, and I use the parser's number because it reads the grammar rather than guessing at it. Neither figure changes the argument.

---

## Recommendation

**Option A now, and decide B or C only if you judge the loss of `import` a blocker.**

The ticket was written believing Elixir callers had `apply/3` and nothing else. They have an ordinary, formatter-stable, compiler-checked call syntax, and the one capability aliases add on top is `import` (62j). A is the spec correction regardless, and B or C can follow without breaking it, because aliases only add exports. The reverse is not true: **an export, once shipped, is an ABI**. That asymmetry is the reason to wait.

If you do want aliases, **prefer B**: it keeps ticket 32 §3 intact, and the author states each name, so the compiler needs only a duplicate check. This is inferred, not probed: the written syntax was never built. C is the zero-effort choice; its rule is cheap (12 lines) but needs three refusals and an amendment to 32 §3.

**What would change this:** (1) evidence that Elixir tooling mishandles quoted capitalised calls (ElixirLS, Credo, ExDoc untested); (2) a decision that incremental adoption inside Elixir codebases is the primary use, which makes quoted calls a real cost and favours B or C; (3) the clean-room handoff needing a stable Elixir-facing name list in the spec, which favours B, since written names appear in the source.

## Spec statements the probes contradict or sharpen

Not decisions; I did not edit the spec.

- `LANGUAGE.md:3323–3326` shows `apply/3` as "the way in" and never mentions the quoted call (62b).
- `wayfinder/issues/62-the-outbound-abi.md:117–118` cites Gleam as downcasing functions; `10-atoms-in-a-csharp-skin.md:335` is about variants (`compiler-core/src/erlang.rs:387`, `to_snake_case` at `compiler-core/src/strings.rs:73`).
- The ticket says the Gleam call was "not run"; 62k runs it.

---

## Neighbour survey (sources cloned or installed locally)

| Language | What it does with a function name on the BEAM | Source |
|---|---|---|
| **Gleam** | Function names are emitted unchanged; the only rewrite is `module_info` → `moduleInfo`. A PascalCase function name is a syntax error (`I'm expecting a lowercase name here`). Constructors are snake_cased (`Circle` → `circle`, `UnitSquare` → `unit_square`; 62c). Module path `deep/nested_mod` → `deep@nested_mod`. | `gleam-lang/gleam@0d9fa18`: `compiler-core/src/erlang.rs:653`, `:4104–4109`, `:387`; `compiler-core/src/strings.rs:73`; `compiler-core/src/build.rs:432` |
| **Elixir** | `.Capitalized` after a dot is an alias token, and an alias followed by `(` is a hard error. A quoted name after `.` is built as a call. | `elixir-lang/elixir@d33fd8e`: `lib/elixir/src/elixir_tokenizer.erl:1501–1512`, `:946–985`, `:1035–1039`; `lib/elixir/src/elixir_parser.yrl:480–481`, `:494–498` |
| **Erlang** | Quotes atoms freely; no friction (62a, 62b). 14 of 21,600 OTP exports are capitalised, all in one module. | 62l |
| **Elm** | Not surveyed: Elm compiles to JavaScript and has no BEAM export convention. | n/a |
| **C#** | Not surveyed: no local source. | n/a |

## Evidence ledger

| Probe | Claim tested | Control | Result | Does **not** show |
|---|---|---|---|---|
| `62a` (existing, re-run) | PascalCase export gives Elixir a `SyntaxError`; no module prefix helps; Erlang unaffected | unquoted forms | Reproduced on this toolchain; its Gleam section fails here at hex resolution (62c and 62k replace it) | The quoted-call syntax |
| `62b_quoted_call.sh` | Elixir calls a bsc export with quoted syntax | unquoted, `Shop` alias, absent name, `import` call | 6 of 6 positive cases work; all 4 controls fail | Anything on OTP < 28 beams |
| `62c_gleam_naming.sh` | Gleam snake_cases constructors, not functions | PascalCase function in source | Constructors `circle`/`unit_square`; functions unchanged; PascalCase function refused | Gleam's Elixir target |
| `62d_alias_cost.sh` | Byte cost of derived delegating aliases | `off` = real compiler | 83 → 163 author exports; stripped 16,220 → 17,756 B; unstripped path-dependent | JIT native code; written aliases |
| `62e_alias_call_cost.sh` | Call-time cost of an alias | same function timed twice | +0.19 ns median vs −0.01 control; spread ~3 ns | Cold or megamorphic call sites; other architectures |
| `62f_alias_guard.sh` | A delegating alias keeps one guard | real export on a forged record | `deleg` fails in `'Squared'`; `dup` fails in `squared` | Aliases under Dialyzer |
| `62g_blast_radius.escript` | Size of a rename; real collisions | synthetic collision | 356 / 259 public / 0 collisions; control reports the synthetic one | 4 unparsable files; eunit-embedded sources; LANGUAGE.md blocks |
| `62h_alias_edge_cases.sh` | Where a derived rule breaks | `BS_ALIAS=off` on each program | `GetId`/`GetID`, `ModuleInfo/1`, `ModuleInfo/0` break; 6 other cases don't | A complete list of generated names |
| `62i_quoted_call_tooling.sh` | Formatter and compiler checks (parts 1, 3: real bsc beam, Elixir 1.19.5/OTP 28); older-Elixir parse (part 2) | wrong arity, wrong name, quoted lowercase | Formatter idempotent; compiler warns on wrong arity/name; **part 2 is tokenizer-only evidence about Elixir 1.14.0 (compiled with OTP 24, run on OTP 25) calling a hand-written stand-in module, not about bsc output** | ElixirLS, Credo, ExDoc |
| `62j_import_from_elixir.sh` | `import` of a capitalised name is accepted but uncallable; aliases make it callable | real compiler | `import :Shop, only: [New: 1]` runs; every call spelling is a `SyntaxError`; with aliases `new(1)` works | — |
| `62k_gleam_calls_bsharp.sh` | A Gleam `@external` call to a PascalCase B# export runs | absent name → `undef` | Runs and returns the record | Gleam on the Elixir target |
| `62l_otp_uppercase_exports.escript` | Capitalised exports are rare in OTP | classifier controls | 14 of 21,600, one module | Hex packages |
| `62m_compile_time.sh` | Compile-time cost | `off` timed twice | Inside noise | Larger programs |
| `62n_brief_blocks_compile.sh` | Every B# block in this brief compiles (or is refused, as labelled) under `$BSC` | the wrong record-literal form is refused | see output | That the Elixir blocks parse (62b, 62j run them) |

## Not probed, or inferred

- **Option B's `export "new"` syntax was never parsed or prototyped.** The refusal in 62n only shows that today's compiler does not have it.
- "B needs no collision rule" and "B costs bytes only where asked" are **inferred** from the derived-alias prototype, not measured on a written form. B still needs a duplicate check (item 2 above).
- `ModuleInfo` was tested at arities 0 and 1; `BehaviourInfo/1` and `BsTypeAtoms/0` compile. Other BEAM-generated names (for example in modules that declare `-callback`) were not enumerated.
- An alias with a `-spec` was only byte-counted; Dialyzer was not run on it.
- The third candidate (snake_case function names) was dropped as an option on my judgement, for the reason and count above; you may weigh it differently.
- Tooling beyond the Elixir compiler and formatter (ElixirLS, Credo, ExDoc); other OTP versions and architectures; C# and Elm.
- One example module of 23 is refused by the compiler in every mode, control included, so totals cover 22.
