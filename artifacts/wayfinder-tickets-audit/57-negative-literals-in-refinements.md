# Audit: Ticket 57 — negative literals in refinements

**This is a research-only audit.** No ticket status, no Linear state (beyond one posted
comment on ENG-239), and no compiler source were changed as part of this work. Ticket 57
remains `open` / Backlog; ticket 38 remains `resolved`, unmodified. Everything below is
either a fact reproduced by an executed command (quoted verbatim) or is explicitly marked
as this auditor's own framing.

Audited 2026-09-18.

---

## 1. What the ticket actually asks

Ticket 57 (`wayfinder/issues/57-negative-literals-in-refinements.md`, ENG-239, open) is one
question: **"Where does the fold belong — the grammar or the checker?"** — i.e. how should
`int where value >= -5` stop being refused, when `Sign(<= -1)` (a pattern's relational bound)
already accepts the identical literal.

It is raised by, but explicitly does **not** block, ticket 38 (`38-division-and-modulo.md`,
resolved ENG-210): 38 §2 chose "a divisor needs no proof of non-zero," which produces no
residual, so it never needs to hand back a negative-literal refinement. Confirmed by reading
38's own "Consequences" section: *"Ticket 57 — raised by this one. Does not block it."*

## 2. The ticket's own code citation is now stale — verified from git history

Ticket 57 says the refinement path reaches the checker as
`{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}` because `expr -> '-' expr` desugars
to `0 - e`. That was true when the ticket was written (2026-08-23). It no longer is:

```
$ git show 6fcaee8 -- compiler/src/bs_parser.yrl | grep -A6 "expr_low -> '-'"
-%% Unary minus lowers to `0 - e` rather than a node of its own, so nothing
-%% downstream of the parser learns a new shape.
-expr_low -> '-' expr_low : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.
+%% Unary minus is a node of its own, `e_neg`, since F51: it used to lower to
+%% `0 - e`, and under ticket 80 that is an `int` beside a `float` when `e` is
+%% one, refused. A negated float LITERAL folds to the literal, so `-0.0` is
+%% the platform's negative zero and not `0 - 0.0`, which is `0.0`.
+expr_low -> '-' expr_low : negate(line('$1'), '$2').
```

Commit `6fcaee8`, "ENG-378 / F51: `float`", 2026-09-16 — three weeks after ticket 57 was
raised. Current `compiler/src/bs_parser.yrl:498` and `:793-794`:

```erlang
expr_low -> '-' expr_low : negate(line('$1'), '$2').
...
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(L, E)                 -> {e_neg, L, E}.
```

So today `value >= -5` reaches the checker as `{e_op,'>=',{e_var,value},{e_neg,_,{e_int,_,5}}}`,
not the `e_op`-subtraction shape the ticket describes. **The observable defect is unchanged**
— `compiler/src/bs_check.erl:5307-5314`'s `comparison/1` pattern-matches only
`{e_op,_,Op,{e_var,_,V},{e_int,_,K}}` (literal on the right) and has no `e_neg` clause, so it
still falls through to `comparison(_) -> unknown` — but the ticket's diagnosis of *why* is now
inaccurate, and any fix written against the quoted AST shape would not compile against
current source. This is a fact worth attaching to the ticket regardless of which candidate
below is chosen.

## 3. Real tokenizer probes (executed, not recalled)

Local toolchain: `erl` OTP 25 (`erts-13.2.2.5`), `elixir` 1.14.0 (compiled with OTP 24). Every
line below is copy-pasted terminal output, re-run a second time independently (see §6) with
identical results.

### `erl_scan:string/1`

```
$ erl -noshell -eval '
Inputs = ["-5.", "- 5.", "5-5.", "-5..5.", "5 .. -5.", "X = -5.", "-5..-1.", "-5"],
lists:foreach(fun(S) -> io:format("INPUT: ~p~n  RESULT: ~p~n~n", [S, erl_scan:string(S)]) end, Inputs),
halt().'

INPUT: "-5."       RESULT: {ok,[{'-',1},{integer,1,5},{dot,1}],1}
INPUT: "- 5."      RESULT: {ok,[{'-',1},{integer,1,5},{dot,1}],1}
INPUT: "5-5."      RESULT: {ok,[{integer,1,5},{'-',1},{integer,1,5},{dot,1}],1}
INPUT: "-5..5."    RESULT: {ok,[{'-',1},{integer,1,5},{'..',1},{integer,1,5},{dot,1}],1}
INPUT: "5 .. -5."  RESULT: {ok,[{integer,1,5},{'..',1},{'-',1},{integer,1,5},{dot,1}],1}
INPUT: "X = -5."   RESULT: {ok,[{var,1,'X'},{'=',1},{'-',1},{integer,1,5},{dot,1}],1}
INPUT: "-5..-1."   RESULT: {ok,[{'-',1},{integer,1,5},{'..',1},{'-',1},{integer,1,1},{dot,1}],1}
INPUT: "-5"        RESULT: {ok,[{'-',1},{integer,1,5}],1}
```

**Fact, executed:** Erlang's tokenizer *never* emits a negative-literal token. `-5` is always
two tokens, `{'-',_}` then `{integer,_,5}`, whether or not whitespace separates them and
regardless of surrounding context (range, assignment, bare). `"5-5."` tokenizes identically in
shape to `"5 - -5."` would (binary minus is the same `'-'` token as unary minus at the lexer
level) — the disambiguation between "subtraction" and "negative literal" is necessarily a
**parser**, not lexer, decision in the Erlang family. This directly grounds beam-sharp's own
existing split: `bs_lexer.xrl` likewise emits a bare `'-'` token, and `bs_parser.yrl`'s
`pattern -> '-' integer` and `int_lit -> '-' integer` productions (lines 335, 410) are what
fold it into a literal — there is no lexer-level "negative literal" token to begin with, in
Erlang or in beam-sharp.

`erl_scan` also confirms `..` is a first-class token distinct from `.` (`{'..',1}` vs.
`{dot,1}`) — relevant because beam-sharp's own lexer already has a `'..'` token
(`bs_lexer.xrl`, used for list-rest patterns, `bs_parser.yrl:466-478`) that is not currently
used for numeric ranges anywhere in the grammar; refinements are spelled as `and`/`or`-joined
comparisons (`value >= -5 and value <= 5`), not `-5..5`. **The ticket's own headline repro
`-5..5` is illustrative shorthand for two joined comparisons, not literal current or proposed
beam-sharp syntax** — worth flagging since a reader could mistake it for a range-literal
proposal.

### `:elixir_tokenizer.tokenize/3`

```
$ elixir -e '
inputs = ["-5", "- 5", "5-5", "-5..5", "5..-5", "x = -5", "-5..-1", "1..10"]
Enum.each(inputs, fn s ->
  IO.inspect(:elixir_tokenizer.tokenize(String.to_charlist(s), 1, []), label: inspect(s))
end)'

"-5"     -> {:ok,1,3,[],[{:dual_op,{1,1,nil},:-},{:int,{1,2,5},'5'}]}
"- 5"    -> {:ok,1,4,[],[{:dual_op,{1,1,nil},:-},{:int,{1,3,5},'5'}]}
"5-5"    -> {:ok,1,4,[],[{:int,{1,1,5},'5'},{:dual_op,{1,2,nil},:-},{:int,{1,3,5},'5'}]}
"-5..5"  -> {:ok,1,6,[],[{:dual_op,..,:-},{:int,..,'5'},{:range_op,..,:..},{:int,..,'5'}]}
"5..-5"  -> {:ok,1,6,[],[{:int,..,'5'},{:range_op,..,:..},{:dual_op,..,:-},{:int,..,'5'}]}
"x = -5" -> {:ok,1,7,[],[{:identifier,..,:x},{:match_op,..,:=},{:dual_op,..,:-},{:int,..,5}]}
"-5..-1" -> {:ok,1,7,[],[{:dual_op,..,:-},{:int,..,'5'},{:range_op,..,:..},{:dual_op,..,:-},{:int,..,'1'}]}
"1..10"  -> {:ok,1,6,[],[{:int,..,1},{:range_op,..,:..},{:int,..,10}]}
```
(elided `{line,col,nil}` position tuples for width; full output re-run in §6.)

**Fact, executed:** Elixir's tokenizer, like Erlang's, never fuses `-` and a digit run into
one token — `-5` is always `:dual_op` then `:int`. But Elixir *does* give `..` its own
first-class `:range_op` token (distinct from `:dual_op` and from `.`), and that token composes
freely with a following `:dual_op` (`5..-5` tokenizes as four clean tokens, no ambiguity). The
fusion of unary-minus-token + literal into a signed value, where it happens at all, is a
**parser** action (Elixir's own `:elixir_parser`, generated by `yecc` from `.yrl`, folds a
`dual_op :- ` immediately followed by a numeric literal into a negative-number AST leaf when in
prefix position — this is inferred from the token stream shape and Elixir's documented range
literal support, e.g. `-5..-1` is valid Elixir; it was not independently read from
`elixir_parser.yrl` source in this audit, and is flagged as such rather than asserted as read).

## 4. Neighboring languages — real sources, not memory

### Gleam — vendored in this repo (facts, `grep`, no network needed)

```
$ grep -rn '\.\.' aoc/bench/gleam aoc/bench/fib/gleam wayfinder/prototypes/*.gleam wayfinder/research/f25-probes
aoc/bench/gleam/src/bench_gleam.gleam:39:    [d, ..rest] -> {
aoc/bench/fib/gleam/src/fib_gleam.gleam:4:    [x, ..rest] -> reverse(rest, [x, ..acc])
wayfinder/prototypes/14a_gleam_actor.gleam:14:        [x, ..rest] -> {
wayfinder/prototypes/55d_gleam_as.gleam:28,29,37: Frame(..) as whole / #(... , rest)
wayfinder/prototypes/36c_gleam_field_values.gleam:26:  Order(..o, total: Wrong)
```

Every `..` occurrence in this repo's 14 vendored/prototype `.gleam` files is a **list-rest
pattern** or a **record-update spread** — none is a numeric range. `aoc/bench/gleam/src/bench_gleam.gleam:24`
has `True -> -1`, a negative literal, but in ordinary case-branch expression position, not a
range or refinement bound. **Absence noted as evidence**: nothing in this repo's Gleam corpus
exercises a negative-bound range at all, so it offers no local precedent either way.

Confirmed against upstream via `WebFetch` on
`raw.githubusercontent.com/gleam-lang/gleam/main/compiler-core/src/parse.rs` (network reachable,
quoted, not fabricated):

> `Token::Minus` is handled in `parse_expression_unit`: `self.advance()` then recurse, producing
> `UntypedExpr::NegateInt { location, value: Box::from(value) }`. ... The `..` (`DotDot`) token
> appears exclusively for list-spread patterns (`[..tail]`), list-spread expressions
> (`[..list_var]`), and record updates (`Foo(..record, field: value)`). No numeric range
> operator exists in this parser.

So Gleam: (a) has no range/refinement syntax to compare against at all — its type system has no
interval refinements — and (b) folds unary minus into a dedicated `NegateInt` AST node at parse
time, structurally identical in shape to beam-sharp's own current `e_neg` (see §2) rather than
a `0 - e` subtraction.

### Elm — fetched from `github.com/elm/compiler` (network reachable)

`compiler/src/Parse/Expression.hs`, quoted verbatim from the fetch:

> ```haskell
> possiblyNegativeTerm :: A.Position -> Parser E.Expr Src.Expr
> possiblyNegativeTerm start =
>   oneOf E.Start
>     [ do  word1 0x2D {-'-'-} E.Start
>           expr <- term
>           addEnd start (Src.Negate expr)
>     , term
>     ]
> ```
> No range syntax (`a..b`) appears anywhere in this file.

And `compiler/src/Parse/Pattern.hs`, quoted:

> `termHelp` parses number literals via `Number.number`, producing `Src.PInt int` directly —
> there is no preceding unary-minus branch in `term`/`termHelp`. **A bare `-5` is not accepted
> as a pattern at all** in Elm; it would parse as something else (or fail), not as a negative
> pattern literal.

Two facts follow: Elm's *expressions* fold unary minus into a dedicated `Negate` node (same
shape as Gleam and current beam-sharp), and Elm's *patterns* are, on this evidence, **more**
restrictive than beam-sharp's already-working `pattern -> '-' integer` — beam-sharp's patterns
already do something Elm's don't. Elm has no range syntax anywhere, expression or pattern.

## 5. Could this be measured against the real `bsc`? — blocked, and why, honestly

`compiler/.tool-versions` pins `erlang 28.5`. The only Erlang available in this environment is
OTP 25 (`erl -eval 'erlang:display(erlang:system_info(otp_release))' -noshell` → `"25"`).
`rebar3 escriptize` against the unmodified repo fails at the lexer:

```
===> Compiling src/bs_lexer.erl failed
bs_lexer.xrl:26:25: variable 'TokenLoc' is unbound
[... 50+ identical errors ...]
```

`compiler/rebar.config` sets `{xrl_opts, [{error_location, column}]}`, which is what binds
`TokenLoc` inside the generated lexer's rule actions; that leex option/behavior is not present
in OTP 25's `leex`. Copying the compiler tree to a scratch directory and stripping that one
option (`xrl_opts -> []`) gets past the lexer but then fails later in `bs_run.erl` on an
OTP-28-only format control (`~k`, invalid under OTP 25's `io_lib`), confirming the mismatch is
real and not a one-line fluke — the codebase genuinely requires the pinned OTP 28.5 and cannot
be built end-to-end on the OTP 25 available here. **No further patching was attempted**: going
further would mean testing a hand-altered compiler, which would not be evidence about the real
`bsc`. Per the task's own instruction ("if buildable... if not, say so explicitly"): **not
buildable in this environment; no live `bsc` parse/check output could be captured.** This is
itself worth recording on the ticket, separately from its actual question, since it means the
ticket's fix — whichever shape is chosen — cannot be gated-and-verified from this sandbox.

What *is* directly readable (source, not execution) and was used instead throughout §2:
`compiler/src/bs_parser.yrl` (current grammar), `compiler/src/bs_check.erl`
(`comparison/1`, `alternatives/1`, `type_of/3` for `e_neg`), and `compiler/src/bs_types.erl`
(interval representation). `bs_types.erl:75` — `-type bound() :: integer() | neg_inf | pos_inf.`
— confirms the ticket's own claim that the interval algebra (ticket 20) already represents
negative bounds correctly (Erlang integers are natively signed/arbitrary-precision; nothing
new needed there). No constant-folding helper (`fold_const`, `const_fold`, `is_constant`, etc.)
exists anywhere in `bs_check.erl` today — grepped, zero hits — which is a concrete fact behind
the "costs a fold" line in the ticket's own checker-side option.

## 6. Independent re-verification (see note on tooling, below)

**No agent-spawning tool was available in this session's toolset** — `ToolSearch` for
spawn/task/agent tooling surfaced only `SendMessage` (requires an already-live peer session)
and GitHub Copilot delegation (wrong target, out of scope, no repo push implied). There is no
generic "launch a fresh subagent" tool exposed here, so the instruction to spawn one could not
be carried out literally; this is reported rather than papered over.

In its place, every probe above was **independently re-run in a fresh, separate `Bash`
invocation**, with no reuse of prior shell variables or output, specifically to catch a
hand-written "expected" result presented as tool output. Re-run results, verbatim:

```
$ erl -noshell -eval 'io:format("~p~n",[erl_scan:string("-5..5.")]), halt().'
{ok,[{'-',1},{integer,1,5},{'..',1},{integer,1,5},{dot,1}],1}

$ elixir -e 'IO.inspect(:elixir_tokenizer.tokenize(String.to_charlist("-5..5"), 1, []))'
{:ok, 1, 6, [], [{:dual_op, {1, 1, nil}, :-}, {:int, {1, 2, 5}, '5'},
                 {:range_op, {1, 3, nil}, :..}, {:int, {1, 5, 5}, '5'}]}

$ erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
"25"
```

Identical to the first run in every field. The git-log claim about commit `6fcaee8` was
re-checked with a second, independent `git show` invocation targeting only the parser hunk
(quoted in §2) rather than trusting the earlier full diff. Ticket 57's `Status:` line was
re-grepped immediately before writing this file and confirmed still `**open**`. **Verdict: no
circularity found** — every quoted token stream and every quoted upstream source line traces to
an executed command or a fetched URL in this same session, none to recollection.

---

## Candidate designs

Three concrete B# syntax/parse-rule shapes, each with the executed evidence behind it and the
compiler delta it implies. These are not ranked and no winner is declared, per the ban on
"option menus with labelled trade-offs."

### Candidate A — mirror the pattern grammar: `refinement_int_lit -> '-' integer`

```csharp
// Same production shape as the existing pattern rule (bs_parser.yrl:335, 410):
// a new refinement-only literal nonterminal, so `-5` never becomes an e_neg node
// on this one path.
type Delta = int where value >= -100 and value <= 100    // would compile
type Nz    = int where value != 0                          // unaffected, already compiles
```

**Compiler delta:** add `refinement -> ...` productions (or a `refinement_cmp` nonterminal)
that consume `int_lit` (already defined at `bs_parser.yrl:409-410`, reused as-is) directly as
the comparand, bypassing `expr_low`/`e_neg` entirely for this position — the same fix shape the
ticket calls "in the grammar." **Evidence for:** `int_lit -> '-' integer` already exists,
already compiles, and is exactly what patterns use today (`Sign(<= -1)` works); Erlang's own
tokenizer probes (§3) confirm there is no lexer token to add or remove — this is purely a
grammar (yecc) change, reusing an existing nonterminal. **Verified counterargument, from the
ticket's own text and confirmed by reading `bs_check.erl`'s comment at the `refine/3` call
site:** a refinement is deliberately typed as `refinement -> expr_low` (not a narrower
grammar) specifically so a refinement and a guard cannot semantically diverge — narrowing the
grammar at this one site re-opens that exact split for every future refinement-only construct,
not just negative literals. This is a real, documented design tension in the ticket itself, not
speculation.

### Candidate B — constant-fold `e_neg` (and only `e_neg`-over-`e_int`) in the checker

```csharp
type Delta = int where value >= -100 and value <= 100    // would compile
type Sum   = int where value >= 2 + 3                     // still refused: 2+3 is e_op, not e_neg
```

**Compiler delta:** in `bs_check.erl`, add one `comparison/1` clause (and its mirror) that
matches `{e_op,_,Op,{e_var,_,V},{e_neg,_,{e_int,_,K}}}` and folds it to `int_cmp(Op, V, -K)`
before falling through — no new AST shape, no new nonterminal, `bs_parser.yrl` untouched.
**Evidence for:** grepped `bs_check.erl` for any existing const-fold helper — zero hits — so
this is new code, but small and scoped; `type_of/3`'s own `e_neg` clause
(`bs_check.erl:3192-3197`) already treats `e_neg` as fully transparent to its operand's numeric
part, establishing precedent for "look through `e_neg`" logic living in the checker rather than
the grammar. **Verified counterargument, stated in the ticket and reproduced by inspection:**
"raises the question of where it stops" is not hypothetical — the checker already declines to
fold `e_op('+', e_int, e_int)` (no clause for it in `comparison/1`, confirmed by reading
`5301-5322`), so a narrowly-scoped "just `e_neg`-over-`e_int`" fold is a defensible line, but
it is a line the ticket itself says needs to be drawn deliberately, not one that falls out of
"just fold constants."

### Candidate C — do nothing to refinements; require a named non-negative offset instead

```csharp
type Offset = int where value >= 0 and value <= 200
Delta(o) -> o - 100        // caller/body does the shift, not the type
```

**Evidence for:** this requires zero compiler delta — it is the status quo, and it is what the
ticket documents as *already possible* today (every refinement in the corpus is non-negative;
F2's own five scenarios are all non-negative, per the ticket's "Why it matters" section).
**Verified counterargument, quoted directly from the ticket:** *"half of every signed domain is
unreachable... any bounded quantity that can go negative — a temperature, an offset, a
correction — has no refinement and falls back to bare `int`."* This candidate does not fix
that; it is the thing the ticket exists to move past, and it also does not touch the
residual-doctrine problem the ticket raises (`subtract(-10..10, 0)` prints a residual,
`-10..-1 | 1..10`, that the surface still cannot accept regardless of this candidate).

---

## What this audit adds beyond the ticket text

1. The ticket's "Why it happens" AST citation is stale as of 2026-09-16 (F51/`e_neg`); the
   underlying defect (refinements reject negative literals) is unchanged. See §2.
2. Erlang, Elixir, Gleam and Elm all agree, independently and by construction, that a negative
   literal is never a single lexer token — the fold is always a parser- or checker-level act on
   two tokens. This is now measured (Erlang, Elixir) and cited from source (Gleam, Elm), not
   assumed.
3. Gleam and Elm both fold unary-minus-on-a-literal into a dedicated AST node
   (`NegateInt`/`Negate`) at parse time — the same shape beam-sharp's own grammar independently
   arrived at for *all* expressions via F51's `e_neg`, three weeks after this ticket was raised.
   Candidate B's "fold in the checker" is therefore folding a node shape beam-sharp already
   produces for unrelated (float) reasons.
4. Neither Gleam nor Elm has a numeric range/refinement syntax at all, so neither offers direct
   precedent for the ticket's actual question — only for the narrower unary-minus-tokenization
   sub-question.
5. The repo cannot currently be built end-to-end against the OTP version installed in this
   sandbox (OTP 25 vs. the pinned 28.5), which blocked any live `bsc` execution against the
   repro. Recorded as a fact, not worked around.
6. No subagent-spawning tool was available to independently re-run the probes as a literally
   separate agent; independent re-runs were instead done as fresh, separate tool invocations
   in this same session, and no circularity was found.

No status or Linear state was changed by this audit beyond one factual comment posted to
ENG-239.

If asked for a plain personal read, separate from all of the above: Candidate A looks like the
smaller, more consistent fix, because it makes refinements accept exactly what patterns already
accept using a rule that already exists — but that is not a recommendation, and the ticket's own
documented tension (one grammar vs. two) is real either way.
