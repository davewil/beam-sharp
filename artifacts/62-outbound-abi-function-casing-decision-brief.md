# Ticket 62 — the outbound ABI: how an Elixir caller reaches a PascalCase export

**Ticket:** [62](../wayfinder/issues/62-the-outbound-abi.md) · **Linear:** [ENG-252](https://linear.app/davewil/issue/ENG-252)
**Brief written:** 2026-10-23 · **Status: DECISION OPEN — for David's review; nothing resolved.**
**Toolchain:** OTP 28.5 (built from source, the repo's pin), Elixir 1.19.5, Gleam 1.18.1, Elm 0.19.3, rebar3 3.27.0, `bsc` built from `master` at the working tree. Linux x86_64.
**Probes:** `artifacts/probes/62/` (each has a captured `*_output.txt`). **Prototype delta:** one scratch copy of the compiler, +55 lines in `bs_emit.erl`, never in the repo (see 62d).

## What this brief changes about the ticket

Two of the ticket's load-bearing statements are wrong as written, and both matter to the choice.

1. **"Elixir callers use `apply/3`" is false.** Elixir has an ordinary call syntax for a capitalised function name:
   ```elixir
   :Shop."New"(1)                      # works, against the real bsc-emitted beam
   1 |> :Shop."New"()                  # works
   Enum.map([1, 2], &:Shop."New"/1)    # works
   alias :Shop, as: S; S."New"(1)      # works
   ```
   `LANGUAGE.md` §12 (lines 3315–3335) and the ticket both show `apply(:Shop, :New, [1])` as "the way in". It is a way in, not the only one. The unquoted form really is a `SyntaxError`, which is what 62a measured. The quoted form is what Elixir's own tokenizer builds for names that are not identifiers (`elixir-lang/elixir@d33fd8e lib/elixir/src/elixir_tokenizer.erl:946` `handle_dot`, which takes `.` followed by a quote and builds a call). *(Probe 62b; controls inside.)*
2. **"Gleam downcases when it emits to the BEAM: PascalCase becomes snake_case" (ticket 10, repeated in ticket 62 as the precedent for aliases) is true of constructors and false of functions.** Gleam rejects a PascalCase *function* name at parse time and passes every function name through unchanged, apart from one reserved name. The precedent the ticket leaned on does not exist for functions. *(Probe 62c, §Evidence.)*

What is still true and still open: **`import` is impossible today** (a capitalised name is not an Elixir identifier even in `only:`), and every call site carries quotes. That is the whole friction, now measured.

---

## The gating question, alone

> **Is "an Elixir caller writes `:Shop."New"(1)` and can never `import` it" a defect worth a compiler change, or a fact to document?**

Everything else (derived or written, collisions, defaults) only matters if the answer is *a defect*. Here is the same Elixir caller under each answer. Both snippets run (62b, 62j):

```elixir
# Answer "document it" (today's compiler)
alias :Shop, as: S
order = S."New"(1)
orders = Enum.map(ids, &S."New"/1)
# import :Shop            -> unusable: no spelling of New survives Elixir's parser

# Answer "fix it" (prototype compiler, any alias design)
import :Shop, only: [new: 1]
order = new(1)
orders = Enum.map(ids, &:Shop.new/1)
```

A B# author sees nothing in either case. The B# source is the same; the alias is emitted.

## Sub-decisions, in dependency order

| # | Sub-decision | Gates / follows |
|---|---|---|
| 1 | Is the quoted-call form acceptable, so the work is documentation only? | **Gating.** If yes, 2–4 do not arise. |
| 2 | If not: does the author *write* the alias, or does the compiler *derive* it? | Gates 3 and 4. |
| 3 | Collision rule: what happens when two names derive the same alias, or an alias hits a name the BEAM reserves? | Only exists under "derive". |
| 4 | Is deriving on by default, or per module? | Only exists under "derive". |

The ticket's third candidate (change B#'s own function casing to snake_case) is **not offered as an option**: see *Why option 3 is not on the menu*.

---

## Options

### Option A — Accept, and correct the spec

No compiler change. `LANGUAGE.md` §12 shows the quoted call beside `apply/3` and states plainly that `import` is unavailable.

- **Compiler delta:** none. Spec delta only: §12 lines 3315–3335 and the comment at 3335 (`ticket 62 holds the open decision on the casing`).
- **Evidence.**
  - Works against real bsc beams: direct call, nested module (`:"Shop.Reports"."Restate"(1)` → `3`), pipeline, capture, `alias ... as:` (62b).
  - Controls in 62b all fail as they should: unquoted `:Shop.New(1)`, `Shop."New"(1)` (resolves to `Elixir.Shop`, a different module), a name that does not exist, and `import`.
  - Formatter-stable (idempotent under `Code.format_string!`), and Elixir's compiler cross-checks quoted calls against the real export table: a wrong arity gives `:Shop."New"/2 is undefined or private`, a wrong name `:Shop."Nope"/1 is undefined or private`, and the correct call gives no warning (62i, Elixir 1.19.5).
  - The same syntax parses and runs on the distro Elixir 1.14.0 / OTP 25 (62i part 2; **hand-written stand-in `Shop` module**, because an OTP 28 beam will not load on OTP 25).
  - Elixir treats the quotes as *required* here. A quoted lowercase name draws "found quoted call but the quotes are not required" (`elixir_tokenizer.erl:960`, 62i `quoted_lower`); `"New"` draws nothing.
  - Erlang is unaffected, and so is Gleam: a Gleam `@external(erlang, "Shop", "New")` compiles **and runs** (62k; 62a only compiled it). The control, an absent name, fails with `undef`.
  - Precedent that capitalised exports are rare, so no Elixir convention exists for them: of 21,600 exports in 996 OTP 28.5 beams, 14 start with an uppercase letter, all in `diameter_types` (generated code) (62l).
- **Strongest counterargument.** The ticket's own worry stands: this is the likeliest adoption route (B# inside an existing Elixir codebase), and every call site reads as if the author made a mistake: a quoted, capitalised function in a language whose style guide says lowercase. There is no `import`, so a module's whole API must be re-spelled at each call or captured through an `alias`. Nothing measured says this *blocks* anyone, but nothing measured says it *doesn't*: ElixirLS, Credo and ExDoc behaviour on quoted calls were **not measured**.

### Option B — The author writes the alias

An opt-in, per-function second name, written beside the signature. This follows ticket 32 §3's principle that *"both spellings are written"* (`wayfinder/issues/32-ffi-surface.md:200–205`): a written name has no failure case, which is exactly what a derived one cannot promise.

```csharp
// illustrative spelling only; the delta is the same under any spelling
public Order New(int id) export "new"
New(id) -> { Id: id, Total: 0 }
```

- **Compiler delta, concrete.**
  1. `bs_parser.yrl:308–322`: the four `signature` productions take an optional trailing `export STRING`; the `signature` node (the `#fn` record's `vis` neighbour, `bs_emit.erl:141`) carries it.
  2. `bs_check`: a duplicate check across *written* aliases and across existing public names, same arity, reported in B# vocabulary through `bs_diag`. Without it erlc reports `function get_id/1 already defined` at line 0 (62h `acronym_pair`).
  3. `bs_emit.erl:35` (`Exports`) and `:76` (the export attribute), plus one call in `file_group` (`:98–105`): emit `alias(A1..An) -> 'Name'(A1..An).` and export it. Same shape as the prototype, 62d `deleg` mode.
  4. A reserved-alias refusal for `module_info` (Gleam does the same by renaming, `compiler-core/src/erlang.rs:4104–4109`).
- **Measured cost (prototype, derived aliases on *every* public function, so an upper bound for B).**
  - Over 22 compiling example modules: beams 54,232 → 58,716 bytes (+8.3%); `Code` chunk 10,099 → 11,469 (+13.6%); `ExpT` 1,916 → 2,876 (+50%); exports 152 → 232 (80 aliases). That is **about 56 bytes per delegating alias**. With a `-spec` copy: ~64 bytes (62d).
  - Call cost: median remote call 10.79 ns real vs 11.24 ns through the alias; paired delta **+0.19 ns**, against a same-function control delta of **−0.01 ns** and a min–max spread of about 3 ns. Not distinguishable from noise at this resolution (62e). The alias is a tail call to a local function.
  - The delegating form carries **one** copy of the boundary guard: a forged record sent through the alias fails inside `'Squared'`, same as the real export. A full-duplicate alias carries two copies and fails inside `squared` (62f).
  - Compile time: {{62m}}
- **Strongest counterargument.** It needs a **new piece of declaration syntax** (the repo has no annotation form: `LANGUAGE.md` mentions `[DoesNotReturn]` only as C#'s). More important, **an export is an ABI**: once `new` is published, retracting it breaks callers, so each alias is a permanent second public name, and nothing keeps `"new"` and `New` apart when the function is later renamed. The author does extra work on every function that wants Elixir ergonomics, and the work is exactly the kind an agent author forgets.

### Option C — The compiler derives a snake_case alias for every public function

Zero author effort: `New`→`new`, `GetId`→`get_id`, `HTTPServer`→`http_server`.

- **Compiler delta, concrete.** The same emission as B (`bs_emit.erl:35, 76, 98–105`) plus a `snake/1` function (the prototype's is 12 lines), a collision check, and a reserved-name check, both in `bs_check` and both reported through `bs_diag`. `bs_otp:callback_name/3` (`bs_otp.erl:83–89`) is the in-repo precedent for a rename at emission, **but it is a table keyed by name and arity, not a rule**; ticket 35 chose the table on purpose.
- **Measured cost.** As B's upper bound above. Real-corpus collisions: **0** across 259 public functions in 159 parsed `.bs` files, grouped by module directory and arity (62g). The detector is shown to work: its synthetic control `GetId`/`GetID`/`Get_Id` reports the collision.
- **What breaks without the two checks (62h; control compiles, derived does not).**

  | program | real compiler | derived alias, no checks |
  |---|---|---|
  | `GetId` and `GetID`, both `public`, same arity | compiles | erlc error `function get_id/1 already defined`, at line 0 |
  | `public int ModuleInfo(int x)` | compiles | erlc error `function module_info/1 already defined` |
  | `Length` (collides with the BIF name) | compiles | compiles (an export named `length/1` is accepted) |
  | `GetId` public + `GetID` private | compiles | compiles (privates are not aliased) |
  | same name, two arities | compiles | compiles |

  So the rule needs exactly two refusals. The first fails on programs that are legal today, so adopting C makes some existing programs invalid; this is the hazard CLAUDE.md records for 25c ("a capability that closes a residual without supplying a way to name the cases makes previously-valid programs invalid").
- **Strongest counterargument.** It contradicts the letter of ticket 32 §3 and LANGUAGE.md §11 (line 3122): *"the language needs no snake_case ⇄ PascalCase mapping anywhere."* That statement was about the *inbound* direction, where a mapping cannot spell `'PKCS-1'` or a quarter of Elixir's names, and the outbound direction is total on B# identifiers, so the objection does not transfer one-for-one. But it does introduce the language's first derived naming rule, and it is not injective, which is what forces the collision refusal. It also **doubles the public export surface permanently** (80 aliases onto 152 exports in the examples), visible to every Erlang tool that lists exports.

### Why option 3 (snake_case function names in B#) is not on the menu

Counted with the compiler's own lexer and parser (62g): **356 function declarations (259 public) in 159 parsed files** outside `artifacts/`, every public one uppercase-initial. That is the cheap part. The expensive part is that function names are `uident` tokens in the grammar (`bs_parser.yrl:308–310`), and ticket 26 §3 chose to tell a field projection from a call *lexically, by casing*: `o.Status` against `List.Map` (`wayfinder/issues/26-data-modelling.md:240`; ticket 32 repeats it at `32-ffi-surface.md:196–199`). Lowercase function names reopen that rule. Four files fail to parse under the current grammar (listed in `62g_output.txt`) and are not in the count; embedded eunit sources and `LANGUAGE.md` blocks are not counted either.

---

## Recommendation

**Option A now, and decide B or C only if you judge the loss of `import` to be a blocker.**

The ticket was written believing Elixir callers had `apply/3` and nothing else. They have an ordinary, formatter-stable, xref-checked call syntax, and the only capability the aliases add on top of it is `import` (62j). A and the aliases are not exclusive: A is the spec correction regardless, and B or C can follow without breaking it, because aliases only add exports. The reverse is not true: **an export, once shipped, is an ABI**. That asymmetry is the reason to wait.

If you do want aliases, **prefer B (written) over C (derived)**: it keeps ticket 32 §3 intact, needs no collision rule because the author states the name, and costs bytes only where someone asked. C is the one with zero author effort, and if you want that, the rule is cheap (12 lines) and the two refusals are the whole of its edge.

**What would change this:** (1) evidence that Elixir tooling mishandles quoted capitalised calls (ElixirLS completion, Credo, ExDoc were not tested); (2) a decision that incremental adoption inside Elixir codebases is the primary use, in which case quoted calls at every site is a real cost and B or C wins; (3) the clean-room handoff needing a stable Elixir-facing name list in the spec, which favours B (written names appear in the source).

## Independent of the choice: three spec corrections this brief found

These are outside this ticket's decision and are listed because they are checkable facts, not choices. I did not edit the spec.

- `LANGUAGE.md:3323–3326` presents `apply/3` as the only way in. Probe 62b shows otherwise.
- `wayfinder/issues/10-atoms-in-a-csharp-skin.md:18` and `:335` say PascalCase becomes snake_case on Gleam's BEAM output; that holds for constructors (`compiler-core/src/erlang.rs:387`, `to_snake_case` at `compiler-core/src/strings.rs:73`) and not functions. Ticket 62's option 2 cites it as precedent for function aliases.
- `wayfinder/issues/62-the-outbound-abi.md` says Gleam "names foreign functions as strings … measured as far as compiling the declaration; the call was not run." Probe 62k runs it.

---

## Neighbour survey (sources cloned or installed locally)

| Language | What it does with a function name on the BEAM | Source |
|---|---|---|
| **Gleam** | Function names are emitted unchanged. The only rewrite is `module_info` → `moduleInfo`. A PascalCase function name is a *syntax error* (`I'm expecting a lowercase name here`). Constructors and types are snake_cased (`Circle` → `circle`, `UnitSquare` → `unit_square`; 62c). Module path `deep/nested_mod` → `deep@nested_mod`. | `gleam-lang/gleam@0d9fa18`: `compiler-core/src/erlang.rs:653` (function name goes through `escape_erlang_existing_name`), `:4104–4109` (that function), `:387` (constructor atom), `compiler-core/src/strings.rs:73` (`to_snake_case`); `compiler-core/src/build.rs:432` (`/` → `@`) |
| **Elixir** | `.Capitalized` after a dot is an alias token, and an alias followed by `(` is a hard error with an explanatory message. A quoted name after `.` is built as a call by `handle_dot`. | `elixir-lang/elixir@d33fd8e`: `lib/elixir/src/elixir_tokenizer.erl:1501–1512`, `:946–985`, `:1035–1039`; `lib/elixir/src/elixir_parser.yrl:480–481`, `:494–498` |
| **Erlang** | Quotes atoms freely; no friction (62a, 62b). 14 of 21,600 OTP exports are capitalised, all generated. | 62l |
| **Elm** | Not surveyed: Elm compiles to JavaScript and has no BEAM export convention. Its port boundary is ticket 18's reference, not this one's. | n/a |
| **C#** | Not surveyed: no local source. | n/a |

## Evidence ledger

| Probe | Claim tested | Control | Result | Does **not** show |
|---|---|---|---|---|
| `62a` (existing, re-run) | PascalCase export gives Elixir a `SyntaxError`; no module prefix helps; Erlang unaffected | unquoted forms | Reproduced on this toolchain (the Gleam part fails here at hex resolution; see 62c/62k for the replacement) | Quoted-call syntax (it did not test it) |
| `62b_quoted_call.sh` | Elixir can call a bsc export with quoted syntax | unquoted, `Shop` alias, absent name, `import` | 6 of 6 positive cases work; all 4 controls fail | Anything on OTP < 28 beams (see 62i) |
| `62c_gleam_naming.sh` | Gleam snake_cases constructors, not functions | PascalCase function in source | Constructors `circle`/`unit_square`; functions unchanged; PascalCase function refused | Gleam's Elixir-target output |
| `62d_alias_cost.sh` | Byte cost of aliases | `off` mode = real compiler | +4,484 B (deleg) / +7,576 B (dup) on 54,232 B; 80 aliases | JIT native code size |
| `62e_alias_call_cost.sh` | Call-time cost of an alias | same function timed twice | +0.19 ns median vs −0.01 control; spread ~3 ns | Cold/megamorphic call sites; other architectures |
| `62f_alias_guard.sh` | Delegating alias keeps exactly one guard | real export on a forged record | `deleg`: fails in `'Squared'`; `dup`: fails in `squared` | Behaviour of aliases with `-spec` under Dialyzer |
| `62g_blast_radius.escript` | Size of the rename; real collisions | synthetic collision | 356 decls / 259 public / 0 collisions; control reports the collision | 4 unparsable files; eunit-embedded sources; LANGUAGE.md blocks |
| `62h_alias_edge_cases.sh` | Where a derived rule breaks | `BS_ALIAS=off` on each program | `GetId`/`GetID` and `ModuleInfo` break; 4 other cases don't | A complete list of reserved names |
| `62i_quoted_call_tooling.sh` | Formatter, xref, older Elixir | wrong arity, wrong name, quoted lowercase | Formatter idempotent; xref warns on wrong arity/name; 1.14.0 runs it | ElixirLS, Credo, ExDoc |
| `62j_import_from_elixir.sh` | Aliases add `import` | real compiler | `import :Shop, only: [new: 1]` works only with aliases | — |
| `62k_gleam_calls_bsharp.sh` | A Gleam `@external` call to a PascalCase B# export runs | absent name → `undef` | Runs and returns the record | Gleam on the Elixir target |
| `62l_otp_uppercase_exports.escript` | Capitalised exports are rare in OTP | classifier controls | 14 of 21,600, all `diameter_types` | Hex packages |
| `62m_compile_time.sh` | Compile-time cost | `off` measured twice | {{62m-short}} | Larger programs |

## Not measured, and caveats

- OTP 28.5, erts 16.4, x86_64 Linux only. Timing resolution as stated in 62e.
- The alias cost numbers come from a prototype that aliases **every** public function with a delegating call; option B's cost is proportional to how many functions an author chooses to alias.
- 62d's byte counts include debug info (`Dbgi` chunk); the `Code` and `ExpT` columns isolate the executable part.
- One example module (of 23) is refused by the compiler in every mode including the control, so the totals cover 22 modules.
- Tooling beyond the Elixir compiler and formatter was not tested.
- The `bs_emit.erl` prototype is in the session scratchpad (`p62-compiler/`), not in the repo, by design.
