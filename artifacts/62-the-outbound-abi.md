# 62 — What B# looks like from the outside: the outbound ABI

Status: brief only; ticket left OPEN for David. Authored against HEAD 019533d, Elixir 1.18.5, OTP 28, gleam 1.19.2.

## What the ticket asks, and what changed

Ticket 62 ([ENG-252](https://linear.app/davewil/issue/ENG-252)) asks what a B# module presents to an Erlang/Elixir/Gleam caller. Two of its three frictions are already settled: the module prefix (closed, not reopened here) and the `Kind` tag (David, 2026-08-25: written down in LANGUAGE.md §12, `Kind` contract). **One decision remains: the casing of exported function names for Elixir callers** — (1) accept, (2) emit snake_case aliases, (3) change B#'s convention.

Since the ticket was written: `bs@type_atoms/0` is exported from every module (ticket 87 / ENG-398, LANGUAGE.md §12), and `bs_otp` renames behaviour callbacks (`HandleCall` -> `handle_call`, ticket 35). The first sits beside the author's exports; the second is an outbound PascalCase->snake_case rename that already ships (see "Findings 5").

**Two premises of the ticket do not survive measurement** (Findings 1 and 4): Elixir *can* call a PascalCase export without `apply/3`, and the Gleam "precedent" for aliases is a misreading.

## The gating question, alone

**Is Elixir's `:Shop."New"(1)` an acceptable way to call B#?**

If yes, nothing else is owed; option 1 stands and the only work is a sentence in LANGUAGE.md §12 (which currently says `apply/3` is "the way in"). If no, the follow-ups are: what the alias name-derivation rule is and what happens on a collision (option 2), or the whole surface changes (option 3, which 62's own text calls the largest blast radius and whose lexer split ticket 26's casing rule depends on, see below). Do not ask those until the gate is answered.

## Findings

### 1. "Elixir cannot call a PascalCase export; `apply/3` is the way in" — REFUTED

Probe `62_elixir_syntax.sh` (rerun of 62a's table on Elixir 1.18.5, plus the quoted-name forms the ticket did not try). Excerpt of `62_elixir_syntax.out`:

```
:Shop.New(1)                    SYNTAX_ERROR
:"BSharp.Shop".New(1)           SYNTAX_ERROR
:"Elixir.Shop".New(1)           SYNTAX_ERROR
(&:Shop.New/1).(1)              SYNTAX_ERROR
m = :Shop; m.New(1)             SYNTAX_ERROR
:"BSharp.Shop".new(1)           parses, UndefinedFunctionError (module not available)
apply(:Shop, :New, [1])         ok -> %{Kind: :"Shop.Order", Total: 0, Id: 1}
:Shop."New"(1)                  ok -> %{Kind: :"Shop.Order", Total: 0, Id: 1}
:Shop.'New'(1)                  ok
(&:Shop."New"/1).(1)            ok
1 |> :Shop."New"()              ok
m = :Shop; m."New"(1)           ok
:"Shop.Reports"."Restate"(3)    ok -> 9        (unquoted :"Shop.Reports".Restate(3): SYNTAX_ERROR)
:Shop."Nope"(1)                 UndefinedFunctionError   (control: quoted form really dispatches)
```

The ticket's SYNTAX_ERROR rows are all CONFIRMED. What it missed: **Elixir accepts a quoted function name after a dot**, for any atom module. It is a plain remote call, not a macro trick. `62_elixir_compiled_caller.sh` compiles a real Elixir module with `elixirc`:

- `:Shop."New"(id)`, `id |> :Shop."New"() |> :Shop."Pay"() |> :Shop."Amount"()` and `&:Shop."New"/1` compile with **no warning** and run (`500` for the pipe).
- Control: `:Shop."Nope"(id)` warns `:Shop."Nope"/1 is undefined or private`. So the compiler's remote-call checker reads the B# `.beam` and *validates* quoted PascalCase calls (typos are caught at Elixir compile time).
- `defdelegate new(id), to: :Shop, as: :New` in an Elixir shim module works (`1 |> ShopEx.new() |> ShopEx.pay() |> ShopEx.amount()` -> `500`), one line per function, giving Elixir callers snake_case on their side with no change to B#.
- Staleness: the ticket's `:"Shop.Reports".Totals(1)` row names a function `Shop.Reports` does not export at HEAD (exports: `Restate`, `Counted`, `Fully`); I kept the row (it errors for syntax before the name matters) and added the real `Restate` rows.
- LANGUAGE.md §12 repeats the claim: `apply(:Shop, :New, [1])    # the way in` and "costs Elixir its call syntax". Both overstate; it costs two quote marks.

Why (source, fetched from github tag v1.18.5 since the nix store ships only `.beam`s; `elixir_tokenizer.erl` 1843 lines, `elixir_parser.yrl` 1335):
- `elixir_tokenizer.erl:664`: `_ when Kind == alias -> tokenize_alias(...)` — after a `.`, a bare capitalised token is lexed as an `alias` token, hence the parser rule `elixir_parser.yrl:471`: `dot_alias -> matched_expr dot_op alias : build_dot_alias(...)`, which only builds `__aliases__` (a module path), never a call.
- `elixir_tokenizer.erl:912`: `handle_dot([$., H | T] = Original, ...) when ?is_quote(H) ->` extracts the quoted string, `unsafe_to_atom`s it, and emits `check_call_identifier(Line, Column, H, Atom, Rest)`: a *call identifier*, any atom. Lines 913-935 show its only objection to a quoted name is a warning when the quotes are unnecessary (`is_unnecessary_quote`, `:988`, true only when the text tokenizes as a plain `identifier`; "New" tokenizes as an alias, so no warning, as observed).

### 2. "Erlang is unaffected" — CONFIRMED

`62_erlang_caller.sh`: an `erlc`-compiled module calling `'Shop':'New'(Id)` returns the map; control `'Shop':new(1)` against the stock compiler is `undef`.

### 3. "Gleam is unaffected; `@external(erlang, "Shop", "New")` compiles" — CONFIRMED, and the ticket's "call was not run" gap is closed

`62_gleam_case.sh` section 4: `caller:main() -> #{'Kind' => 'Shop.Order','Total' => 0,'Id' => 7}`; Gleam's beam imports `[{'Shop','New',1}, ...]`.

### 4. "Gleam downcases when it emits to the BEAM — PascalCase becomes snake_case" (ticket 10 §7) as precedent for option 2 — PARTLY: real for constructors, a misreading for functions

Ticket 10 line 335 reads, in full: *"Fieldless variants compile to atoms, variants with fields to tagged tuples, PascalCase to snake_case. The constructor **is** the declaration site."* That sentence is about **custom-type constructors becoming data atoms**. Ticket 62 reads it as a function-export transform. `62_gleam_case.sh` (output in `62_gleam_case.out`):

```
pub fn NewOrder(...)   -> error: Syntax error ... I'm expecting a lowercase name here
pub fn newOrder(...)   -> error: Invalid function name ... Try: new_order
src/Shop.gleam         -> warning: Invalid module name ... (no .beam produced)
deep@nested exports    -> [{make,0},{mk2,0},{module_info,0},{module_info,1}]
make()  [Circle(1), MyHTTPThing, HTTPServer(2), X2Y, GetURL2]
        -> [{circle,1}, my_h_t_t_p_thing, {h_t_t_p_server,2}, x2_y, get_u_r_l2]
mk2()   MyType(3) -> {my_type,3}
```

- Gleam does **not** downcase functions or modules: it *rejects* PascalCase for both at the front end. Functions are snake_case in source; modules are snake_case paths joined with `@`. There is no alias, no export pair.
- The only downcasing is constructor *atoms* (data), by a naive per-capital rule: `MyHTTPThing` -> `my_h_t_t_p_thing`, `GetURL2` -> `get_u_r_l2`. That rule is acronym-hostile; it is evidence that a derivation rule needs decisions, not a precedent for aliasing.
- Gleam source lines for this were unavailable (binary only); the claim rests on running the compiler.

Verdict on the precedent: **a misreading. No neighbouring BEAM language emits two spellings of an exported function.** Option 2 would be novel, not borrowed.

### 5. Is "no snake_case<->PascalCase rule anywhere in the language" (tickets 32, 35) in tension with option 2? — PARTLY

Ticket 32 closed a rule on *inbound* names, on evidence that a mapping cannot spell `'PKCS-1'` or `fetch!`. Outbound the domain is smaller and total: a B# function name is `[A-Z][a-zA-Z0-9_]*` (`bs_lexer.xrl:150`, `uident`), so every name has an image. But the mapping is **not injective**: `62_alias_prototype.sh` section A: `GetUrl`, `GetURL`, `Get_Url` all derive `get_url/1`, and `ModuleInfo/1` derives `module_info/1`, which the VM already defines. Ticket 35 did ship an outbound rename, but through a fixed table scoped to a declared behaviour's `{name, arity}`, "which is what stops it being a naming rule by another route". Option 2 *is* the naming rule by another route, and ticket 32/35 closed that.

Also: a lowercase function name cannot be written in B#: `public int new(int id)` -> `lower.bs:3:12: error: syntax error before: new`, so a snake alias can never collide with an *authored* B# function; collisions come only from the derivation itself and from VM-reserved names.

## Neighbours

| | what they do | evidence |
|---|---|---|
| Erlang | quoted atoms; any function name callable with ordinary syntax | `62_erlang_caller.out` |
| Elixir | `.Capitalized` is an alias token (`elixir_tokenizer.erl:664`, `elixir_parser.yrl:471`); `."Quoted"` after a dot is any atom call (`elixir_tokenizer.erl:912`) | `62_elixir_syntax.out`, `62_elixir_compiled_caller.out` |
| Gleam | rejects PascalCase functions and modules; constructors become snake_case data atoms; `@external(erlang, "Shop", "New")` names foreign functions as strings and runs | `62_gleam_case.out` |
| Elm | **not run**: `elm make` needs `package.elm-lang.org` (403 via the proxy; `~/.elm/0.19.2/packages` is empty). From general knowledge, not measured here: ports target JavaScript only, so Elm offers no outbound-to-BEAM precedent either way. |

## Measurements

Option 2 prototyped on a patched copy of the compiler (`62_alias_exports.patch`, +~45 lines in `bs_emit.erl`; repo `compiler/` untouched). All from `62_alias_prototype.out`.

| measure | stock | alias patch | n / unit |
|---|---|---|---|
| exports over 23 top-level `compiler/examples` modules (excl. `module_info`) | 106 | 186 (+80) | exports |
| total `.beam` bytes, same 23 modules | 54,456 | 58,796 (+4,340, +8.0%) | bytes, one build |
| toy 7-function module `Awk.beam` | 1,564 | 1,952 (+388, ~55 per alias) | bytes |
| compile time, `bsc` on `Shop`, wall incl. VM start | min 407, median 477 | min 447, median 465 | ms, n=7 (**indistinguishable**; ranges overlap, stock max 525) |
| call, direct `'Awk':'GetOrder'(X,Y)` | min 42.8, median 44.0 | | ms per 1e7 calls, n=7 (4.28 ns/call) |
| call via alias wrapper `'Awk':get_order(X,Y)` (local tail call) | | min 45.2, median 47.6 | ms per 1e7 calls, n=7 (4.52 ns/call) |
| call via duplicated clauses (same emitted body under snake name) | | min 42.3, median 45.2 | ms per 1e7 calls, n=7 (4.23 ns/call) |
| empty loop (control) | 13.7 / 15.0 | | ms per 1e7 |

Alias call cost is ~0.24 ns over direct (about 5%), duplication is free at run time but doubles function bodies in the beam (not measured separately; the wrapper form was the one built for the size rows). **Existing tests under the patch** (`62_alias_eunit.sh`, full `rebar3 eunit`, stock vs patched, same machine): stock Failed 5 / Passed 1443 (five environment failures, e.g. `a_path_is_utf8_on_the_wire_test`); patched Failed 13 / Passed 1435. **Eight tests fail only under the alias patch**: `visibility_tests` x3 (`a_private_function_is_not_exported_test` asserts the author's exports are exactly `[{'Fib',1}]`), `heads_tests:four_clauses_become_four_clause_heads_test` (exact emitted function set), `bindings_tests`, `intervals_tests` (same shape, not inspected further), and `otp_tests` x2: `without_a_behaviour_the_name_is_untouched_test` and `a_callback_of_another_behaviour_is_untouched_test` assert `handle_call/3` is **not** exported from a module that does not declare the behaviour (`otp_tests.erl:66`, `:87`). That last pair is ticket 35's pinned decision (the rename is scoped to a declared behaviour "which is what stops it being a naming rule by another route"); an alias export of `HandleCall` in every module is exactly that rule. Six of the eight are assertions about the export set that any alias design must rewrite; the two `otp_tests` are a decision, not an assertion.

**Not measured:** in-VM compile time without VM start-up, Dialyzer behaviour on alias exports (the prototype emits no `-spec` for aliases), and the repo's shell gates (`bin/verify.sh`).

Name derivation (acronym-aware, Elixir `Macro.underscore` shape), `62_alias_prototype.out` section A:

| B# name | alias | note |
|---|---|---|
| `New` | `new` | |
| `ToJSON` | `to_json` | |
| `HTTPGet` | `http_get` | |
| `X2Y` | `x2_y` | |
| `GetURL2` | `get_url2` | |
| `GetOrder/2` | `get_order/2` | arity kept |
| `GetUrl`, `GetURL`, `Get_Url` | all `get_url/1` | **collision**, prototype drops all three and prints `bs_alias_collision` |
| `ModuleInfo/1` | `module_info/1` | **collides with the VM's `module_info/1`** |
| `Init` in a `GenServer` module | none | already emitted as `init` (ticket 35), nothing to alias |

All aliased names reachable from Elixir as `:Awk.new(1)`, `:Awk.to_json(1)`, `:Awk.http_get(1)`, `:Awk.x2_y(1)`, `:Awk.get_url2(1)`, `:Awk.get_order(1,2)`; control `:Awk.nope(1)` -> `UndefinedFunctionError`. Erlang `'Awk':'New'(1)` and `'Awk':new(1)` both work. B#-to-B# unaffected: `'Shop.Reports':'Restate'(3)` -> 9, and `bsc ... Shop/Reports Restate 3` under the patched bsc prints `9`, because B# callers resolve `remote_names` to the PascalCase name and cannot spell a snake one.

Option 3 blast radius, `62_blast_radius.out` (regex count; **a lower bound**, calls and multi-line signatures not counted; control fixture prints 7/7):

| tree | files | public fns | private | clause heads |
|---|---|---|---|---|
| compiler/examples/*.bs | 75 | 115 | 60 | 359 |
| aoc/*.bs | 3 | 7 | 13 | 38 |
| handoff/*.bs | 25 | 29 | 0 | 31 |
| wayfinder/prototypes/*.bs | 45 | 72 | 14 | 144 |
| LANGUAGE.md (fenced) | | 154 | 16 | 271 |
| TOUR.md (fenced) | | 62 | 17 | 128 |

Mechanism, not just count: `bs_lexer.xrl:150` `uident = {UPPER}{ALNUM}*`, `:153` `lident = {LOWER}{ALNUM}*`; a lowercase function name is a syntax error today (above). Ticket 26's casing rule reads `Ets.Lookup` as a call because both segments are uppercase (32 line ~196); with lowercase function names, `Shop.new(1)` would lex as a field projection, which is what closed "identity by default" in 32e.

## Options

The same Elixir caller, three answers. The B# source is the same for 1 and 2: `module Shop` with `public Order New(int id)`.

### Option 1 — Accept it; document the quoted form

```elixir
order = :Shop."New"(1)                       # compiles today, no warning
1 |> :Shop."New"() |> :Shop."Pay"()          # pipes fine
defdelegate new(id), to: :Shop, as: :New     # optional Elixir-side shim
```
Refused: `:Shop.New(1)` (SyntaxError; Elixir reads `.New` as an alias). No change to B#.

Compiler delta: **none.** Doc delta: LANGUAGE.md §12's "`apply(:Shop, :New, [1])    # the way in`" becomes the quoted form (the `apply/3` line stays as the dynamic route); correct the "costs Elixir its call syntax" sentence.

Evidence: Findings 1-3. The Elixir compiler warns on a typo'd quoted call.

**Strongest counterargument, as its best opponent states it:** "An Elixir developer reads `:Shop.\"New\"(1)` and thinks 'this is generated or foreign code': it is the only place in their codebase that looks like that, and every call site carries it. Incremental adoption inside an Elixir codebase was the point of ticket 62's question, and the thing that makes a new language feel native is that `:shop.new(1)` just works. Your own measurement says the shim fix (`defdelegate`) costs one line per function on the *Elixir* side, which is the wrong side to put a tax on: every B# library author's users pay it, and nobody can tell them to."

### Option 2 — Emit snake_case aliases alongside

```elixir
:Shop.new(1)      # works; also :Shop."New"(1) and Erlang 'Shop':'New'(1)
```
Refused: any B# program whose derived alias collides, e.g. `GetUrl` + `GetURL` in one module (alias set is ambiguous), or `ModuleInfo/1` (clashes with `module_info/1`). In the prototype this *silently drops* the aliases and writes `bs_alias_collision: get_url/1 from 'GetUrl'` to stderr; the real version should be a diagnostic, which is a design choice not yet taken.

Compiler delta (prototyped and measured on a patched copy, `62_alias_exports.patch`):
- `bs_emit:forms/1`: an `alias_table/1` from the emitted public names, `snake/1` (the rule above), one extra `{Alias, Arity}` in the `-export` attribute and one `alias_form/3` wrapper (`new(A1) -> 'New'(A1).`) per entry.
- A collision rule and its diagnostic (`bs_check`, where all public names are known): the prototype's "drop silently" is not shippable.
- Alias `-spec`s (`spec_attr`), or Dialyzer sees untyped exports.
- Decide whether `bsc --api` and LANGUAGE.md §12 list both spellings; the `Kind` contract table is untouched.
- A gate that guards the language: the alias set of an exemplar module, plus the collision case red (CLAUDE.md: a gate needs `--self-test`).

Evidence: Findings 4-5 and Measurements: +80 exports and +8.0% bytes across the examples, ~5% on a call through the alias, compile time unchanged within noise, B# callers and Erlang callers unaffected. Compatibility with pinned behaviour is **not clean**: see the eunit row below. Not measured: Dialyzer, the repo's shell gates (`bin/verify.sh`).

**Strongest counterargument:** "Elixir callers are the first foreign users B# will have and the friction is the first thing they hit; eight percent of a beam and a nanosecond-scale tail call are nothing against *never asking an Elixir developer to write quoted PascalCase*. The rule is total on B# names (every name is `[A-Z]\w*`, so unlike the inbound census it has no unspellable case); only collisions need handling, and they are rare and compile-time detectable. Ticket 35 already established that the compiler may export a different spelling of a B# function."

Against that, the author's own findings: (a) no neighbour does it, so "Gleam does it" is wrong; (b) the rule is not free of judgement, since Gleam's own per-capital rule gives `my_h_t_t_p_thing` and this one needs `HTTPGet` -> `http_get`, which is a spec item the clean-room fleet must reproduce exactly; (c) it reopens ticket 32/35's "no naming rule" with a rule that has a collision class, and (d) the repo's own suite pins against it: eight existing tests fail under the patch, two of them ticket 35's "a module without the behaviour does not export `handle_call/3`".

### Option 3 — Change B#'s function convention to snake_case

```
public Order new(int id)      // today: syntax error before: new
```
Refused today: every lowercase function name. Accepted after: all of them; and `Shop.new(1)` must be told apart from the field projection `shop.new`.

Compiler delta: `bs_lexer.xrl` (`lident` for function declarations and heads), `bs_parser.yrl` (declaration/clause-head rules), ticket 26's casing rule (call vs projection), `bs_check` name resolution, `bs_otp` callback table (becomes the identity), and every B# program in the repo: the Option 3 table above (115+7+29+72 public functions in `.bs` files, ~290 in the two docs; lower bounds).

Evidence: counts above and the lexer lines. Not prototyped.

**Strongest counterargument:** "PascalCase functions are the C# family's, but the thing B# sells is multi-clause heads, not casing, and Erlang, Elixir, Gleam and Elm are all lower-case-function languages. One spelling everywhere removes the entire class of problem (quoted calls, aliases, callback tables, `bs_otp`), and the repo is small enough that the migration is a few hundred lines." Against: it throws away ticket 26's mechanism for telling a call from a projection, and 62's own text calls it "fights the C#-family syntax that is the language's whole premise".

## Recommendation

**Option 1**, with the LANGUAGE.md §12 correction and one line: "from Elixir, `:Shop.\"New\"(1)`; the Elixir-side shim `defdelegate new(id), to: :Shop, as: :New` gives snake_case without B# emitting anything".

Why: the ticket's whole case for 2 rested on two premises that measured false: that Elixir has *no* ordinary-syntax route (it has one), and that Gleam ships this transform (it does not). With both gone, option 2 pays +8% bytes, a new collision class, a new diagnostic, a spec item every clean-room implementer must match byte-for-byte, and a reversal of tickets 32/35's "no naming rule", to save two quote characters, when Elixir already offers `defdelegate` for callers who want snake_case.

What would change my mind: (a) an Elixir user, or David, deciding that `:Shop."New"(1)` is unacceptable at *call sites* and `defdelegate` at the library boundary is also unacceptable (the real question the gate asks); (b) discovering Elixir tooling that breaks on a quoted capitalised call (Dialyzer/xref on the caller side, the formatter, LSP; **I only ran the compiler and `elixirc` warnings, not these**); (c) a decision to publish B# libraries to hex.pm for Elixir apps, where the call-site tax is multiplied. If (a)-(c) happen, option 2 with a hard collision error (not silent drop) and alias specs is the shape, and the gate to write first is the exemplar alias set plus the red collision case.

## Probe log

- `62_elixir_syntax.exs` first run: syntax error in the probe itself (the `|` sigil delimiter collided with `|>`); changed the delimiter to `~S{}` and re-ran. Second error (`#` is not a legal delimiter), same fix. No row was edited after seeing output. The `Totals` rows were kept (the ticket's), `Restate` rows added after I found `Shop.Reports` has no `Totals`; the original row stays in the output.
- The `unquote` row, `n = "New"; :Shop.unquote(String.to_atom(n))(1)`, is `CompileError` when `eval_string`'d (unquote outside a quote); the macro-time form at the bottom (`Dyn.call_new(1)`, `def` generated with `unquote`) works: both are in `.out`.
- **Surprise:** I expected, from the ticket, that quoting would not help. It does. This is the finding that moves the recommendation.
- `62_gleam_case.sh`: first run's last step cat'd `_gleam_artefacts/caller.erl`, which Gleam does not keep; replaced with a `beam_lib` imports check and added the "does a PascalCase module file produce a beam" check. Expectation was the file would be accepted with a warning; the result (warning, no `.beam`) is in the `.out`.
- `62_alias_prototype.sh`: first run failed on shell quoting in the `erl -eval` and the Elixir string, and the bench inserted its `-export` after function forms (erl_lint rejects). All three were harness bugs, fixed, whole probe re-run; no numbers were changed by hand.
- The first run's compile-time rows had proto *faster* than stock (min 375 vs 420); the re-run reversed the order (407 vs 447). That is why the brief says "indistinguishable" rather than reporting a delta.
- `62_blast_radius.sh`: a stale first draft wrote a temporary `.py` into the probes dir; removed before the run that produced the `.out`. Counts are regex-based lower bounds.
- Elm: could not run (registry blocked); no probe.
- `62_alias_eunit.sh` was written after a first, unscripted `rebar3 eunit` on the patched copy showed 12 failures with no baseline. It is the scripted stock-vs-patched comparison; the unscripted run (12 failures) and the scripted one (13, one more flaky-environment failure `diagnostic_term_tests:the_diagnostics_gate_passes_test` present in both columns of the scripted run) differ only in that environment failure. Expectation before running: the patch would pass the suite except for export-list assertions. It broke a pinned-decision test too (otp_tests), which I did not expect.

## Probe index

All from `artifacts/probes/`, after `. ./env.sh`; each writes `<probe>.out`.

| probe | rerun | refuted if |
|---|---|---|
| `62_elixir_syntax.sh` (+`.exs`) | `./62_elixir_syntax.sh` | `:Shop."New"(1)` / `&:Shop."New"/1` / `m."New"(1)` do not print `ok`, or an unquoted form prints `ok`, or `:Shop."Nope"(1)` prints `ok` |
| `62_elixir_compiled_caller.sh` | `./62_elixir_compiled_caller.sh` | the `New`/pipeline calls warn or fail, or the `Nope` control stays silent, or `defdelegate ... as: :New` fails |
| `62_erlang_caller.sh` | `./62_erlang_caller.sh` | `ecall:a(1)` is not the map, or the snake control is not `undef` |
| `62_gleam_case.sh` | `./62_gleam_case.sh` | `pub fn NewOrder` compiles; or a PascalCase module yields a `.beam`; or the exports list shows downcased functions; or `caller:main()` is not the map |
| `62_alias_prototype.sh` (+`62_alias_exports.patch`, `62_alias_bench.erl`, `62_fixtures/{Awk,Coll,Lower}`) | `./62_alias_prototype.sh` (about 1-2 min: builds the patched compiler) | Awk's alias set differs from the table; no collision line for `GetUrl`/`GetURL`/`Get_Url`/`ModuleInfo`; `:Awk.new(1)` fails; a PascalCase call stops working; the bench's alias median exceeds direct by more than 10% |
| `62_alias_eunit.sh` | `./62_alias_eunit.sh` (about 10 min: two full `rebar3 eunit` runs) | the "failing ONLY under the alias patch" list is empty |
| `62_blast_radius.sh` | `./62_blast_radius.sh` | the control fixture does not print `(1, [7, 0, 7])` |

Source for Elixir citations (not in the nix store, only `.beam`): `https://raw.githubusercontent.com/elixir-lang/elixir/v1.18.5/lib/elixir/src/elixir_tokenizer.erl` and `.../elixir_parser.yrl`.
