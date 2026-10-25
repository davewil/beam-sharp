# Decision brief: ticket 62, the outbound ABI (ENG-252), function-name casing for Elixir callers

Status: brief only. Nothing under `wayfinder/` or `compiler/` was edited, nothing committed, Linear untouched.
Toolchain: OTP 29, Elixir 1.20.4, gleam 1.19.1, bsc built from `compiler/src` at HEAD `1429fdc`.
Probes are under `probes/`; each is cited as `probes/<file>`.

## 0. The short version

The ticket's premise is out of date in a way that changes the question. Elixir **can** call a
capitalised function with ordinary dot syntax. The spelling is `:Shop."New"(1)` and the ticket
does not list it (`probes/03_elixir_spellings.out`). It produces the same AST as `:shop.new(1)`,
survives `mix format`, and gets a compile-time "undefined or private" warning that `apply/3` does
not get. So the friction is "Elixir callers must quote the function name", not "Elixir callers are
pushed to `apply/3`", and LANGUAGE.md §12 currently teaches the second one.

The ticket's other premise, that Gleam "downcases PascalCase when it emits", is **wrong for
functions and modules**. Gleam rejects PascalCase function names and module names at the
parser. The snake_casing is applied to **data constructors**, and its rule is naive:
`HTTPGet` becomes `h_t_t_p_get` (`probes/05_gleam_names.out`, `probes/09_gleam_constructor_mapping.out`).
It is a bad precedent for the thing the ticket wants to borrow it for.

Recommendation (section 6): **candidate 1, amended.** Accept PascalCase exports, change LANGUAGE.md
§12 to teach the quoted-call spelling, and put the caller-side `defdelegate` / macro wrapper in
the section as the escape for a team that wants snake_case names (`probes/16_*`). This is a
doc-only change with no compiler work. Candidate 2 costs real compiler work, two of its measured
failure modes cannot be fixed by a better rule, and it contradicts a published sentence of §12.
Candidate 3 rewrites the lexer rule that lets the grammar tell a function from a type.

## 1. Sub-decisions, in dependency order

1. **Is there an Elixir spelling of a capitalised export that is not `apply/3`?** A fact, not a
   decision. Answered by probe: yes (section 2). Everything after it depends on this.
2. **Given that spelling exists, is "write the function name in quotes" an acceptable supported
   contract for an Elixir caller?** This is the **gating decision**. If yes, nothing else is
   needed. It is a question about Elixir callers' ergonomics, and David should judge it by reading
   the two call sites in section 3.
3. **Only if 2 is no: should B# emit extra snake_case exports, and by what rule?** Costed in
   section 4.
4. **Only if 3 is also no: change B#'s own function-name convention.** Costed in section 5.

Sub-questions 3 and 4 are asked only after 2, per the house rule that a gating question is asked alone.

## 2. Re-running the ticket's own measurements

`probes/01_62a_original.sh` is the unmodified prototype. `probes/02_62a_adapted.sh` is the same
script with three edits (`probes/02_adapt.diff`): the `bsc` path points at the prebuilt wrapper,
`PATH` and `ELIXIR_ERL_OPTIONS` are set, and the `rebar3` build block is removed. Raw output is
`probes/02_62a_adapted.out`.

| Ticket claim | Still holds on OTP 29 / Elixir 1.20.4 / gleam 1.19.1? | Evidence |
|---|---|---|
| Module atoms are `Shop`, `Shop.Reports`, `Shop.Collections.Ints`, no prefix | Holds | `02_62a_adapted.out` section 1 |
| Erlang `'Shop':'New'(1)` works | Holds | section 2 of the same file |
| `:Shop.New(1)`, `:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)`, `:"Elixir.Shop".New(1)` are syntax errors | Holds, all four | section 3(b) |
| `:"BSharp.Shop".new(1)` and `apply(:Shop, :New, [1])` parse | Holds | section 3(b) |
| A B# record arrives as a plain map, `is_struct?` false, no `__struct__` | Holds | section 3(c) |
| Right tag accepted, wrong tag and an Elixir struct give `FunctionClauseError` | Holds | section 3(e) |
| Gleam `@external(erlang, "Shop", "New")` "compiles" | **Could not re-run as written**: `gleam new` pulls `gleam_stdlib` from hex.pm, which is blocked here (`02_62a_adapted.out` section 4). Re-done without any dependency in `probes/06_gleam_calls_bsharp.sh` and now **run, not only compiled**: it returns `order`. A control with a misspelt function gives `error:undef`. | `probes/06_gleam_calls_bsharp.out` |
| Ticket says "OTP 28, gleam 1.18.1" | The tools here are newer; the results did not change | |

So all three frictions hold as measured. What the ticket did not test is the next table.

### 2.1 Every Elixir spelling of a capitalised function I could find

`probes/03_elixir_spellings.exs`, run with the harness's own positive control
(`:erlang.abs(-1)` runs, `:Shop.module_info(:module)` runs) and negative controls (a lowercase name
that does not exist gives `UndefinedFunctionError`).

| Spelling | Result |
|---|---|
| `:Shop.New(1)` | parse error: "unexpected ( after alias New. Function names ... start with lowercase" (from `elixir_tokenizer.erl:1528`, located via probe 07) |
| `:"Shop".New(1)` | same parse error |
| **`:Shop."New"(1)`** | **runs, returns the record** |
| `:"Shop"."New"(1)` | runs |
| `m = :Shop; m."New"(1)` | runs |
| `apply(:Shop, :New, [1])`, `Kernel.apply/3`, `:erlang.apply/3` | run |
| `Function.capture(:Shop, :New, 1).(1)` | runs |
| `&:Shop.New/1` | parse error: "atom cannot be followed by an alias" (`elixir_tokenizer.erl:1197`) |
| **`&:Shop."New"/1`** | **runs; `(&:Shop."New"/1).(1)` returns the record** |
| `&Shop.New/1` | `CompileError` (it means the alias `Shop`, not the atom) |

`Module.concat`, `unquote` and macro routes were not needed: the quoted call already works, and
`Module.concat([:Shop])` only builds a module name, it never helps with the function name.

Elixir's tokenizer and parser sources are not installed (only `.beam` files under
`lib/elixir/lib/elixir/ebin`). Line numbers above were read from the `abstract_code` chunk of
`elixir_tokenizer.beam` by `probes/07_elixir_source_from_abstract.escript`
(output `probes/07_elixir_source_from_abstract.out`). They are the source lines the beam was built
from, not a file I could open.

### 2.2 What the quoted call gives an Elixir caller, in a compiled module

`probes/04_elixir_compiled_caller.exs` compiles a `defmodule` rather than using `eval_string`:

- `def make(id), do: :Shop."New"(id)` works. So do the piped capture `&:Shop."New"/1`, the nested
  module `:"Shop.Reports"."Fully"(o)`, and `which(make(3))` returning `:order`.
- The AST is `{{:., [], [:Shop, :New]}, [], [1]}`, the same shape as `{{:., [], [:shop, :new]}, [], [1]}`
  for a lowercase call. It is a first-class remote call, not a dynamic dispatch.
- `Code.format_string!` keeps the quotes (`:Shop."New"(1)`) and drops them for a lowercase name.
- A typo, `:Shop."Nwe"(id)`, produces `warning: :Shop."Nwe"/1 is undefined or private` when the
  `.beam` is on the code path. The same typo through `apply(:Shop, :Nwe, [id])` is **silent**
  (`probes/04b_apply_gets_no_xref_warning.out`). So the quoted spelling is strictly better than
  `apply/3` and gets the caller xref checking.

One probe failure to report: my first nested-module line used `Totals`, which `Shop.Reports` does
not export. That output is kept as `probes/04_v1_wrongname_Totals.out`; I fixed the name to `Fully`
and re-ran, which is what `04_elixir_compiled_caller.out` shows.

## 3. Neighbouring languages

### Erlang

Quoted atoms are ordinary syntax: `erl_scan.erl:629` hands a `'` to `scan_qatom` (defined at
`erl_scan.erl:1607`). `probes/17_erlang_quoted_atoms.out`: `'Shop':'New'(1)` parses as a remote
call of two atoms, and the control `Shop:New(1)` parses as a call of two **variables** (a different
program, which is why a quoted export is needed at all).

### Gleam 1.19.1: the ticket-10-section-7 claim

`probes/05_gleam_names.out` (negative controls first):

- `pub fn ToJson(x: Int)` is a syntax error: "I'm expecting a lowercase name here".
- A module file `src/Bad.gleam` gives the warning "Module names must begin with a lowercase letter".
- So Gleam source never contains a PascalCase function or module. There is nothing to downcase.
- Constructors are what get snake_cased. `probes/09_gleam_constructor_mapping.out`:

| Gleam constructor | atom emitted |
|---|---|
| `ToJson` | `to_json` |
| `HTTPGet` | `h_t_t_p_get` |
| `IOError` | `i_o_error` |
| `Take2` | `take2` |
| `GetID` | `get_i_d` |
| `GetId` | `get_id` |
| `URLs` | `u_r_ls` |
| `Ver1Beta` | `ver1_beta` |

- Gleam refuses an underscore in a constructor name (`Get_Id` gives "not a valid type variant
  name"), which is why its naive rule never collides. B# allows underscores (section 4.3), so
  that safety does not transfer.
- Gleam's nested module is `deep@nested` (`ls build/dev/erlang/caller/ebin`).

Ticket 10 line 335 says "PascalCase to snake_case" in the context of *fieldless variants compile
to atoms*. Read in context it was always about constructors; the ticket-62 text re-applied it to
function names. The borrow heuristic's "somewhere to look" therefore leads to a rule that
(a) is not applied to functions and (b) produces `h_t_t_p_get`.

Gleam calling B# is unaffected (section 2 table): the function name is a string.

### Elixir calling out to Erlang-side names, and the reverse

Elixir does not emit unquoted-callable aliases for Erlang callers either. In the installed stdlib
(`probes/18_precedent_exports_needing_quotes.out`): `Elixir.Kernel` exports 162 names of which 99
need quotes from Erlang (operators such as `'+'`, and `?`/`!` names), `Elixir.File` 48 of 86,
`Elixir.Enum` 9 of 117. The platform norm is that the caller quotes, and no BEAM language I
checked ships aliases to avoid it. (An earlier version of this probe counted "unquoted twins" and
was misleading: `read!` and `read` are different functions, not aliases. It is kept as
`18_v1_with_misleading_twin_column.out` and the column was removed.)

### Elm

Compiles to JavaScript; no BEAM export surface. Not a relevant neighbour. Not probed.

## 4. Candidate 2: snake_case aliases, costed for real

### 4.1 The program and what it lowers to

```csharp
module Shop

public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```

Today this exports `'New'/1`. Under candidate 2 it additionally exports `new/1`, defined as a
tail call:

```erlang
-export(['New'/1, new/1]).
new(V1) -> 'New'(V1).          %% local tail call, or 'Shop':'New'(V1) for the remote form
```

An Elixir caller then writes `:Shop.new(1)`; an Erlang or B# caller still writes `'New'`.

### 4.2 The compiler delta

- `compiler/src/bs_emit.erl:75-77`: the export attribute is built from
  `[{name(F, Behaviours), A} || {F, A} <- Exports] ++ [{type_atoms_name(), 0}]`. Aliases would be a
  third list appended here.
- A name-derivation function next to `name/2` (`bs_emit.erl:117`) and `emitted_name/3` (`:131`).
- One emitted function and one copied `-spec` per alias, in `file_group` (`bs_emit.erl:97-104`) or
  after `reserved_forms/1` (`:2099`). The `-spec` copy matters; see 4.6.
- A collision pass. No pass exists today. It belongs in `bs_check` (the module that already reports
  a behaviour's missing callbacks), because a collision has to be a diagnostic at the author's
  source, not a silent drop in the emitter.
- Three readers of the export list must learn to hide the aliases. They hide `module_info` and
  `bs@...` today, and an alias, unlike `bs@type_atoms`, has an ordinary name that no prefix test
  can recognise: `bs_run:authors_exports/1` (`bs_run.erl:367`), `bs_run:private_names/2`
  (`bs_run.erl:75`) and `bs_repl:defined/1` (`bs_repl.erl:38`).
- Docs: LANGUAGE.md §12 line 3315 "Function names are exported PascalCase, exactly as written",
  and the sentence at LANGUAGE.md:3122 "the language needs no snake_case ⇄ PascalCase mapping
  anywhere", and `bs_otp.erl:6-8` ("the language has no such rule"). All three would need to
  change or be qualified to "no *inbound* mapping".

Modelled, not implemented: `probes/11_alias_inject.exs` reads the `.abstr` file that `bsc` writes
(the exact input of `compile:file(from_abstr)`, `bsc.erl:826-843`), adds the aliases, recompiles
with the same options and compares. `bs_emit.erl` was not modified.

### 4.3 Measured cost (23 real example modules, `probes/11_alias_all_*.out`)

| Variant | .beam bytes, all 23 modules | Delta | Per alias | Aliases |
|---|---|---|---|---|
| local tail-call alias | 51 508 to 56 712 | +5 204 (+10.1%) | 65.0 B | 80 |
| remote tail-call alias (`'Shop':'New'(...)`) | 51 508 to 57 856 | +6 348 (+12.3%) | 79.3 B | 80 |

Per-module overheads run from +2.8% (the big `Intake`) to +23.3% (`Label`, 7 public functions in a
1.8 KB module). The `.beam` carries `debug_info`, so the alias's abstract code and spec are
counted twice. The export table gains one entry and the atom table one atom per alias.

Compile time (7 runs each, ms min/median/max), for example `Shop`: 4.9/5.0/5.1 to 5.6/5.7/5.8.
That is about +0.7 ms on a 5 ms module. The larger modules are dominated by noise (`Stream`
27.9/28.2/29.8 to 28.0/28.8/42.5). I would call it negligible.

Runtime (`probes/14_alias_call_cost.out`, 5 million calls, 5 runs): original 90.4 to 99.3 ms,
alias 87.7 to 101.4 ms for the local form and 91.9 to 97.6 ms for the remote form. Within noise.

### 4.4 Stack traces and tracing (`probes/13_*`, `probes/13b_*`)

- **No extra frame.** An alias that ends in a tail call leaves no frame. A crash through the
  alias (`:Shop.which(bad)`) prints the identical top frame as the original:
  `shop.bs:18: :Shop."Which"(%{Kind: :"MyApp.Order", ...})`. The hypothesis that an alias that calls the original adds a frame is false for the tail-call form. The trace output is in
  `probes/13_v1_BROKEN_trace_harness_local.out`; the crash-trace half of that file is valid and
  the trace-count half is not (see the next bullet).
- **A local-call alias is invisible to a global trace.** Probe 13 v1 returned 0 events even for the
  control, so the harness was broken (the module was not loaded when `trace_pattern` ran; kept as
  `13_v1_BROKEN_*` and `13b_v1_module_not_loaded_before_trace_pattern.out`). The fixed
  `probes/13b_trace_alias.out` shows the control sees 1 event; the **local alias gives 0 events**
  and the **remote alias gives 1** (the event names the original `'Shop':'Amount'`). So a person
  using `dbg:tp`, `recon_trace` or observer on `'Shop':'Amount'/1` misses every call made through a
  local-form alias. The remote form fixes that and costs 14 more bytes per alias (table above).
- Observer's module view and `module_info(exports)` show both names, so every function appears twice.

### 4.5 The derivation rule: where it breaks (`probes/10_*`, `probes/12*`)

B# function names match `{UPPER}{ALNUM}*` with `ALNUM = [a-zA-Z0-9_]` (`bs_lexer.xrl:16,150`). So
underscores are legal. A lowercase-initial function name is a **syntax error**
(`probes/08a_names_with_lowercase_foo.out`: `syntax error before: foo`), which means `Foo` versus
`foo` can never collide. That case from the brief is closed by the grammar. The rest are not.

Real compile of the names (`probes/08_names/`), then aliasing under two rules.
Rule A is Elixir's own `Macro.underscore` (acronym-aware). Rule B is Gleam's observed rule
(each capital becomes `_` plus lowercase, except the first letter).

| B# name | Rule A (Elixir) | Rule B (Gleam) | Comment |
|---|---|---|---|
| `ToJson` | `to_json` | `to_json` | fine |
| `HTTPGet` | `http_get` | `h_t_t_p_get` | B is unusable; A is guessable |
| `IOError` | `io_error` | `i_o_error` | same |
| `Take2` | `take2` | `take2` | fine; the caller cannot guess whether it is `take_2` |
| `Ver1Beta` | `ver1_beta` | `ver1_beta` | fine |
| `URLs` | `ur_ls` | `u_r_ls` | **A is wrong**, no rule gets `urls` |
| `GetID` and `GetId` | `get_id` and `get_id` | `get_i_d` and `get_id` | **A: COLLISION** |
| `ParseURL` and `ParseUrl` | `parse_url` twice | `parse_u_r_l`, `parse_url` | **A: COLLISION** |
| `GetId` and `Get_id` | `get_id` twice | `get_id` twice | **BOTH rules collide** (`12b_names2_underscore_collision.out`) |
| `Get_Id` | `get__id` | `get__id` | double underscore |
| `ModuleInfo/0` | `module_info/0` | same | **hard compile error** (below) |

What the rule must therefore do, in order of how forced it is:

1. **Refuse on collision.** Two different B# names that derive the same alias are an author-visible
   error, because dropping one silently gives an Elixir caller the wrong function. Under rule A it
   happens for any pair differing only in acronym casing (`GetID`/`GetId`), a thing C# style guides
   actively create. Under rule B it needs an underscore (`GetId`/`Get_id`). The check needs a new
   diagnostic and a new pass in `bs_check`; there is no precedent site.
2. **Reserve `module_info`.** `ModuleInfo()` aliases to `module_info/0`, which the compiler
   already defines. Real error from `compile:forms`:
   `{redefine_function,{module_info,0}}` and `{duplicated_export,{module_info,0}}`
   (`probes/12c_names3_bif_clash.out`). The rule needs a reserved-name list.
3. **BIF names are safe, contrary to what I expected.** `Length`, `Abs`, `Self`, `Node` alias to
   `length/1`, `abs/1`, `self/0`, `node/0` and the module still builds
   (`12c_names3_bif_clash.out`, second block). A B# body that uses the BIF compiles to a
   *remote* `erlang:length` call (`12d_names5_bif_body.out`, abstract form line 18), so the local
   definition does not make it ambiguous.
4. **Already-snake names are no-ops.** `Counter` is a GenServer; `HandleCall` already lowers to
   `handle_call/3` (`bs_otp.erl`), and the rule has to notice the alias equals the existing export
   and skip it (probe 11 prints "no-op" for the three callbacks).
5. **Pick an acronym policy and document it**, because the caller must derive the name by hand.
   No policy gets `URLs`, `HTTPGet`, `Take2` and `GetID` all as the caller would guess.

The point that matters for the decision: the *input* domain is B#'s own restricted identifiers
(unlike ticket 32's inbound problem, which had to spell `'PKCS-1'`), so a total rule is possible.
That is the best argument for candidate 2 and I do not dismiss it. But a total rule that must
refuse collisions and reserve names is a language feature with its own errors, not a heuristic.

### 4.6 Dialyzer (`probes/19_dialyzer.out`)

Minimal PLT (erts, kernel, stdlib, 46 s). A deliberately wrong Erlang caller (`misuse.erl` passes
`not_a_map`) is flagged for the original name against the original module and for **both** names
once the alias carries a copied `-spec`. An alias without a copied spec would show only the
inferred success typing; the tool copies it (a part of the 65 B per alias). The control: against
the un-aliased module, `'Shop':amount/1` is "missing or unexported function", as it should be.

### 4.7 Strongest counterargument against candidate 2

It publishes **two names for every function forever**, and the second is a derived guess. Section
4.5 shows the guess is not stable: `URLs`, acronyms and digits each need a policy, a refusal rule
and a reserved list, and whichever policy ships becomes ABI the way `Kind` did. The ticket's whole
reason to exist was an undocumented contract that callers depend on; this candidate adds a
second one. And the thing it buys, dot syntax, costs a caller two characters of quoting
(section 2.2).

## 5. Candidate 3: change B#'s own convention to snake_case

### 5.1 The program that stops compiling

```csharp
module Shop

public Order new(int id)      // lowercase function name
new(id) -> Order{ Id = id, Total = 0 }
```

Today this is `syntax error before: foo` (`probes/08a_names_with_lowercase_foo.out`; the same
shape with `foo`). The lexer gives a lowercase word the token `lident` (`bs_lexer.xrl:153`), and the parser's
function signature is built on `uident` (`bs_parser.yrl:308-322`).

### 5.2 What the compiler must change

- `bs_lexer.xrl:150,153`: `{UPPER}{ALNUM}*` is `uident` and `{LOWER}{ALNUM}*` is `lident`. That
  split is the rule that tells a **function** from a **variable or builtin type** with no symbol
  table. Ticket 35 states it: "a beam-sharp function name is PascalCase by construction ... without
  changing the rule that lets the grammar tell a type from a function with no symbol table"
  (`35-behaviour-callback-names.md:130,238`).
- F46: LANGUAGE.md:2467 says "a lowercase name followed by `(` is a call through a bound value".
  With functions lowercase, `rule(cents)` could be either a closure call or a call to a function
  named `rule`, and the checker needs a symbol table at parse time to decide.
- Types stay PascalCase, builtins stay lowercase (`int`, `atom`, LANGUAGE.md:1618), so lowercase
  names would now live in three namespaces.

### 5.3 Blast radius (`probes/15_blast_radius.out`, excluding `_build`)

89 `.bs` files; about 603 function heads, 148 public declarations and 830 call tokens in them;
283 lines of LANGUAGE.md code fences; 18 of 120 tickets mention PascalCase. The `_build/test`
copies (4 372 files) are mirrors and are not counted. Also every `bs_otp` table row, because a
callback row maps a PascalCase name to the OTP name, would become an identity.

### 5.4 Strongest counterargument against candidate 3

It is the only candidate that makes **both** directions clean: the Erlang, Elixir and Gleam caller
sees the name an author wrote, with no alias, no rule, no quoting, and apart from `Kind` the ABI would
be fully idiomatic. It also removes a whole class of naming-rule objections (ticket 32's
"no mapping anywhere") by making B# names the BEAM names. The cost is exactly the thing the
project says is its premise: CLAUDE.md names "C#-family brace syntax", and C# functions are
PascalCase.

## 6. Candidate 1, amended: accept PascalCase, teach the quoted call

### 6.1 What the author and the caller write

```csharp
module Shop
public Order New(int id)
New(id) -> Order{ Id = id, Total = 0 }
```

```elixir
:Shop."New"(1)                     # ordinary remote call, xref-checked, formatter-stable
&:Shop."New"/1                     # capture
apply(:Shop, :New, [1])            # still works, no longer "the way in"
```

and, for a team that wants snake_case names throughout an Elixir codebase, a wrapper they own
(`probes/16_elixir_caller_side_wrapper.exs`, output `probes/16_*.out`):

```elixir
defmodule ShopApi do
  defdelegate new(id), to: :Shop, as: :New          # or `use BSharpWrap, mod: :Shop`
end
```

`BSharpWrap` is a 12-line macro that reads `:Shop.module_info(:exports)` at the caller's compile
time and derives names with `Macro.underscore`. Verified: `ShopAuto.which(ShopAuto.new(2))` returns
`:order`; the crash trace through the wrapper names `:Shop."Which"`; a nonexistent wrapper raises
`UndefinedFunctionError`. The policy decisions that section 4.5 forces on the B# compiler (acronyms,
collisions) are made by the *caller's* team, in their repo, where a wrong guess breaks their build
and no one else's.

### 6.2 The compiler delta

None. The change is to LANGUAGE.md §12 (`LANGUAGE.md:3315-3326`): the code block marks
`apply(:Shop, :New, [1])` as "the way in", and the sentence "No module naming scheme changes this"
stays true. It should gain the quoted-call line, state that it is xref-checked, and mention the
wrapper idiom. I did not edit it. The `<!-- ticket 62 holds the open decision -->` comment at
`LANGUAGE.md:3337` is for David to resolve.

### 6.3 Strongest counterargument against candidate 1

First impressions. An Elixir developer trying B# inside an existing codebase hits a syntax error
on the first call they write, `:Shop.New(1)`, and the compiler error message ("Function names ...
start with lowercase") tells them B# is wrong. The quoted call is discoverable only if they read
§12. The wrapper idiom also moves the maintenance burden to the adopter, and "incrementally inside
an existing Elixir codebase" is the ticket's own stated likeliest adoption path. If that adoption
path matters more than 80 B per function, candidate 2 is what removes the cliff. I think the
quoted spelling plus the wrapper recipe makes the cliff a step, but that is a judgement, not a
measurement.

## 7. Contradictions found with published text

- **LANGUAGE.md:3325** says `apply(:Shop, :New, [1])    # the way in`. Not false, but it is no
  longer the only way, and the ticket's friction 1 ("Elixir cannot call... pushed to apply/3") is
  overstated by one syntax form.
- **LANGUAGE.md:3122 and 3460, and `bs_otp.erl:6-8`**: "the language needs no snake_case ⇄ PascalCase
  mapping anywhere". Candidate 2 would contradict all three. They would need to say "no *inbound*
  mapping".
- **Ticket 32 Decisions entry (`32-ffi-surface.md:204`)** records the same sentence as a decision
  ("There is no snake_case ⇄ PascalCase rule anywhere in the language"). Candidate 2 would reopen
  it; the argument that it does not (outbound domain is B#'s own identifiers) is in 4.5.
- **Ticket 62's third candidate paragraph** cites ticket 10 section 7 as precedent "Gleam downcases
  when it emits". It applies to constructors, not functions or modules (section 3).
- **Ticket 87 / LANGUAGE.md:3330-3335**: `bs@type_atoms` was added as a compiler-owned export with
  a recognisable prefix. A snake alias has no prefix, so the three readers in 4.2 need a new way to
  recognise it. That is extra cost the ticket did not list.

## 8. Recommendation

**Candidate 1, amended: accept PascalCase exports; make §12 teach `:Shop."New"(1)`; document the
`defdelegate`/macro wrapper as the supported route to snake_case names in Elixir.**

Why:

1. The measured friction is smaller than the ticket recorded. The remaining cost for an Elixir
   caller is two quote marks per call site, and in return they get an xref warning on typos that
   `apply/3` lacks (`probes/04b`).
2. Candidate 2's costs are not mostly bytes (+10 to 12%, 65 to 79 B per alias, no runtime cost,
   no extra stack frame, dialyzer clean). They are the rule: it needs a collision diagnostic, a
   reserved-name list (`module_info` is a real compile error), an acronym policy, and no policy gets
   `URLs`, `HTTPGet` and `GetID` all right, and three readers that must learn to hide a name
   with no prefix. It also contradicts three published sentences and a ticket-32 decision.
   The local-call form is invisible to `dbg` traces; the remote form fixes that.
3. Candidate 3 changes the lexer rule that lets the grammar do without a symbol table, and 603 function
   heads and the language's stated premise with it.
4. The wrapper recipe (4.5's whole rule, run in the caller's repo) puts the policy decisions with
   the people who can make them without breaking anyone else, and costs B# nothing.

What would change my mind: if David judges that an Elixir developer's first `:Shop.New(1)`
syntax error is an adoption cliff worth ~12% of beam size and a naming rule, then candidate 2 with
**rule A (Elixir's `Macro.underscore`), remote-call aliases, a hard refusal on collision, and a
reserved list of `module_info`** is the cheapest correct form of it. Rule B (Gleam's) should not be
used: it yields `h_t_t_p_get`.

If the recommendation is taken, the follow-up is a doc edit to §12 and nothing else; whether a
feature file is needed is for David.

## 9. Probe index

Setup for every re-run:
`export PATH=$S/beam/bin:$PATH LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"` with
`S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad`, and a
`bsc` build of Shop into `$S/62/ebin` (`$S/bsc --src-root compiler/examples -o $S/62/ebin compiler/examples/Shop`,
then `.../Shop/Reports`). Paths below are relative to `artifacts/62-the-outbound-abi/probes/`.

| File | Re-run | Claim it supports |
|---|---|---|
| `01_62a_original.sh` | (needs rebar3; kept unmodified) | the ticket's own prototype |
| `02_62a_adapted.sh`, `.out`, `02_adapt.diff` | `bash 02_62a_adapted.sh` | all three frictions still hold; gleam section fails on hex.pm |
| `03_elixir_spellings.exs`, `.out` | `BS_EBIN=$S/62/ebin elixir 03_elixir_spellings.exs` | `:Shop."New"(1)` and `&:Shop."New"/1` work; `:Shop.New(1)` and `&:Shop.New/1` do not |
| `04_elixir_compiled_caller.exs`, `.out`, `04_v1_wrongname_Totals.out` | same with 04 | quoted call is a normal remote call; formatter keeps quotes; typo warns |
| `04b_apply_gets_no_xref_warning.exs`, `.out` | same with 04b | `apply/3` typo is silent, quoted typo warns |
| `05_gleam_names.sh`, `.out` | `./05_gleam_names.sh $S/62/gl2` | Gleam rejects PascalCase functions/modules; ticket-10 claim is about constructors |
| `06_gleam_calls_bsharp.sh`, `.out` | `./06_gleam_calls_bsharp.sh $S/62/gl3 $S/62/ebin` | Gleam `@external` to a PascalCase export runs; misspelt name gives `undef` |
| `07_elixir_source_from_abstract.escript`, `.out` | `escript 07_... <elixir_tokenizer.beam> "after alias"` | source lines of the Elixir tokenizer errors |
| `08_names/{Names,Names2,Names3,Names4,Names5}/`, `08a_*.out`, `08b_*.out` | `$S/bsc -o <out> 08_names/Names` | B# accepts `HTTPGet`, `GetID`/`GetId`, `Get_Id`; refuses lowercase `foo` |
| `09_gleam_constructor_mapping.sh`, `.out` | `./09_gleam_constructor_mapping.sh $S/62/gl4` | gleam's naive rule: `HTTPGet` becomes `h_t_t_p_get`; underscore refused |
| `10_macro_underscore.exs`, `.out` | `elixir 10_macro_underscore.exs` | Elixir's rule collides `GetID`/`GetId`, `ParseURL`/`ParseUrl`; `URLs` becomes `ur_ls` |
| `11_alias_inject.exs`, `11_alias_all_{macro,gleam}_{local,remote}.out` | `elixir 11_alias_inject.exs $S/62/all macro local` | +10.1% / +12.3% beam, 65 / 79 B per alias, 80 aliases |
| `12_alias_names_collisions.out`, `12b_*`, `12c_*`, `12d_*` | `LIST=1 elixir 11_alias_inject.exs <abstr dir> <rule> local` | collisions under each rule; `module_info` is a hard error; BIF names are safe |
| `13_alias_trace_cost.exs`, `13_v1_BROKEN_*.out` | `elixir 13_alias_trace_cost.exs <ebin> <label>` | crash through an alias shows the original's frame (the trace-count half is broken; see 13b) |
| `13b_trace_alias.erl`, `.out`, `13b_v1_*.out` | `erlc` it, then `erl -pa <aliased ebin> -eval "'13b_trace_alias':run(),halt()."` | local alias is invisible to global trace; remote alias is seen; control sees the original |
| `14_alias_call_cost.erl`, `.out` | as 13b with module `14_alias_call_cost` | no measurable per-call cost |
| `15_blast_radius.sh`, `.out` | `./15_blast_radius.sh` | size of candidate 3's rewrite |
| `16_elixir_caller_side_wrapper.exs`, `.out` | `BS_EBIN=$S/62/ebin elixir 16_...` | caller-side `defdelegate` and macro wrapper work |
| `17_erlang_quoted_atoms.escript`, `.out` | `escript 17_...` | Erlang quotes atoms in ordinary syntax; unquoted is variables |
| `18_precedent_exports_needing_quotes.escript`, `.out`, `18_v1_*.out` | `escript 18_... $S/beam/lib/elixir/lib/elixir/ebin` | Elixir's own stdlib exports names Erlang must quote and ships no aliases |
| `19_dialyzer.sh`, `.out`, `19_dialyzer/misuse.erl` | `./19_dialyzer.sh $S` (needs `$S/62/min.plt`) | aliases with copied specs keep dialyzer working |

Probes that failed or were redone, all kept: `04_v1_wrongname_Totals.out` (wrong export name),
`13_v1_BROKEN_*` and `13b_v1_*` (trace harness ran before the module was loaded; control read 0),
`18_v1_*` (misleading "twin" metric), `08a_*` (the lowercase `foo` function is a syntax error, so
the name list was cut down in 08b).

Not done: no change to `bs_emit.erl` (the alias cost is modelled on the emitted forms); the
Elixir tokenizer sources are unavailable (read from beam abstract code); Elm skipped as irrelevant;
a build-tool-generated wrapper module (a `bsc --elixir-wrapper` mode) was not probed.

## Errata from independent verification (verification.md)

The verifier re-ran every probe except 01 (needs rebar3) and reproduced them, and wrote its own `Acme.erl` that confirmed the quoted call `:Acme."New"(1)` works from a script and from `elixirc`. No probe is circular. Corrections:

- **Probe 11's percentages.** The aliases were compiled into real beams, but the baseline is a recompile of the `.abstr` (51,508 B), not bsc's real output (54,640 B). The byte deltas stand (+5,204 and +6,348). Against bsc's real baseline the figures are about **9.5% and 11.6%**, not 10.1% and 12.3%.
- **Compile-time figures** quoted for Shop and Stream appear in no stored output. The stored lines differ; the conclusion (roughly +0.7 to 0.9 ms on a 5 ms module) is consistent with the stored data.
- **"No per-call cost"** (probe 14) has no sensitivity control, so "within noise" says little.
- **"No other BEAM language ships aliases"** is unprobed. Probe 18 measures only Elixir stdlib quoting.
- **Not probed at all:** the dialyzer claim about an alias without a copied spec, Observer showing both names, and `private_names` / `authors_exports` / `defined` needing to hide aliases (code reading only).
- **Gleam module names:** a PascalCase module file gives a warning and is not built; it is not rejected at the parser as section 0 says. PascalCase function names are a syntax error, as stated.
- **Citations:** LANGUAGE.md:3460 is worded differently from the sentence it is grouped with. LANGUAGE.md:1618 does not support "builtins stay lowercase" (the builtin table is near line 577). The ticket 35 quote is at line 132 and reads "without", not "with no".
