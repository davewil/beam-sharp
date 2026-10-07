# Brief: ticket 62, the outbound ABI (ENG-252), function-name casing

Status: OPEN - for human review. Probes: `artifacts/probes/62/` (`./run.sh` re-runs all; outputs in `*.out`).
Toolchain: OTP 28, Elixir 1.18.5, **gleam 1.19.0** (the ticket says 1.18.1), prebuilt `bsc`.

## Ticket and gating question

Ticket: `wayfinder/issues/62-the-outbound-abi.md`. Prefix, record shape and the `Kind` contract are settled
(LANGUAGE.md section 12, lines 3103-3290). One decision is left: **function-name casing for Elixir callers.**

**Gating question (ask alone):** *Should an Elixir caller be able to write `:Shop.new(1)`, i.e. should the
beam export a second, lowercase name for each public function?* Everything else (how the name is derived,
what happens on collision) follows only if the answer is yes.

## Result that changes the question (read first)

**The ticket's premise is wrong in one place.** It says Elixir cannot call a PascalCase export and
`apply/3` is "the way in" (ticket lines 35-44; LANGUAGE.md 3128-3131). Probe 03 shows Elixir can use ordinary
dot-call syntax if the function name is quoted:

```elixir
:Shop."New"(1)        # => %{Kind: :"Shop.Order", Id: 1, Total: 0}   (executed)
m = :Shop; m."New"(1) # works;  (&:Shop."New"/1).(1) works;  Function.capture(:Shop, :New, 1) works
:Shop.New(1)          # SYNTAX_ERROR (confirmed)
```

So the cost to Elixir is "write two quote marks", not "give up call syntax". Whether that is acceptable is
the real decision; section 12 currently overstates it. This is not a refutation of the cost, only of the stated size.

## Sub-decisions

1. **(Gating)** Alias or not: does the beam export lowercase names beside the PascalCase ones?
2. If yes: derivation rule (Elixir-style or Gleam-style), collision refusal, behaviour-callback dedup.
3. If no: does section 12 get corrected to show `:Shop."New"(1)` as the documented spelling?
4. Changing B#'s own convention (candidate 3 in the ticket) is not carried further here; see Options.

## Evidence

| # | Claim | Probe | Result | Verdict |
|---|---|---|---|---|
| 1 | `:Shop.New(1)` is a syntax error; no module prefix helps | `01_rerun_62a.sh` | reproduced exactly: `:Shop.New`, `:"BSharp.Shop".New`, `:"Elixir.Shop".New` all SYNTAX_ERROR | confirmed |
| 2 | Erlang unaffected | `01_rerun_62a.sh` | `'Shop':'New'(1)` returns the map | confirmed |
| 3 | Gleam unaffected (ticket: "never run") | `02_gleam_call.sh` | a no-deps Gleam project with `@external(erlang, "Shop", "New")` built and **ran**: `caller:main() -> order` | confirmed, now executed |
| 3b | 62a's Gleam step works as shipped | `01_rerun_62a.sh` | **fails offline**: `gleam new` pulls gleam_stdlib from hex (no network here). Environment, not B#; 02 avoids deps | 62a's step 4 is not re-runnable offline |
| 4 | "apply/3 is the way in" | `03_elixir_workarounds.sh` | `:Shop."New"(1)`, `m."New"(1)`, `&:Shop."New"/1`, `:erlang.apply`, `Function.capture` all run | **contradicts ticket**: dot-call works with quotes |
| 5 | `unquote` in macros | `03_...exs` | a `for ... def unquote(name)(unquote_splicing(args))` module generates `new/1 ... which/1` wrappers from `:Shop.module_info(:exports)` at compile time and works | an Elixir-side shim is ~6 lines, but per project |
| 6 | An alias export is accepted by Elixir | `06_alias_from_elixir.sh` | beam rewritten with `new/1` etc. beside `'New'/1`: `:Shop.new(1)` and `:Shop.which(:Shop.new(1))` return `:order`; `'Shop':'New'(1) =:= 'Shop':new(1)` is true in Erlang | confirmed (simulated by editing `.abstr`; compiler not modified) |
| 7 | Gleam "downcases PascalCase" (ticket 10, line 335) | `04_gleam_names.sh` | true for **variant tags only**, per capital: `HTTPGet`->`h_t_t_p_get`, `ToJSON`->`to_j_s_o_n`, `ABC`->`a_b_c`, `A1B`->`a1_b`. **Gleam function names are not converted**: `pub fn Foo()` is a syntax error ("expecting a lowercase name") | the precedent is for data tags, not function exports |
| 8 | Gleam bans underscores in variant names | `04_gleam_names.sh` | `Get_2`, `Foo_bar` refused ("not a valid type variant name") | so Gleam's rule cannot collide; B#'s can (below) |
| 9 | Cost of aliasing | `05_alias_cost.sh` | table below | measured |
| 10 | Derivation edge cases | `07_name_table.exs` | table below | measured |

### Cost (probe 05: 27 example modules that compile standalone, 95 public functions, `debug_info` as in bsc.erl:843)

| | base | + alias wrappers | + full body copies (upper bound) |
|---|---|---|---|
| beam bytes, total | 54,860 | 59,880 (**+9.2%**) | 64,288 (+17.2%) |
| export-table entries | 176 | 268 | 268 |
| `erlang:external_size(module_info(exports))` | 2,741 B | 3,825 B (+39.5%) | same |
| atom-table entries | 483 | 573 | not measured |

Per module, Shop (8 fns): 2,588 -> 2,992 B (+404 B, about 50 B per function). Wrappers have no `-spec` in
this probe; adding one would cost more. Load time on Shop (300 purge+load runs, microseconds min/median/max):
base 466/847/2821, wrap 458/1030/6566, copy 470/1216/7055. **The spread is wider than any difference; I
claim no measurable load-time cost and no measurable benefit.** Compile time was not measured.
Counter-example: `Counter` (GenServer) gains nothing, because callbacks already emit `init`, `handle_call`
(bs_otp.erl:40ff, bs_emit.erl:132-136).

### Derivation edge cases (probe 07; G was asserted equal to the real gleam binary on 13 names)

| B# name | E: Elixir `Macro.underscore` | G: gleam-style (`_` before every capital) |
|---|---|---|
| `New` / `Which` / `New2` | `new` / `which` / `new2` | same |
| `HTTPGet` | `http_get` | `h_t_t_p_get` |
| `ToJSON` | `to_json` | `to_j_s_o_n` |
| `XMLHttpRequest2` | `xml_http_request2` | `x_m_l_http_request2` |
| `ABC` vs `Abc` | `abc` and `abc` **collide** | `a_b_c`, `abc` distinct |
| `FooBar` vs `Foobar` | `foo_bar`, `foobar` | same, distinct |
| `FooBar` vs `Foo_bar` (underscore is legal in B#, bs_lexer.xrl:16) | collide | collide |
| `GetX` vs `Get_X` | collide (`get_x`) | `get_x`, `get__x` distinct |
| `Init`, `HandleCall` | `init`, `handle_call` (already exported by the callback table: must dedupe) | same |

No rule is collision-free over B#'s identifier grammar, so any alias rule needs a compile-time "two names derive
the same alias" error. That is the same shape ticket 32 rejected inbound (32b: a mapping cannot spell
`'PKCS-1'` or a quarter of Elixir's names), but outbound the domain is B#'s own grammar, which is closed, so
the objection is weaker here. The rule would have to be written into the spec, and the clean-room fleet
would need to match it exactly.

## Neighbour survey

- **Gleam:** function names are snake_case in source and emitted as written; no conversion exists for
  functions (probe 04, error text). The only conversion is variant tag -> atom, per capital (probe 04 output).
  Gleam's compiler source is **not installed** (binary only, `/nix/store/*gleam-1.19.0`), so I cite behaviour, not
  its source lines.
- **Elixir:** `Macro.underscore` is the caller-side convention; Elixir source is **not installed** (only the
  compiled release), so the E column comes from running it (probe 07).
- **Erlang:** quoting is free (probe 01 step 2).
- **Repo:** `bs_emit.erl:118` ("the one place a B# function name becomes an Erlang one"; export list, spec,
  definition and local calls all go through it); `bs_emit.erl:74-77` (exports plus `bs@type_atoms`);
  `bs_otp.erl:83-89` (callback rename by table, keyed name+arity); LANGUAGE.md 2927 and 3265-3266 ("no
  snake_case/PascalCase mapping anywhere", a table not a rule); ticket 32 line 204; ticket 35 line 22.

## Options

**Option A: Accept, and correct section 12.** Document `:Shop."New"(1)`.
```elixir
# compiles and runs today
user = :Shop."New"(1)
:Shop."Which"(user)      # => :order
```
Compiler delta: none. LANGUAGE.md 3128-3131 gains the quoted form; the "SyntaxError ... apply is the way in"
wording is softened.
Evidence: probe 03, all rows run. Cost to Elixir: two quote marks per call; mixed-case call sites look odd,
and Credo/formatter may complain (not tested).
**Strongest counterargument:** an incremental-adoption story that needs a quoting trick on every call site is
a bad first impression, and `mix format` / editor completion on `:Shop.` will offer unquoted PascalCase
names that do not parse (not tested; LSP behaviour unverified).

**Option B: Export snake_case aliases.** Each `public` function also exports a lowercase name.
```elixir
:Shop.new(1)             # works (probe 06)
:Shop."New"(1)           # still works; Erlang 'Shop':'New'(1) unchanged
```
Compiler delta (concrete): in `bs_emit.erl` at the single naming site (line 118) add an `alias_name/1`; the
export list at 74-77 gains one `{Alias, Arity}` per public function; one wrapper `function` form per alias
calling the PascalCase name; a `bs_check` error "`A` and `B` both export `x`" for collisions; dedupe against
`bs_otp:callback_name` results. Spec rule: the derivation (E or G) becomes part of the handoff.
Measured: +9.2% beam bytes, +92 export entries over 95 functions (+39.5% export-term size), +90 atoms; no
load-time difference outside noise.
**Strongest counterargument:** it is a naming rule by another route, which tickets 32 and 35 explicitly
refused, and it makes every public function two ABI names forever. Choosing E vs G is a permanent public
decision (`http_get` vs `h_t_t_p_get`) that a later change would break callers on. Probe 07 shows E collides
on `ABC`/`Abc`, so a careful B# author can write an error into their own module by naming alone.

**Option C: Change B#'s convention to snake_case functions.** Not probed beyond one fact: the lexer routes
`[A-Z]` identifiers to `uident` and `[a-z]` to `lident` (bs_lexer.xrl:150,153), and a lowercase function head
(`get_x`) is already a syntax error today (probe run in session, `t.bs:4:12`). Compiler delta is
a lexer/parser/checker change plus every exemplar. **Strongest counterargument:** it costs the one syntax
property the language is built on (CLAUDE.md "C#-family syntax"), to fix a two-quote-mark problem (probe 03).

## Recommendation

**Option A for now, and fix section 12.** Reason: the measured cost to Elixir is two quote marks, not lost call
syntax, and Option B buys that at a permanent, unrevertable name-derivation commitment (E and G disagree on
common names, and neither is collision-free over B#'s identifier grammar) that tickets 32 and 35 declined to make.
If David's incremental-adoption priority outweighs that, Option B with rule E and a collision error is the
cheaper form (+9% bytes), and the table in probe 07 is the spec text it would need.

## What I could not measure

- Compile-time cost of Option B (not run); `-spec` for alias wrappers (omitted from the size figures).
- Load-time effect: spread exceeded any difference; no conclusion.
- Real-world Elixir ergonomics: formatter/Credo/ElixirLS behaviour on `:Shop."New"(1)` and on completion.
- Gleam's and Elixir's compiler source (not installed): names derived from observed output only.
- The gleam version: 1.19.0 here, ticket says 1.18.1. 62a's Gleam step needs network (hex); not re-runnable offline.
- Alias beams were produced by editing `.abstr` and recompiling with `compile:forms`, not by a modified `bsc`.
- Record/struct (`%Order{}`) and `Kind` findings were reproduced by probe 01 but not explored further.
