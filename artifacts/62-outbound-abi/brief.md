# Decision brief: ticket 62, the outbound ABI (function-name casing seen from Elixir)

- Ticket: 62, [ENG-252](https://linear.app/davewil/issue/ENG-252)
- Status: **OPEN, undecided.** This brief is a recommendation. Nothing under `wayfinder/` was edited, no Linear change was made.
- Date: 2026-10-11
- Versions: OTP 29 (erts-17.1), Elixir 1.20.4 (built on OTP 27, run on 29 with `+fnu`), Gleam 1.19.1, repo rev `019533d`. The ticket's own numbers were taken on OTP 28 / Gleam 1.18.1.
- Probes: `probes/` (one command each, captured `.out` beside each; index in `probes/README.md`).

## 0. The headline

**The ticket's premise is wrong.** It says Elixir "cannot call a PascalCase export" and that `apply/3` is the way in. Elixir can, with ordinary syntax:

```
:Shop.New(1)         -> PARSE ERROR  (the only spelling the ticket tried)
:Shop."New"(1)       -> parses, runs -> %{Kind: :"Shop.Order", Total: 0, Id: 1}
```

A quoted function name after the dot is legal Elixir. Every call form that matters works with it: pipes, captures (`&:Shop."New"/1`), `Enum.map`, dynamic receivers, macros. So the friction is **ugly (two quote characters), not impossible**. `LANGUAGE.md` section 12 (lines 3299-3302) repeats the wrong claim, so the spec currently teaches `apply/3` as "the way in". That needs correcting whichever way the casing decision goes.

The one thing the quoted call does not give is `import :Shop` followed by a bare call (probe 01, T6).

## 1. Sub-decisions

1. **(Gating, ask alone.) Does B# owe Elixir callers a spelling without quotes (`:Shop.new(1)`, `import :Shop`), now that `:Shop."New"(1)` works?** If no, the ticket is closed by a documentation fix and everything below is moot. If yes, 2 and 3 follow.
2. (Only if 1 is yes.) Emitted by the compiler as aliases, or by a change of B#'s own convention?
3. (Only if aliases.) Which derivation rule, and what happens on a collision. This decision is a published ABI, because every Elixir caller's source then depends on the rule's output.

## 2. Claim ledger

| # | Claim | Probe | Result |
|---|---|---|---|
| 1 | Elixir has no way to call a PascalCase export except `apply/3` (ticket; `LANGUAGE.md` 3299-3302) | 01 | **REFUTED.** 14 spellings run: quoted call, charlist call (deprecated), variable receiver, pipe, no-parens, `Kernel.apply`, `:erlang.apply`, `Function.capture/3`, `&:Shop."New"/1`, `fn` wrapper, raw AST, `unquote` in a macro, `defdelegate`. Only the unquoted `:Shop.New(1)` is a syntax error. |
| 2 | `:Shop.New(1)`, `:"BSharp.Shop".New(1)`, `:"Shop.Reports".Totals(1)`, `:"Elixir.Shop".New(1)` are syntax errors | 01 (T1-T3, A1) | Confirmed, for the unquoted function name only. Quoted: `:"Shop.Reports"."Restate"(3)` runs -> `9`. |
| 3 | No module prefix rescues it | 01 (T1-T4) | Confirmed. The prefix is irrelevant; the quote on the function name is what matters. |
| 4 | Erlang is unaffected | 04, 03 | Confirmed (`'Abi':'MaybeInt'(true)` -> `1`). |
| 5 | Gleam `@external(erlang, "Shop", "New")` works | 03 | **Confirmed, and now RUN** (ticket only compiled it). `make_point(3)` -> `#{'X'=>3,'Kind'=>'Abi.Point','Y'=>3}`, `new_http(41)` -> `42`. Controls: wrong name -> `error undef`; beams off the path -> `error undef`. |
| 6 | "Gleam downcases when it emits to the BEAM, PascalCase becomes snake_case" (ticket 10 section 7, reused as the precedent for aliases) | 02, 07 | **Partly, and it is not a precedent for aliases.** True for **type-variant constructors** (data atoms). False for functions: Gleam **refuses** a PascalCase function name at parse time (`I'm expecting a lowercase name here`), and it emits one export per function, never two. See section 3. |
| 7 | A B# record arrives as a tagged map, not a struct | 08 | Confirmed: `is_struct?` false, matches as `%{Kind: :"Shop.Order", Id: id}`. |
| 8 | `Kind` is a required part of the ABI; wrong tag and Elixir struct are `FunctionClauseError` | 08 | Confirmed. **New:** the boundary tests only what the clause patterns name. `Which(%{Kind: :"Shop.Order", Id: 9})` (no `Total`) is accepted and returns `:order`; `:Shop."Amount"(...)` on the same map raises `KeyError` for the missing `Total` (verifier). |
| 9 | `LANGUAGE.md` 12 erasure table matches the emitted `-spec` | 04 | **Confirmed for every row it lists. Incomplete** (see section 4.4): omits `float`, `map<K,V>`, atom unions, and the flattening of `option<result<..>>`. |
| 10 | `result<T,E>` succeeds as the bare value; `option<T>` absence is the atom `nothing` | 04 | Confirmed: `Res(true)` -> `1`, `Res(false)` -> `{error,bad}`, `MaybeInt(false)` -> `nothing`, and `case Res(true) of {ok,_}` does not match. |

Not a ticket claim but found: Elixir's error for the natural spelling does not point at the fix. It says "Function names and identifiers in Elixir start with lowercase characters or underscore" and suggests `hello_world()`. It never mentions quoting (probe 01, last section). A caller who hits it will conclude it is impossible, which is how the ticket's author concluded it.

## 3. Neighbour survey

**Elixir.**
- Quoted function call after a dot: probe 01, A2.
- `Macro.underscore/1` source is **not on this machine** (conda ships `.beam` only; hex.pm is blocked). It was read from the installed beam's debug info: `probes/macro_underscore_src.out`. The recorded source file is `lib/macro.ex`, with `underscore/1` at line 2316 and `do_underscore/2` at line 2331 (line numbers as recorded in the beam's debug info, not read from a `.ex` file). The rule: break before an uppercase letter that follows a non-uppercase; and break before the last capital of an acronym when a lowercase follows (`HTTPServer` -> `http_server`). Digits do not break (`Parse2D` -> `parse2_d`).
- Elixir's own prefix `Elixir.` is a consequence of alias resolution; the ticket's reasoning on prefixes stands.

**Erlang/OTP.**
- Quoted atoms are ordinary syntax (`'Shop':'New'(1)`).
- PascalCase exports already exist in OTP: scanning 1321 OTP beams (46,001 exports) finds **19** starting with an uppercase letter: 14 in `diameter_types` (`'Address'/3`, `'UTF8String'/3`, ...) and 5 in `wx` (`wxImage`, `wxMenu`, `wxRegion` twice, `wxWindow`) (probe 10 prints only the first 12; verifier re-counted). Rare, but not unheard of; an Elixir caller of those hits the same syntax wall and uses the same quoted call.

**Gleam 1.19.1** (binary only; source unavailable, so the evidence is probe runs).
- Variant constructors are lowercased per capital letter: `NewHTTPThing` -> `new_h_t_t_p_thing`, `HttpError(code)` -> `{http_error, _}`, `PaidInFull` -> `paid_in_full` (probe 02, probe 07 part 1c, real compiler output).
- Function names must already be snake_case; `pub fn NewOrder` is refused (probe 02).
- Module names are file names, so `shop`; nested modules are `a@b`.
- Conclusion: Gleam translates **data** casing. It never has a PascalCase function to alias, so it is not evidence that emitting two exports per function is normal.

**B# itself.**
- `bs_otp.erl` (header, lines 1-14) already renames `HandleCall/3` to `handle_call/3`, by a hand-written table, scoped to a declared behaviour contract. Its header says: "These are tables, not a naming rule. A snake_case<->PascalCase derivation cannot spell `'PKCS-1'`... so the language has no such rule." Ticket 32 section 3 says the same. A derived outbound alias would be the first such rule. The PKCS-1 objection is about *inbound* spelling (foreign name to B# identifier); outbound, every B# identifier is `[A-Z][A-Za-z0-9_]*` (`bs_lexer.xrl:14-16`), so a derivation is total. The objection that survives is collisions and acronyms (section 4.5).
- Ticket 26 section 3: "Values are lowercase and modules and functions PascalCase throughout, so the parser settles it." This is what option C would remove.

## 4. Measurements

### 4.1 Cost of snake_case aliases (probe 05)

Patched scratch copy of the compiler (`probes/alias_emit.patch`, 41 added lines; `compiler/src` untouched). Functions are `public int ComputeTotalK(int n) -> n + K`. Compile time is in-VM, hot, after one discarded warm-up, median of 21 runs (so it excludes VM boot). Beams are built with `debug_info`, as `bsc` builds them.

| N | mode | .beam bytes | exports | ExpT bytes | compile ms (median; min-max) |
|---|---|---|---|---|---|
| 1 | none | 1176 | 4 | 52 | 7.3 (3.2-11.5) |
| 1 | forward | 1268 (+8%) | 5 | 64 | 5.1 (4.0-8.4) |
| 10 | none | 2040 | 13 | 160 | 8.0 (7.1-21.4) |
| 10 | forward | 2680 (+31%) | 23 | 280 | 12.0 (8.9-16.6) |
| 10 | dup | 2728 (+34%) | 23 | 280 | 10.5 (9.4-18.3) |
| 50 | none | 5956 | 53 | 640 | 20.9 (20.2-31.8) |
| 50 | forward | 9008 (+51%) | 103 | 1240 | 32.7 (30.0-51.1) |
| 50 | dup | 9368 (+57%) | 103 | 1240 | 36.1 (33.5-45.5) |
| 200 | none | 21504 | 203 | 2440 | 85.8 (76.1-111.7) |
| 200 | forward | 32984 (+53%) | 403 | 4840 | 127.3 (119.5-148.1) |
| 200 | forward_nospec | 32352 (+50%) | 403 | 4840 | 122.1 (112.0-167.1) |
| 200 | dup | 34860 (+62%) | 403 | 4840 | 150.1 (138.3-275.0) |

Reading it:
- A module's exports double. Marginal cost is about **57 bytes per aliased function** (forward) and about 67 (dup). Dropping the duplicated `-spec` saves only 1-2% of the beam; the rest is in the code, atom, export and `debug_info` chunks (Code +58%, AtU8 +108%, ExpT +98% at N=200).
- Compile time rises about **48%** at N=200 (forward) and 75% (dup) **on one-line bodies, which overstates it**. Verifier regenerated N=200 with three-clause guarded bodies: forward +25% beam / +15% compile, dup +47% beam / +100% compile; a stripped beam grows 55% with forward; 57 bytes per alias holds; rerunning probe 05 gave forward +76% compile, so compile time is noisy. Read the cost as 'tens of percent, size-dependent', not a precise figure. The N=1 row is noise (the "none" run is slower than "forward"); trust N>=50.
- **`dup` is understated.** The bodies here are one `+`, so duplicating them costs almost nothing. Real bodies make `dup` cost proportional to body size, while `forward` does not. If aliases are ever emitted, `forward` is the only variant whose cost does not grow with the code.
- Loaded-code memory (`erlang:memory(code)` delta) is in the `.out` but is **not trustworthy** (not monotone with N=1 rows); use the file sizes.
- The beams carry `debug_info` (as `bsc` writes them), so the duplicated abstract code is inside the sizes above; stripping was not measured.

### 4.2 Runtime cost of the hop (probe 06)

- Default compile, as `bsc` does it: the alias is `{call_only,1,{f,40}}`, a tail jump with no frame, no stack growth. It is **not inlined**.
- With `{inline,[{'NewHTTP',1}]}` or plain `inline`, the body is copied into the alias (with a `call_only` fallback label for the clause-failure path). `bsc` passes neither option, so this is only what it *would* take.
- Timing, OTP 29 JIT, x86_64, 15 interleaved reps, `timer:tc` (1 us resolution; 1e7 calls take about 105 ms, so resolution is irrelevant):

| calls | PascalCase export | alias | alias minus Pascal |
|---|---|---|---|
| 1e7 | median 105162 us (committed `.out`: 111790) | median 108023 us (`.out`: 112651) | **0.29 ns/call** (other runs: 0.00, 0.20, 0.09) |
| 5e7 | median 532836 us (`.out`: 563003) | median 541822 us (`.out`: 582620) | **0.18 ns/call** (other runs: 0.07, -0.07, 0.39) |

Run-to-run spread of the difference is about -0.2 to +0.4 ns; min-to-max of a single configuration reaches 40% (verifier), and the difference reached -0.52 ns. The `phash2` control is far larger than anything under test; verifier's real hop controls: a tail forwarder about 0.5 ns/call, a framed forwarder 1.1-1.8. **The hop is under about 1 ns/call.** Positive control: adding one `erlang:phash2/1` BIF per iteration costs +8 to +9.5 ns/call, so the probe can see a real extra cost. (An earlier negative control, a dynamic `M:F(N)` call, showed nothing, because the JIT resolves remote calls through the same export entry. I replaced it with the BIF control rather than leave a control that cannot fail.)

### 4.3 What the Elixir caller gets (probe 09, patched compiler vs stock)

| spelling | aliases on | stock compiler |
|---|---|---|
| `:Abi.new_http(41)` | `42` | UndefinedFunctionError |
| `41 \|> :Abi.new_http()` | `42` | UndefinedFunctionError |
| `import :Abi, only: [new_http: 1]; new_http(1)` | `2` | CompileError |
| `:Abi."NewHTTP"(41)` | `42` | `42` |

### 4.4 The erasure table against the emitted `-spec` (probe 04)

Every row of section 12's table is reproduced exactly. Differences to report:
- **Missing from the table:** `float` -> `float()`; `map<K,V>` -> `#{K => V}` (with `term` expanding to the union `atom() | integer() | float() | tuple() | [any()] | map() | binary() | pid() | port() | reference() | fun()`); an atom union such as `:red | :green` -> `green | red` (the atoms themselves); `term`.
- **Nested:** `option<result<int, atom>>` erases to `nothing | integer() | {error, atom()}`, flat, no wrapper at either level. A caller cannot tell a present value from an absent one if the payload type itself contains `nothing` (for example `option<atom>`: `atom() | nothing`). Not measured further; flagged.
- `bs@type_atoms/0` appears in every export list (already stated in section 12); counted in "exports" in 4.1.

### 4.5 Naming rules and collisions (probe 07)

Three candidate PascalCase to snake_case rules, with the real Elixir and real Gleam as ground truth:

| B# name | simple (break lower/digit to Upper) | Macro.underscore (real) | Gleam per-capital (real) |
|---|---|---|---|
| NewHTTP | new_http | new_http | new_h_t_t_p |
| ParseURL | parse_url | parse_url | parse_u_r_l |
| HTTPServer | httpserver | http_server | h_t_t_p_server |
| XMLHttpRequest | xmlhttp_request | xml_http_request | x_m_l_http_request |
| OKResult | okresult | ok_result | o_k_result |
| IOList | iolist | io_list | i_o_list |
| GetURLFor | get_urlfor | get_url_for | get_u_r_l_for |
| Parse2D | parse2_d | parse2_d | parse2_d |
| NewUrl / NewURL | new_url / new_url | new_url / new_url | new_url / new_u_r_l |

- The simple rule is wrong on any acronym followed by a word. Gleam's rule is deterministic but ugly. `Macro.underscore` is what an Elixir caller would guess, but its two-letter look-ahead is a rule a clean-room implementer must reproduce exactly (my Erlang re-implementation agreed with the real one on all 17 names).
- **Collisions.** `New` and `new` cannot coexist: a lowercase function name is `syntax error before: new` (probe 07, Col6). The collisions come only from the derived alias:
  - `NewUrl` + `NewURL` both derive `new_url/1`. The stock compiler accepts the module silently. The patched one fails in `erlc` with `col2.bs:0: function new_url/1 already defined` plus `spec for new_url/1 already defined`: position `:0`, no mention of aliases. A real implementation would need its own diagnostic.
  - `ModuleInfo` (arity 1) derives `module_info/1`, which collides with the BEAM's own `module_info/1`: `function module_info/1 already defined`.
  - `Length`, `Abs`, `Min` derive names of auto-imported BIFs; it compiles (no local call is made). Harmless here: Erlang only complains about a *local call* to a function sharing a BIF's name, and nothing local calls the alias.
  - A function already lowercased by `bs_otp` (`HandleCall` in a GenServer) has no alias to make; the patch skips it.

### 4.6 Option C: what changing the convention touches (probe 07 Col6; counts by grep)

- `public int new(int n)` today: `syntax error before: new`. The grammar has two identifier classes (`uident`, `lident`, `bs_lexer.xrl:150,153`) and ticket 26 section 3 uses the class to decide, with no types, between projection `o.total`, qualification `List.Map(f, xs)` and call `Total(o)`.
- The corpus: 75 `.bs` files under `compiler/examples`, 196 `public`/`private` function declarations (130 public), about 760 `Upper(` occurrences (declarations and calls together; counted by regex, rough).
- I did not measure the cost of implementing it; it needs a new rule for the three cases above.

## 5. Options

### Option A. Accept it, and document the quoted call

**Elixir caller code (all measured, probe 01):**

```elixir
order = :Shop."New"(7)                         # %{Kind: :"Shop.Order", Id: 7, Total: 0}
:Shop."Which"(order)                           # :order
Enum.map([1, 2], &:Shop."New"/1)               # works
1 |> :Shop."New"()                             # works

defmodule MyApp.Shop do                        # one-off adapter, if a team wants snake_case
  defdelegate new(id), to: :Shop, as: :New
end
```

**Refused:** `:Shop.New(1)` (syntax error) and `import :Shop` followed by a bare call.

**Compiler delta:** none. **Doc delta:** replace `LANGUAGE.md` 3299-3302 (`apply/3` "the way in") with the quoted call, and say once that `import` cannot reach PascalCase names.

**Measured evidence:** section 0 and probe 01. No change to beam size, compile time or runtime. An Elixir-side macro can generate the snake_case wrappers from a list of names in 12 lines (probe 01, F4: `use Caller, [New: 1, Amount: 1, Pay: 1]` produced `Gen.new/1`, `Gen.amount/1`, `Gen.pay/1`). That library belongs to the tooling track and needs no B# compiler change.

**Strongest counterargument:** adoption inside an existing Elixir codebase is the likeliest first use, and the first thing an Elixir author will write is `:Shop.New(1)`. The error they get tells them to use lowercase, and never says "quote it". Option A leaves that first impression in place. And `import` is genuinely unavailable.

### Option B. Emit snake_case aliases alongside

**Elixir caller code (measured, probe 09):**

```elixir
:Shop.new(7)                                   # works
import :Shop, only: [new: 1, which: 1]
new(7) |> which()                              # works
```

**B# side:** unchanged source. `public Order New(int id)` now exports both `'New'/1` and `new/1`.

**Compiler delta (concrete, as implemented in the scratch patch):**
1. `bs_emit:forms/1`: for each `public` function, add `{alias, arity}` to the export attribute (41 added lines in all).
2. `bs_emit:file_group/5`: after each public function, emit `alias(A1..An) -> 'Name'(A1..An).` and a duplicate `-spec` (the `forward` variant; compiles to a `call_only` jump).
3. A `snake/1` derivation. For Elixir-callers' expectations it must be the `Macro.underscore` rule, not the simple one.
4. Not in the patch and required: a checker diagnostic when two aliases (or an alias and a declared function, or `module_info/0,1`) collide, with a B# source position; `bsc --api` decision (does it list aliases?); `-spec` and `Kind` rules unchanged; a gate and a `--self-test` per the project's rules.
5. Spec delta: the derivation rule becomes part of the published ABI, with the acronym table in section 4.5 as its test vectors.

**Measured evidence:** section 4.1 (exports double, tens of percent in beam and compile time, size-dependent: see 4.1 and its verifier note), 4.2 (runtime: under about 1 ns/call), 4.3 (what the caller gets), 4.5 (rule and collisions).

**Strongest counterargument:** the quote is two characters and aliases are forever. Every module in the language, including ones nobody calls from Elixir, pays the size and compile cost. Erlang tooling (xref, Dialyzer, `module_info`) sees every function twice. The derivation rule becomes a contract that every clean-room implementation must match byte for byte, and it directly contradicts `bs_otp.erl`'s "the language has no such rule" and ticket 32. It would also be the only place in the language where one source function yields two public names.

### Option C. Change B#'s own convention to snake_case functions

**B# program that compiles under C and is refused today:**

```csharp
public Order new(int id)           // today: error: syntax error before: new

new(id) -> Order{ Id = id, Total = 0 }
```

Elixir would call it `:Shop.new(1)`; Erlang `shop:new(1)`.

**Compiler delta:** lexer/parser: function names become `lident`. Ticket 26 section 3's lexical rule (`o.total` vs `list.map(f)` vs `total(o)`) no longer decides anything before types exist; that rule has to be replaced by scope-directed resolution, which ticket 17 refused for the same reason. Module names would stay PascalCase (module and atom are one thing: `Shop`) or follow too, which moves the module atom as well.

**Measured evidence:** only that today's grammar refuses it (probe 07, Col6) and the corpus size in 4.6. Not costed by implementation.

**Strongest counterargument:** it is the largest change, it removes the syntactic distinction that ticket 26 built the call/projection/qualification rule on, and it fights the C# family syntax that is the language's premise (per `CLAUDE.md`). It fixes a problem that Option A shows is two quote characters.

## 6. Recommendation

**Choose Option A now, and correct `LANGUAGE.md` section 12.**

Reasons, all from measurement:
1. The friction the ticket was written to fix does not exist as described. `:Shop."New"(1)` works in every position `apply/3` does and a few more.
2. Option B is real but not cheap: exports double, and the beam and compile time grow by tens of percent (size-dependent), in every module, to save two characters. Runtime is nearly free (a tail jump, under about 1 ns/call), so the objection is not speed. It is that the derivation rule becomes a public ABI, collides on `NewUrl`/`NewURL` and `ModuleInfo`, and reverses ticket 32's "no such rule".
3. Option C touches the one lexical rule ticket 26 depends on.

The one gap A leaves, `import`, is better covered on the Elixir side (the 12-line macro in probe 01 F4, or a generated `defdelegate` module) than by every B# module on every platform. That belongs with the tooling track.

**Ask David the gating question first** (sub-decision 1): "Is `:Shop."New"(1)` an acceptable thing for a B# author to tell an Elixir team?" If yes, A. If no, the next question is alone: "aliases, or change convention", and the concrete program for each is in section 5.

**What would change the recommendation:**
- Evidence that Elixir adopters will not accept quoted calls (a user, a report, an incremental-migration case study). Then B, with the `Macro.underscore` rule, `forward` form and a collision diagnostic, and ideally opt-in per module so only callers pay.
- A decision that the clean-room spec should minimise what implementers must replicate. That also favours A.
- A measured proportion of B# modules actually called from Elixir; none exists.

**Independent of the decision:** section 12 should also state the boundary-tests-`Kind`-only fact (claim 8) and the three missing erasure rows (4.4).

## 7. Limitations

- Elixir sources (`macro.ex`) and Gleam sources are not available (conda ships beams; GitHub/hex are blocked). Macro.underscore line numbers (2316, 2331) come from the beam's debug info, which records the original source lines; no `.ex` file was read. Gleam behaviour is from running the 1.19.1 binary.
- Elixir 1.20.4 is built on OTP 27 and run here on OTP 29; the Elixir probes are unaffected, but this combination is not the one a user will have.
- The alias patch is an experiment: forward and dup variants only; no collision diagnostic, no handling of records inside generics, no `bsc --api` support, no gate.
- Compile times are in-VM and hot (no VM boot, no I/O cold start), on one machine; medians of 21 runs with a wide max, so differences under about 15% at small N are noise.
- `dup` understates its real cost (trivial bodies). Loaded-code memory was captured but is unreliable. Stripped-beam size was not measured.
- Runtime numbers are x86_64 JIT only; the `call_only` form is the same in the emulator, but I did not time it.
- Dialyzer, xref, ExDoc, LSP and editor behaviour with doubled exports were not tested.
- Option C was not implemented; its cost is described by what the grammar refuses, not by a prototype.
- Elm does not target the BEAM; it was not consulted.
- The scratchpad `bsc` wrapper cannot take dashed flags, so probes call `bsc:main/1` directly (`probes/lib.sh`). Other probes use the same compiler ebin built at the same revision.


## Verification note

Independently verified: `verification.md` (VERIFIED WITH CORRECTIONS), all 11 probes reproduce and the headline (`:Shop."New"(1)` runs; Gleam `@external` runs) holds. Corrections applied above: OTP census split (14 diameter_types + 5 wx), cost percentages, timing medians and spread, kind-check wording. Also from the verifier, not yet in the body text:

- `import :Shop, only: [{:New, 1}]` works, and a macro-built local call `{:New, [], [11]}` runs. Only a source-spelled bare call after `import` is impossible. Read "import cannot reach PascalCase names" in sections 4.3 and 5 with that limit.
- Three controls are vacuous or mislabelled: probe 09's "NEGATIVE: no alias built" is a SyntaxError under any compiler; probe 08's "negative control" is a finding; probe 01's T6 fails because the call syntax is invalid, not because import fails.
- The alias patch measures the *simple* snake_case rule, but the brief recommends `Macro.underscore`. Real `Macro.underscore` gives `IDs` -> `i_ds`, `UUIDv4` -> `uui_dv4`, `Parse_Url` -> `parse__url`, `Foo__Bar` -> `foo___bar`. `Parse_Url` and `ParseUrl` collide under the simple rule but not under `Macro.underscore`, so the collision set depends on the rule.
- "Gleam downcases..." is ticket 62's paraphrase of ticket 10 §7.
