# Decision brief: ticket 62 (ENG-252), the function-name casing of the outbound ABI

Prepared for human review. Nothing in `wayfinder/`, `LANGUAGE.md`, `compiler/` or Linear was touched.
All probes live in `artifacts/62-function-name-casing/probes/` and re-run with `bash probes/run_all.sh`.

Environment: Erlang/OTP 25, Elixir 1.14.0 (built on OTP 24), rebar3. `bsc` could not be built here (it needs
OTP 27+ leex), so **every "emitted" form below comes from hand-built abstract forms shaped like bsc's output,
not from bsc**. That limit applies to every number in this brief.

## 0. The headline: the ticket's premise is partly wrong

The ticket, and `LANGUAGE.md:3324-3325`, say Elixir cannot call a PascalCase export and `apply/3` is "the way in".
**Elixir 1.14 can call it with ordinary call syntax, if the function name is quoted:**

```elixir
:Shop."New"(1)                       # works. Same AST as :Shop.New(1) would have had.
1 |> :Shop."New"() |> :Shop."Pay"()  # works
(&:Shop."New"/1).(1)                 # works
```

(`probes/p1_elixir_call_syntax.out`, `p2_elixir_compiled_and_format.out`.) It parses, compiles with no warnings,
survives `Code.format_string!`, and `Macro.to_string` prints it back quoted. `:Shop.New(1)` is still a
SyntaxError, so `62a`'s measurement stands; what it missed is the quoted spelling. This is a zero-cost option that
the ticket's three candidates do not contain.

**A second Elixir friction that no function-alias scheme can reach:** the record *field* keys are PascalCase atoms
too, and `order.Id` is a CompileError in Elixir ("invalid alias"). `order."Id"`, `order[:Id]` and `%{Id: i} = order`
all work (`probes/p2b_field_access.out`). This is probably the larger adoption cost for a caller handling B#
records, and it is outside this ticket. See section 6.

## 1. Sub-decisions extracted

1. **Convention:** accept PascalCase exports / add snake_case aliases / change B#'s own convention.
2. **If aliases: who derives the name?** A rule in the compiler, or the author writing it.
3. **If a rule: acronyms and collisions.** `GetID` vs `GetId` vs `Get_Id`; an alias equal to a name the module
   already defines; alias equal to a compiler-reserved name; same name at different arities.
4. **Does an alias need its own `-spec`?**
5. **Behaviour callbacks.** Does the alias pass touch `Init` / `HandleCall`?
6. **Trampoline or duplicate body.**

Sub-decision 3's non-obvious answers (probes `p3`, `p4`): `GetID`/`GetId` collide under any acronym-aware rule
(`get_id`), erlc refuses the pair ("function get_id/1 already defined"), so the compiler would have to turn this
into a B#-level diagnostic. `ModuleInfo/0` derives `module_info/0`, which erlc refuses for the same reason
(`erl_lint.erl:530`, `1633-1637`). Two arities of one name do **not** collide (`p4: arity_distinct`).
`Get_Id` is a legal B# identifier (`bs_lexer.xrl:150`, `UPPER ALNUM*`, `ALNUM` includes `_`), so a rule must also say
what `_` and digits do. Sub-decisions 4 and 5 are answered by measurement in section 4.

Sub-decision 6 is settled by measurement, not taste: use a trampoline (section 4).

## 2. Option A: accept PascalCase; document the quoted call (compiler delta: none)

B# source (unchanged, `compiler/examples/Shop/shop.bs`):

```csharp
module Shop
record Order { Id: int, Total: int }
public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```

What is emitted (unchanged): `{attribute,1,export,[{'New',1},{'Pay',1},{'Which',1},{'bs@type_atoms',0}]}`
(the real list is built at `bs_emit.erl:76-77`).

What an Elixir caller writes:

```elixir
order = :Shop."New"(7)                    # probes/p1: {:ok, %{Id: 7, Kind: :"Shop.Order", Total: 0}}
defmodule MyApp.Shop do                   # the adoption shim, one line per function (probes/p2, compiled, no warnings)
  defdelegate new(id), to: :Shop, as: :New
end
```

What the compiler must gain: nothing. The work is documentation: amend `LANGUAGE.md` §12 (lines 3324-3325 present `apply/3` as "the way in"
and do not mention the quoted form) and add the one-line `defdelegate` pattern.
Under the repo's rule that a claim in the spec needs a gate, the natural gate is an Elixir-side exemplar that calls
`:Shop."New"(1)` against a real `bsc` build. It cannot be run here, so it is not written.

Measured evidence: `p1_elixir_call_syntax.out` (observed: unquoted -> `:syntax_error`; quoted, single-quoted,
`:"Shop"."New"`, pipe, capture, `apply` -> all return the same map; a nonexistent quoted function raises
`UndefinedFunctionError`, so the quoted form is a real call and not a parse artefact). `p1_mutation_must_fail.out`
shows the probe going red (exit 1) when the target function is renamed. `p2_*`: compiled in a real `.ex` file,
format-stable.

Ecosystem context (`p8_ecosystem_census.out`): of 48,523 exports in 1,669 installed OTP 25 and Elixir 1.14 beams, 19
(0.04%) have an uppercase-initial name (excluding Elixir's compiler-owned `MACRO-` exports), in five modules
(`diameter_types`, `wxImage`, `wxMenu`, `wxRegion`, `wxWindow`); none in Elixir. PascalCase exports have almost no
precedent on the BEAM, so Elixir developers have no habit that accepts them.

**Strongest counterargument:** every call site in Elixir carries quote marks, forever, and an Elixir developer who has
never seen the form will first hit `SyntaxError` and then not know that quoting is the fix. The error message
("syntax error before: ...") does not hint at it. The ticket's stated worry is incremental adoption inside an existing
Elixir codebase; "wrap every call in quotes, or write a `defdelegate` per function" is a tax that is paid per function
by every adopter, and `defdelegate` is itself a hand-maintained second name list in Elixir code. If B# libraries are
meant to be called from Elixir as a first-class use case, A makes B# look foreign at every call site.

## 3. Option B: compiler-derived snake_case aliases

B# source (unchanged). Emitted, N=2 shape (abstract format, `p5_measure.out`):

```erlang
{attribute,1,export,[{'CalcTotal1',1},{'CalcTotal2',1},{calc_total1,1},{calc_total2,1},{'bs@type_atoms',0}]}
```
```
-- calc_total1/1                      %% from the 'S' listing in p5_measure.out
[{label,6},{func_info,{atom,'ShopM'},{atom,calc_total1},1},{label,7},{call_only,1,{f,2}}]
```

The alias is a trampoline: it compiles to a `call_only` tail jump into the PascalCase function. Elixir then writes
`:Shop.new(7)` (probe `p1`: `:Shop.new(1)` returns the same map); Erlang and B# keep `'New'`.

What the compiler must gain (concrete work):

- **A derivation function**, e.g. `bs_names:snake/1`. Acronym-aware (`HTTPGet` -> `http_get`, `ParseURL` ->
  `parse_url`); the naive "underscore before every capital" rule gives `get_i_d` and `parse_u_r_l` (`p3_derivation_census.out`).
  A rule must also define `_` and digits (`Get_Id`, `V2Parse`).
- **An export-list extension** at `bs_emit.erl:76` (one alias per `{F, A}` pair, so each generated arity from default
  arguments gets its alias; `p4: arity_distinct` shows distinct arities are not a collision) plus a trampoline
  `{function,..}` form per alias, emitted next to `file_group` output. `name/2` (`bs_emit.erl:117`) stays the single
  funnel, so spec, definition and local calls cannot disagree; the alias pass is additive.
- **A checker pass with three diagnostics** (new work in `bs_check`): (a) two exported names derive the same alias
  (`GetID`/`GetId`: erlc itself refuses the result, `p4: acronym_collision`); (b) an alias equals a reserved atom
  (`module_info`, `behaviour_info`: `p4: module_info_collision`); (c) the alias equals an atom the module already
  defines. Case (c) is not hypothetical for behaviours: `bs_otp:callback_name` (`bs_otp.erl:83-89`, table at
  `40-49`) already lowers `Init` to `init`, so an alias pass that also emits `init/1` double-defines it
  (`p4: callback_double_define` red, `callback_ok` green when the alias pass skips atoms already defined).
  Answer to sub-decision 5: **skip aliasing for anything in the behaviour callback table**; the existing table is
  already the snake_case mapping for those names.
- Tests for the three diagnostics and for the rule on acronyms, digits and underscores, written before the code (house rule).

Measured cost (`p5_measure.out`; synthetic modules with `debug_info`, 2-clause map-pattern bodies and `-spec`s
shaped like bsc's, so a real function body is bigger and the *relative* cost smaller; the *absolute* trampoline
cost does not depend on the body):

| N exported fns | plain .beam | + trampoline aliases | + duplicate bodies | ExpT chunk plain -> alias | atoms added plain -> alias |
|---|---|---|---|---|---|
| 10 | 2,136 B | 2,664 B (+528) | 3,292 B | 160 -> 280 B | 324 -> 334 |
| 100 | 13,272 B | 18,456 B (+5,184) | 25,232 B | 1,240 -> 2,440 B | 414 -> 514 |
| 1000 | 127,756 B | 183,684 B (+55,928, about 56 B per alias) | 257,356 B (+129,600) | 12,040 -> 24,040 B | 1,314 -> 2,314 |

- Load time (median of 15 fresh VMs): N=10 407 -> 466 us; N=100 1.14 -> 1.42 ms; N=1000 8.4 -> 11.7 ms
  (duplicate body: 17.3 ms). Roughly 3 us per alias.
- One new atom per alias, exactly (+1000 at N=1000). Loaded-code memory +42% at N=1000 for trampolines (726 KB -> 1.03 MB), +100% for duplicate bodies.
- **Trampoline vs duplicate body:** trampoline wins on every axis measured. Duplicate body is 2.3x the size cost, 1.5x the load
  time of the trampoline at N=1000, and a crash through the alias names the *alias* in the stack trace
  (`p7_runtime_stack.out`: `calc2` appears), while a trampoline's `call_only` leaves the PascalCase name as the only frame (one name to grep).
  Call-time cost is within noise (best-of-7 over 5M calls ranged 115-137 ms across the three variants and re-runs flipped the order;
  no claim is made beyond "not measurably different").
- **Aliases need no `-spec` for Dialyzer to reject a bad call** in the simple case tested (`p6_dialyzer_alias_spec.out`: `total(not_an_int)`
  with no spec on `total/1` IS reported, via success typing inherited from the specced callee; the message just lacks the contract line).
  Adding a spec to every alias adds about 4 KB of `Dbgi` per 1000 aliases (`tramp_spec` rows). Not shown: whether the inherited
  success typing degrades for map-typed (record) arguments, which is the real B# case. Only an `integer()` argument was probed.

The corpus check (`p3_derivation_census.out`): 106 distinct `public` names across 89 `.bs` files / 49 module directories
(found by regex, not by parsing): zero collisions under all three rules tried (naive, acronym-aware, lower-first-only),
zero reserved-name hits. **This proves little**: no corpus name has two consecutive capitals, a digit or an underscore, so
the cases that make a rule hard are not in the sample. The planted controls (`GetID`/`GetId`, `ModuleInfo`) are detected.

**Strongest counterargument:** B# would publish two names for every function, permanently, and the derivation rule becomes part of the
ABI: changing how `V2Parse` or `ParseURL` is spelled later silently breaks every Elixir caller. And the rule is non-injective, so
B# gains a class of compile error ("these two names collide in your snake_case alias") that no author asked for and that is only
visible from a language they may never use. Ticket 32 explicitly refused a snake_case/PascalCase mapping rule on the
inbound side ("There is no snake_case <-> PascalCase rule anywhere in the language", `32-ffi-surface.md:204`); this reintroduces
one on the outbound side. Also, the ticket's cited precedent does not support it (see section 5).

## 4. Option C: author-written alias, no derivation rule

Same emitted forms and costs as B, but only for the functions the author marks. Syntax is **illustrative only** and would need
its own grammar decision; there is no attribute grammar in B# (`22-how-opinionated.md:89-100`: `behaviour` and `using` were
both built as keywords), so a marker would be a signature suffix or modifier keyword, not `[Attr]`:

```csharp
module Shop
public Order New(int id) as :new        // Elixir callers: :Shop.new(7);  Erlang and B#: 'New'
public Order Pay(Order o)               // unmarked: PascalCase only
```

Emitted: the same `{new,1}` export and `call_only` trampoline as in section 3, for `New` only.

What the compiler must gain: a parser arm on the signature rule (`bs_parser.yrl`, the `signature` alternative in `decl`,
`bs_parser.yrl:76-83` per ticket 22); a lowercase-atom check (the lexer already distinguishes `atom_lit`,
`bs_lexer.xrl:125`); the same three diagnostics as B, now with the author's own spelling in the message, which makes
them cheaper to explain (the colliding name is on the screen); and the same additive export plus trampoline emission.
It needs no derivation function and no acronym policy.

Precedent in this repo: ticket 32 chose "both spellings are written" for the inbound direction (`32-ffi-surface.md:44-46`,
"the declaration carries both spellings"), and measured that a mapping reaches 1,920 of 1,924 names but cannot spell the rest
(`32-ffi-surface.md:204-208`).

Measured evidence: cost is B's cost scaled by the number of marked functions (about 56 B, 1 atom and about 3 us each);
`p4` collision cases apply unchanged.

**Strongest counterargument:** a marker on every public signature is read noise (the standing constraint in ticket 32 is that
write cost is near-free and read cost is not, `32-ffi-surface.md:41`), and an Elixir user of a library cannot predict which
functions have a snake_case alias without reading the source: a library author who marks 38 of 40 functions has produced a
surface that is worse for an Elixir caller than one with no aliases or all aliases. Option A's quoted call works for every function regardless.

## 5. Neighbour survey

| Neighbour | What is known | Basis |
|---|---|---|
| Erlang | Quotes atoms freely: `'Shop':'New'(1)` | `erl_scan.erl:420-422` (single quote starts a quoted atom), `io_lib.erl:507-517` (`quote_atom`: needs quotes unless first char is lowercase), `62a` section 2 |
| Elixir 1.14 | Unquoted `.Capitalized` is an alias; quoted function name is a call. Measured here | `probes/p1`, `p2` |
| Elixir sources | **Absent**: `/usr/lib/elixir/lib/*` holds only `ebin/*.beam`, no `.ex` or `.erl`, so there is no Elixir tokenizer line to cite. Behaviour is measured, not read | `ls /usr/lib/elixir/lib/elixir` |
| Elixir's own exports | Compiler-owned names get a prefix (`MACRO-m`), as B# does with `bs@` | `p8_ecosystem_census.escript` (it must exclude them to count authored names) |
| Gleam | **UNPROBED (cited from `wayfinder/prototypes/10c_gleam_atoms.gleam:74-75` and `10-atoms-in-a-csharp-skin.md:334-335`)**: "PascalCase becomes snake_case" is said of *variant constructors becoming atoms*. Gleam functions are authored snake_case and are never aliased. Gleam was not installed here, so I could not execute this. | Cited |
| Gleam caller of a PascalCase export | INHERITED from 62a section 4, not re-executed here: `@external(erlang, "Shop", "New")` compiled; the call was never run | `62a_from_the_outside.sh` |
| Elm | **UNPROBED**: Elm targets JavaScript, has no BEAM export ABI, and was descoped by instruction in earlier tickets (`15-error-model.md:416-424`). It is not a neighbour for this question. | Cited |

Consequence: the 62 ticket text (line 114-119) cites Gleam as a precedent "a neighbouring BEAM language already ships" for
emitting snake_case aliases. On the evidence in this repo, that is a different mechanism (constructor to atom spelling, in a
language whose function names are snake_case in source). Verify against Gleam's compiler or docs before relying on it either way.

## 6. Recommendation

**Option A now.** It costs no compiler work, it is correct today, and it removes the ticket's stated blocker ("Elixir
callers use `apply/3`"): quoted calls and one-line `defdelegate` shims are enough for incremental adoption. Fold the
quoted-call form into `LANGUAGE.md` §12 in place of "the way in". Keep Option C (not B) as the escalation if a real Elixir
adopter finds quoting unacceptable, because C needs no derivation rule and uses the same "both spellings are written"
approach that ticket 32 chose; the collision cases that make B hard (`GetID`/`GetId`, `ModuleInfo`, callback names)
are all measured above.

Two things this recommendation depends on that I could not verify:
1. That a *newer* Elixir (the ticket cites 1.19.5; I have 1.14.0) still accepts `:Shop."New"(1)` without a warning. I believe
   quoted function names are long-standing syntax, but that is a belief and not a measurement.
2. That real bsc output exports exactly what the stand-in does. The ABI shape comes from reading `bs_emit.erl:76` and `62a`'s
   measurement, not from running bsc.

Separate item worth a ticket: the record **field** casing (`order.Id` is a CompileError for Elixir callers, section 0) is the
same class of friction, is not fixable by function aliases, and affects every caller that reads a B# record.

## 7. Claims table

| # | Claim | Basis |
|---|---|---|
| 1 | Elixir 1.14: `:Shop.New(1)` is a SyntaxError | `probes/p1_elixir_call_syntax.out` |
| 2 | Elixir 1.14: `:Shop."New"(1)` works and returns the right map; also `'New'`, `:"Shop"."New"`, pipe, capture | `p1`, `p2_elixir_compiled_and_format.out` |
| 3 | The quoted form compiles with no warning in a real `.ex` file, survives `Code.format_string!`, and `defdelegate ..., as: :New` works | `p2` |
| 4 | `order.Id` is a CompileError in Elixir 1.14; `order."Id"`, `order[:Id]`, map pattern work | `p2b_field_access.out` |
| 5 | The probe can go red | `p1_mutation_must_fail.out` (exit 1); `p3`, `p4`, `p5`, `p7` have internal assertions and controls |
| 6 | `:Shop.new(1)` works if a snake alias is exported | `p1` |
| 7 | `GetID`/`GetId` derive the same name under an acronym-aware rule; erlc refuses a module defining both aliases | `p3` (control), `p4: acronym_collision` |
| 8 | `ModuleInfo` -> `module_info` is refused by erlc | `p4: module_info_collision`; `erl_lint.erl:530,1633-1637` |
| 9 | Double-defining a behaviour callback via an alias pass is refused; skipping already-defined atoms is clean | `p4: callback_double_define`, `callback_ok` |
| 10 | Different arities of one name do not collide | `p4: arity_distinct` |
| 11 | Size, ExpT, AtU8, Code, Dbgi, load time, atom and code-memory deltas for N=10/100/1000 | `p5_measure.out` (synthetic stand-in forms; not bsc output) |
| 12 | Trampoline compiles to `call_only`; alias frame absent from stack trace; duplicate-body frame present | `p5_measure.out` asm section, `p7_runtime_stack.out` |
| 13 | Call-time difference between variants | `p7`: inside run-to-run noise; **no claim made** |
| 14 | Spec-less alias still gets a Dialyzer error for a bad `integer()` argument | `p6_dialyzer_alias_spec.out` (map-typed arguments not probed) |
| 15 | 19 of 48,523 installed exports are uppercase-initial authored names, none in Elixir | `p8_ecosystem_census.out` |
| 16 | Corpus: 106 public names, 49 module dirs, no collision under three rules; corpus lacks acronym, digit and underscore names | `p3_derivation_census.out` (regex census, not a parse) |
| 17 | `bs_emit` builds the export list at line 76 and has one name funnel; `bs_otp` already lowers callback names | `bs_emit.erl:76,117,131-135`; `bs_otp.erl:40-49,83-89` (read, not executed) |
| 18 | B# identifiers allow `_` and digits | `bs_lexer.xrl:150` (read, not executed) |
| 19 | No attribute grammar in B#; `behaviour`/`using` were built as keywords | `22-how-opinionated.md:89-100` (read from the ticket) |
| 20 | Gleam's "PascalCase becomes snake_case" concerns variants, not functions | **UNPROBED (cited from `10c_gleam_atoms.gleam:74-75`, ticket 10 section 7)** |
| 21 | Gleam `@external(erlang, "Shop", "New")` compiles; call not run | **INHERITED from 62a, not re-executed** |
| 22 | Elm has no BEAM ABI | **UNPROBED (cited from `15-error-model.md:416-424`)** |
| 23 | Elixir's tokenizer/parser source for the quoting rule | **Not available**: installed Elixir has `ebin` only; behaviour is measured, not read |
| 24 | Quoted call behaviour in Elixir newer than 1.14 | **UNPROBED** |
| 25 | `62a` measurements on OTP 28 / Elixir 1.19.5 (unquoted forms, `Kind` contract, record as map) | **INHERITED from 62a, not re-executed** (only the unquoted `.New` SyntaxError was independently re-measured, on 1.14) |
| 26 | What real `bsc` emits for these modules | **Not measured** (bsc cannot be built here); stand-in forms only |

## Limitations, plainly

- Stand-in modules, not bsc output; sizes scale with body size and I chose a small realistic one.
- Elixir 1.14 and OTP 25, not the ticket's 1.19.5 and OTP 28. Load times are one machine, 15 fresh VMs each, medians.
- The corpus census is a regex over `public` lines; multi-line signatures could be missed.
- Dialyzer was tested only with an `integer()` argument.
- No probe covers tooling that sits above the compiler: Credo, ElixirLS, IEx autocomplete of `:Shop.` exports, or Gleam's compiler.

---

## Decision left open for human review

This brief does not resolve ticket 62, and the recommendation above is a recommendation only. The open decision is the
function-name casing of the outbound ABI: **accept PascalCase and document the quoted call (A), add compiler-derived
snake_case aliases (B), add author-written aliases (C), or change B#'s convention.** Also open for David: whether the
record-field casing friction (section 0) gets its own ticket, and whether `LANGUAGE.md` §12 lines 3324-3325 are amended now
(they currently state `apply/3` is the way in, which is not the only way).
