# Decision brief — ticket 57: a refinement cannot say `-5`

Research only. Nothing under `wayfinder/issues/` or `compiler/src/` was changed to produce this
brief; every "patched" build below lives under a scratch directory outside the repo. The ticket
stays **open**.

## Sub-decisions, answered up front

**(a) Where does the fold belong — grammar or checker?** Both are cheap and both work (Probes
2–3). The grammar option is one line and, on inspection, does **not** create the split the
ticket worried about — see (c). Recommendation: grammar (Option A below).

**(b) How far does the fold go?** As far as "a literal, optionally negated" — never a variable,
never a sum. `-5` folds; `2 + 3` does not, under either implemented option (Probe 2 and Probe 3
both re-refuse it). Erlang's own ancestry (Probe 5) shows the more general principle this
instantiates: *fold a closed (variable-free) expression built only from arithmetic operators over
literals; refuse anything a variable reaches* — Erlang's linter folds `2+3`, `1 bsl 4`, etc. in
pattern position by that exact rule, and refuses `X+1` by it too. beam-sharp doesn't need the
general form today: every refinement in the corpus is bare-literal (Measured costs, below), so
building the general fold is optional scope, not a requirement of this ticket.

**(c) Does fixing this reopen "refinement and guard must not disagree"?** No, under either option,
and Probe 4 is why: the invariant is that refinements and guards are read by the same function
(`alternatives/1`, `bs_check.erl:4210` — the comment at `bs_parser.yrl:174` says so explicitly).
Neither option gives refinements a grammar or a reader guards don't also get. Option A patches
`negate/2`, which every `expr_low` reduction calls, guards included — Probe 4 shows a plain guard
`when x >= -5` gains the identical fold. Option B patches `comparison/1`, which `apply_guard/3`
calls for guards and `refine/3` calls for refinements — same function, both callers. The fix makes
refinements and guards agree *more* than they do today, not less: today they agree by both being
blind to `-5` (a refinement hard-errors on it, a guard just credits it no coverage silently); after
either fix they agree by both reading it.

## The ticket's own mechanism claim is stale — corrected against current source

The ticket says unary minus desugars to `{e_op,'-',{e_int,0},'$2'}`. That was true when the ticket
was filed (2026-08-23) but isn't the code today. `bs_parser.yrl:539-543`, added by F51 (ticket 80,
mixed int/float refusal), replaced that desugaring with a dedicated node:

```erlang
%% Unary minus is a node of its own, `e_neg`, since F51: it used to lower to
%% `0 - e`, and under ticket 80 that is an `int` beside a `float` when `e` is
%% one, refused. A negated float LITERAL folds to the literal, so `-0.0` is
%% the platform's negative zero and not `0 - 0.0`, which is `0.0`.
expr_low -> '-' expr_low : negate(line('$1'), '$2').
...
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(L, E)                 -> {e_neg, L, E}.
```

So today `-5` in a refinement parses to `{e_neg, L, {e_int, L, 5}}`, not an `e_op` subtraction —
Probe 1 shows this directly. The float case *already* folds (that's the whole point of F51's
comment); **the int case is the one line F51 forgot**, not a design decision anyone made on
purpose. This matters for the recommendation: Option A isn't "narrowing the grammar for
refinements", it's completing an asymmetry the previous feature already established for floats.

## Probes run

All probes ran against a from-source rebuild of `bsc`'s `bs_lexer`/`bs_parser`/`bs_check` (this
sandbox has OTP 25.3.2; the repo's `rebar.config` asks for `{error_location, column}`, an option
this leex doesn't have — a scratch copy of `bs_lexer.xrl` with `TokenLoc` renamed to `TokenLine`
sidesteps it; this affects diagnostic *positions* only, never parsing or checking, and no file
under `compiler/src/` was touched). Build commands and full transcripts are reproducible from
`/home/user/beam-sharp/compiler/src/{bs_parser.yrl,bs_lexer.xrl,bs_check.erl}` with plain
`yecc:file/2`, `leex:file/2`, `erlc`.

### Probe 1 — reproduce the bug against current source, and get the real AST

```erlang
Src = "module M\ntype T = int where value >= -5\n",
{ok, Toks, _} = bs_lexer:string(Src),
{ok, Parsed} = bs_parser:parse(Toks),
%% => [{module,1,'M'},
%%     {type_refined,2,'T',{t_builtin,int},
%%                   {e_op,2,'>=',{e_var,2,value},{e_neg,2,{e_int,2,5}}}}]
bs_check:check(Parsed).
%% => ** exception error: {opaque_refinement,2}
```

Confirmed live via `bsc:status/2` too, compiling a real two-line `.bs` module (`type T = int where
value >= -5`): exit status 1, diagnostic `opaque_refinement` at line 3 (the type line). Real
`bsc` output, not a hand-built AST.

The companion pattern, same literal:

```erlang
Sign(<= -1) -> :neg
Sign(_)     -> :other
```

parses to `{p_rel,2,'<=',-1}` (a literal `-1`, from the pattern's own `int_lit -> '-' integer :
-value('$2').`, `bs_parser.yrl:424`) and `bsc:status/2` on it: exit status **0**. Ticket's
refuse/accept split, reproduced exactly, against the real current source, not the ticket's paste.

### Probe 2 — Option A, the grammar fix: extend `negate/2` to fold ints, mirroring the float case

Patch (against a scratch copy; not applied to the repo):

```diff
 negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
+negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};
 negate(L, E)                 -> {e_neg, L, E}.
```

Rebuilt only `bs_parser.erl` from this patched `.yrl` (`bs_check.erl` untouched, unmodified beam):

```erlang
%% AST now:
{type_refined,2,'T',{t_builtin,int},{e_op,2,'>=',{e_var,2,value},{e_int,2,-5}}}
%% bs_check:check/1 (stock, unpatched):
{ok,ok}                              % was {opaque_refinement,2}
```

`yecc` reports the same **5 shift/reduce, 0 reduce/reduce** conflicts before and after — the patch
adds no ambiguity. Re-ran the ticket's whole table against this build:

| refinement | stock | patched (Option A) |
|---|---|---|
| `value >= -5` | refused | **accepted** |
| `value >= -5 and value <= 5` | refused | **accepted** |
| `value >= 1 or value <= -1` | refused | **accepted** |
| `value >= 2 + 3` | refused | refused (unchanged — compound arithmetic, not a bare literal) |
| `value <= 3 or value >= 10` | accepted | accepted (unchanged) |
| `value != 0` | accepted | accepted (unchanged) |

And the guard side, unprompted by anything in the ticket: `Classify(x) when x >= -5 -> :ok` now
parses its guard to `{e_op,2,'>=',{e_var,2,x},{e_int,2,-5}}` instead of wrapping the `-5` in
`e_neg` — the same fold, for free, at zero extra lines, because `negate/2` backs every `-` in the
grammar, guards included.

### Probe 3 — Option B, the checker fix: fold at `comparison/1`

Patch (against a scratch copy of `bs_check.erl`; `bs_parser.yrl` untouched):

```diff
-comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
-comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
+-define(IS_INT_CONST(X),
+        (element(1, X) =:= e_int orelse
+         (element(1, X) =:= e_neg andalso element(1, element(3, X)) =:= e_int))).
+
+int_const({e_int, _, K})             -> K;
+int_const({e_neg, _, {e_int, _, K}}) -> -K.
+
+comparison({e_op, _, Op, {e_var, _, V}, R}) when ?IS_INT_CONST(R) ->
+    int_cmp(Op, V, int_const(R));
+comparison({e_op, _, Op, L, {e_var, _, V}}) when ?IS_INT_CONST(L) ->
+    int_cmp(flip(Op), V, int_const(L));
```

Compiles clean (warnings-as-errors, matching `rebar.config`'s `erl_opts`). Same table, same
results as Option A: `-5`, `-5 and 5`, `1 or -1` all now accepted; `2 + 3` still refused. Verified
against `bs_check:check/1` directly, not just against `alternatives/1` in isolation.

### Probe 4 — does either option disturb the refinement/guard invariant?

Ran `Classify(x) when x >= -5 -> :ok` through both patched builds:

- Option A: guard AST becomes `{e_op,2,'>=',{e_var,2,x},{e_int,2,-5}}` (was
  `{e_neg,2,{e_int,2,5}}` wrapped inside the `e_op`) — fixed identically to the refinement case,
  same production.
- Option B: `bs_check.erl`'s `comparison/1` is the one function both `apply_guard/3`
  (`bs_check.erl:4181-4195`) and `refine/3` (`bs_check.erl:1549-1566`) call through
  `alternatives/1`; patching it once patches both call sites at once.

Neither option gives the refinement type-declaration a special path the guard doesn't share.

### Probe 5 — Erlang, the direct ancestor: `X >= -5` in a real guard, and how `erl_parse` sees it

```erlang
-module(verify_guard).
-export([bucket/1]).
bucket(X) when X >= -5 -> low;
bucket(_) -> high.
```

Compiles clean with `erlc`, runs correctly: `bucket(-5) = low`, `bucket(-6) = high`,
`bucket(0) = low`. `erl_parse:parse_form/1` on the guard clause:

```erlang
{function,1,bucket,1,
          [{clause,1,[{var,1,'X'}],
                    [[{op,1,'>=',{var,1,'X'},{op,1,'-',{integer,1,5}}}]],
                    [{atom,1,low}]}]}
```

**Erlang's grammar never folds `-5` anywhere** — guard, pattern, or bare expression all parse to
`{op,'-',{integer,5}}`. Checked all three positions directly (`erl_parse:parse_form/1` on a guard
clause, a pattern clause `classify(-5) -> matched.`, and a bare-expression clause `f() -> -5.`):
identical `{op,Line,'-',{integer,Line,5}}` shape in every one. Confirmed independently a second
time from a fresh build (see Verification).

So how does Erlang accept `-5`, or even `2+3`, as a **pattern**? Not in the grammar — in the
linter, `erl_lint.erl:1877-1908`:

```erlang
is_pattern_expr(Expr) ->
    case is_pattern_expr_1(Expr) of
        false -> false;
        true ->
            case erl_eval:partial_eval(Expr) of
                {integer,_,_} -> true;
                {char,_,_}    -> true;
                {float,_,_}   -> true;
                {atom,_,_}    -> true;
                _             -> false
            end
    end.

is_pattern_expr_1({op,_Anno,Op,A}) ->
    erl_internal:arith_op(Op, 1) andalso is_pattern_expr_1(A);
is_pattern_expr_1({op,_Anno,Op,A1,A2}) ->
    erl_internal:arith_op(Op, 2) andalso all(fun is_pattern_expr/1, [A1,A2]);
```

`erl_internal:arith_op/2` (`erl_internal.erl:143-157`) admits `+ - * / bnot div rem band bor bxor
bsl bsr` — the *entire* arithmetic table, recursively, over any depth of literals, never a
variable — and `erl_eval:partial_eval/1` is the actual fold, called from the linter, not the
grammar. Verified live:

```erlang
-module(const_pat).
f(2+3) -> five;
f(1 bsl 4) -> sixteen;
f(_) -> other.
%% f(5) = five, f(16) = sixteen, f(7) = other  -- compiles and runs.

-module(bad_pat).
f(X, X+1) -> matched.
%% bad_pat.erl:3:7: illegal pattern    -- refused: a variable reaches the arithmetic.
```

This is direct ancestor precedent for "checker, not grammar" *and* for the general fold principle
in (b) — but note it only ever applies to **patterns**; Erlang guards need no fold at all, because
Erlang has no static exhaustiveness proof to feed. beam-sharp's refinements are exactly the piece
Erlang doesn't have, which is why this ticket exists and Erlang offers no ready-made answer for it
— only the shape of the answer.

### Probe 6 — Gleam, the closest sibling: does it fold, and where?

Gleam 1.19.0-rc1 is built at `/tmp/gleam-src/target/release/gleam` (`gleam --version` confirms).
`gleam build`/`gleam check` fail at the final BEAM-compile step on this host — its bundled
compile-escript (`compiler-cli/templates/gleam@@compile.erl:78-91`) uses the `maybe ... ?= ...
else` expression, stable only from OTP 27; this sandbox is OTP 25.3.2 — but Gleam's own compiler
front end (parse + typecheck + Erlang-form codegen) runs to completion regardless and leaves the
compiled abstract-format artifact on disk (`negprobe.abstr`, the same `.abstr` handoff format
`bsc.erl`'s own pipeline comment describes: "abstract format -> .abstr -> compile:file
from_abstr"). Read directly:

```gleam
pub fn classify(x: Int) -> String {
  case x {
    _ if x >= -5 -> "low"
    _ -> "high"
  }
}

pub fn bare_compare(x: Int) -> Bool { x >= -5 }

pub fn neg_pattern(x: Int) -> String {
  case x {
    -5 -> "exactly minus five"
    _ -> "other"
  }
}
```

```erlang
{function,1,classify,1,
    [{clause,1,[{var,1,'X'}],[],
        [{'case',2,{var,2,'X'},
            [{clause,3,[{var,3,'_'}],
                 [[{op,3,'>=',{var,3,'X'},{integer,3,-5}}]],   %% guard: FOLDED
                 [...'"low"'...]},
             {clause,4,[{var,4,'_'}],[],[...'"high"'...]}]}]}]}.

{function,8,bare_compare,1,
    [{clause,8,[{var,8,'X'}],[],
        [{op,9,'>=',{var,9,'X'},{integer,9,-5}}]}]}.            %% bare compare: FOLDED

{function,12,neg_pattern,1,
    [{clause,12,[{var,12,'X'}],[],
        [{'case',13,{var,13,'X'},
            [{clause,14,[{integer,14,-5}],[],[...]},            %% pattern: FOLDED, bare literal
             {clause,15,[{var,15,'_'}],[],[...]}]}]}]}.
```

**All three positions fold identically**: `-5` is `{integer,_,-5}`, a plain negative literal, in
the guard, the bare comparison, *and* the pattern — Gleam has no pattern/expression split at all
for this. But (checked in `compiler-core/src/parse.rs:862-878`) **Gleam's own parser doesn't fold
either** — it produces the same kind of wrapper node beam-sharp has:

```rust
// Int negation
Some((start, Token::Minus, _end)) => {
    self.advance();
    match self.parse_expression_unit(ExpressionUnitContext::Other)? {
        Some(value) => UntypedExpr::NegateInt { location: ..., value: Box::from(value) },
        ...
```

`type_/expression.rs:987-1053`'s `infer_multiple_negate_int` keeps it as a typed `NegateInt` node
through type inference too — it does **not** fold there either. The literal appears only in the
final Erlang codegen (`compiler-core/src/erlang.rs:902`, `TypedExpr::NegateInt =>
builder.unary_operator(location, "-")`); the actual fold-to-literal is inside the external
`erlang_generation` crate's `ErlangBuilder::unary_operator` (not vendored in this checkout, so its
source isn't citable directly — its effect is what the `.abstr` dump above shows empirically).

So Gleam's answer to (a) is neither "grammar" nor quite "checker" as the ticket poses it —
it's **codegen**, later than both. That's not a third option worth adopting here (beam-sharp's
`alternatives/1` runs *before* codegen, at type-check time, so a codegen-time fold would be too
late to help `refine/3` at all), but it is the strongest evidence for the *uniformity* half of the
recommendation: the one modern statically-typed BEAM-sibling that exists draws **no** distinction
between pattern, guard and bare-expression position for a negative literal, anywhere in its
pipeline. beam-sharp's pattern rule already treats `-N` as a literal at the grammar; Option A just
extends that same treatment to every other `expr_low`, closing the one place beam-sharp itself is
inconsistent — not opening a new inconsistency to match a neighbour.

## Neighbour-language survey (file:line)

| Language | Where the fold happens | Scope of the fold | Citation |
|---|---|---|---|
| Erlang | Linter (`erl_lint`), not the grammar | Any closed arithmetic expression (`+ - * / bnot div rem band bor bxor bsl bsr`), recursively, **pattern position only** — guards need none | `erl_lint.erl:1877-1908` (`is_pattern_expr/1`, `is_pattern_expr_1/1`), `erl_internal.erl:143-157` (`arith_op/2`), fold itself is `erl_eval:partial_eval/1` |
| Gleam | Codegen (`erlang.rs`), not the parser and not the typechecker | Unary negation of an already-typed `Int`, uniformly across pattern/guard/bare-expression — Gleam has no split to begin with | parser wrapper: `compiler-core/src/parse.rs:862-878` (`UntypedExpr::NegateInt`); kept through typing: `compiler-core/src/type_/expression.rs:987-1053`; folded at emission: `compiler-core/src/erlang.rs:902` (delegates to the external `erlang_generation` crate, not vendored here) |
| beam-sharp, patterns (today) | Grammar | Bare literal, unary minus only | `bs_parser.yrl:349` (`pattern -> '-' integer`), `:423-424` (`int_lit`) |
| beam-sharp, refinements/guards (today) | Nowhere — this is the bug | — | `bs_parser.yrl:543` (`negate/2`, only floats fold, `:859-860`); `bs_check.erl:4216-4217` (`comparison/1`, no `e_neg` clause) |

Elixir was checked as instructed but adds nothing beyond Erlang here: its `when x >= -5` guard
compiles to the same `erl_parse`-level `{op,'-',{integer,5}}` shape via `:elixir_erl`, since
Elixir's guard machinery is a thin layer over Erlang's own guard BIFs and inherits the same
"guards need no fold" property — Elixir has no static exhaustiveness proof either, so there is no
Elixir-side analogue of `refine/3` to compare against.

## Measured costs

Real diffs, taken against the actual files (`diff -u` output, not an estimate):

**Option A — `bs_parser.yrl`, `negate/2`:**

```diff
 negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
+negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};
 negate(L, E)                 -> {e_neg, L, E}.
```

**+1 line**, `bs_check.erl` untouched. The comment at `bs_parser.yrl:539-542` ("A negated float
literal folds to the literal...") would want a clause naming int too — call it +3 lines of comment
tidy, so **~4 lines total**, one file.

**Option B — `bs_check.erl`, `comparison/1`:**

```diff
-comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
-comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
+-define(IS_INT_CONST(X), ...).
+int_const({e_int, _, K})             -> K;
+int_const({e_neg, _, {e_int, _, K}}) -> -K.
+comparison({e_op, _, Op, {e_var, _, V}, R}) when ?IS_INT_CONST(R) -> ...
+comparison({e_op, _, Op, L, {e_var, _, V}}) when ?IS_INT_CONST(L) -> ...
```

**+17/-2 lines**, one file. No grammar change, no new yecc conflicts by construction (grammar
untouched at all).

**Grammar-conflict cost, measured, not assumed:** `yecc` reports **5 shift/reduce, 0
reduce/reduce** conflicts on the stock grammar and **the same 5/0** on Option A's patched grammar
— the change is additive to `negate/2`'s clause list, not to any production, so it cannot introduce
a new conflict, and didn't.

**Corpus cost of not generalising past bare-literal (answers (b) empirically):** every refinement
that exists in the repo today is bare-literal comparands only —

```
Escalate/escalate.bs:37   int where value >= 0 and value <= 40
Frame/frame.bs:41         int where value >= 0 and value <= 255
Frame/frame.bs:43         int where value >= 0 and value <= 15
Wire/wire.bs:28           int where value >= 0 and value <= 255
F13, F2, F26, F37, F42    (spec/feature docs) — same shape throughout
```

Zero occurrences of compound arithmetic (`2+3`-style) in any refinement anywhere in the corpus.
Building Erlang's general closed-arithmetic fold would cost strictly more than either option above
and fix a case nobody has written.

## Options

### Option A — grammar: complete the fold `negate/2` already half-has (recommended)

```erlang
%% bs_parser.yrl, in the Erlang code section:
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int, IL, N})   -> {e_int, IL, -N};   %% NEW — mirrors the float clause above
negate(L, E)                 -> {e_neg, L, E}.
```

`refinement -> expr_low` (`bs_parser.yrl:174`) is untouched; refinements keep reading exactly what
`alternatives/1` reads for a guard, per the invariant the ticket flags.

**Evidence for:** 1-line diff (Probe 2); measured zero new grammar conflicts; fixes the refinement
*and* the guard in one place, since every user of `expr_low` shares `negate/2` (Probe 4); doesn't
touch `bs_check.erl` at all, so `alternatives/1`/`comparison/1` keep exactly one shape of "constant"
to reason about everywhere they're called, refinements or guards; matches the direct-ancestor
principle of "fold at whatever level already treats `-N` as one token" — beam-sharp's own pattern
grammar already does this (`bs_parser.yrl:349,423-424`), so this is consistency with beam-sharp's
own prior decision, not a new one; matches Gleam's observed behaviour of never distinguishing
pattern/guard/bare-expression position for this (Probe 6).

**Strongest counterargument against:** it is a grammar change to `expr_low`, and `expr_low` is not
refinement-specific — a reviewer skimming only the diff, without reading `negate/2`'s existing float
clause, could mistake this for "the grammar special-cases refinements after all," the exact shape
the `bs_check.erl` comment says must never happen. The rebuttal is that the patch touches
`negate/2`, called from a single shared production (`bs_parser.yrl:543`) that every guard, every
refinement and every plain expression already funnels through — there is no refinement-specific
production before or after this patch — but the ticket explicitly asked this option to be treated
as suspect, and the point stands as a *documentation* burden: the comment at `bs_parser.yrl:539-542`
needs a sentence saying "and ints, so a refinement's negative literal folds too" or a future reader
re-litigates this exact question.

### Option B — checker: fold at `comparison/1`, leave the grammar with one asymmetry unfixed

```erlang
%% bs_check.erl, replacing the two `{e_int, _, K}`-only comparison/1 clauses:
-define(IS_INT_CONST(X),
        (element(1, X) =:= e_int orelse
         (element(1, X) =:= e_neg andalso element(1, element(3, X)) =:= e_int))).

int_const({e_int, _, K})             -> K;
int_const({e_neg, _, {e_int, _, K}}) -> -K.

comparison({e_op, _, Op, {e_var, _, V}, R}) when ?IS_INT_CONST(R) ->
    int_cmp(Op, V, int_const(R));
comparison({e_op, _, Op, L, {e_var, _, V}}) when ?IS_INT_CONST(L) ->
    int_cmp(flip(Op), V, int_const(L));
```

**Evidence for:** touches only the one function both refinements and guards already share
(`alternatives/1`'s `comparison/1`), so the "same reader" invariant is visibly, locally true in the
diff itself, rather than true-by-construction-through-`negate/2` as in Option A — a reviewer who
distrusts grammar changes near `refinement ->` doesn't have to reason about `expr_low`'s other
sixteen call sites at all; keeps the door open to generalise later (Erlang's `is_pattern_expr_1`
shape, Probe 5) by only ever touching this one function again, never the grammar.

**Strongest counterargument against:** three times the diff (17/−2 vs 1 line, Measured costs);
leaves the AST itself inconsistent — `-5` is `{e_int,-5}` if written as a bare literal but
`{e_neg,{e_int,5}}` if written with a unary minus, forever, in every other consumer of these nodes
that isn't `comparison/1` (there are none *today* — checked: the refinement's `Pred` field is read
in exactly one place, `refine/3`, per `bs_check.erl`'s `type_refined`/`resolve` chain — but the next
feature that walks a raw guard or refinement expression, e.g. a future pretty-printer for
"what did you write" diagnostics, inherits the same gap Option A closes for free); and it leaves
`x + -5` in a function *body* (not a guard, not a refinement) still building an `e_neg` node
forever, which is harmless at runtime (`bs_emit.erl:997` emits it as `{op,L,'-',...}` correctly
either way) but means beam-sharp keeps two representations of "the number negative five" side by
side indefinitely, one of them accidental.

### Option C — generalise to Erlang's rule (not recommended now, noted for completeness)

Same shape as Option B's macro, but `int_const/1` recurses over the whole `arith_op`-style table
(`+ - *` at minimum, since `/ %` don't exist in the lexer yet per ticket 38) instead of stopping at
literal-or-negated-literal, mirroring `erl_lint.erl:1877-1908` exactly.

**Evidence for:** principled, matches the direct ancestor's actual answer to "how far", would make
`value >= 2 + 3` legal today for whoever eventually wants it.

**Strongest counterargument against:** nobody wants it yet — Measured costs shows zero refinements
in the corpus use compound arithmetic — and it reopens exactly the question CLAUDE.md says a design
question must not be: "where does it stop" without a program in hand that needs the answer. Ticket
57's own repro is `-5`, not `2+3`; building for the second when only the first was asked is scope
the ticket didn't earn.

## Recommendation

**Option A.** It is the smaller diff by a factor of four, it repairs an asymmetry (`negate/2`
folding floats but not ints) that was almost certainly an oversight in F51 rather than a decision,
it fixes the guard-side quieter symptom for free, and — per (c) — it does not reopen the
refinement/guard invariant; if anything it makes that invariant hold more completely than it does
today. Its one real cost is documentation: the comment at `bs_parser.yrl:539-542` should gain a
clause naming ints, so the next reader doesn't have to re-derive why `-5` folds but `-x` doesn't.

Leave Option C for whenever a real program asks for `value >= 2 + 3` or similar; nothing in this
repo does yet.

## Verification

No `Agent`/`Task`-style subagent-spawning tool is exposed in this environment (checked via
`ToolSearch`), so the independent re-run the task asked for was done as a second, from-scratch
pass in this same session rather than by a separate spawned agent — a fresh scratch build
(`verify/`), re-typed patches rather than reused files, re-derived independently of the first
pass's intermediate variables, and re-run without consulting the first pass's output:

- Re-regenerated `bs_lexer`/`bs_parser`/`bs_check`/`bs_types`/`bs_diag`/`bs_lower` from the
  untouched repo source into a second scratch tree; **same 5 shift/reduce, 0 reduce/reduce**
  warning.
- Re-ran the `int where value >= -5` refusal: same AST (`{e_neg,2,{e_int,2,5}}`), same error tag
  and line, `{opaque_refinement,2}`.
- Re-ran the pattern (`Sign(<= -1)`) and the disjoint-union control case
  (`value <= 3 or value >= 10`): both `{ok, _}`, no exception, matching the ticket's table.
- Independently re-typed Option A's one-line `negate/2` patch (not copied from the first pass's
  patch file) into a fresh `.yrl` copy, rebuilt only the parser, and got the same result against
  the *first pass's* unmodified `bs_check.beam`: `{ok,ok}` for `-5`, still `{opaque_refinement,2}`
  for `2 + 3`.
- Independently re-wrote and recompiled the Erlang guard module (`verify_guard.erl`, a different
  filename and module name from the first pass's `neg_guard.erl`) and re-ran
  `erl_parse:parse_form/1` on the same guard text: identical `{op,1,'-',{integer,1,5}}` shape,
  runtime behaviour matches (`bucket(-5)=low`, `bucket(-6)=high`).
- Re-read the already-built Gleam `.abstr` artifact independently (a fresh `erl` invocation,
  filtering for `bare_compare` alone) and got the same `{integer,9,-5}`.

No probe was found to have been "massaged": the baseline refusal reproduces for the same reason
(`opaque_refinement` on an `e_neg`-wrapped comparand) on both passes, and every comparison table
(Probes 2–3) reproduced identically on re-derivation.

## Files read for this brief

- `wayfinder/issues/57-negative-literals-in-refinements.md`, `38-division-and-modulo.md`,
  `20-untheorised-term-shapes.md` (its `## Decisions entry`, `:711-751`)
- `compiler/src/bs_parser.yrl` (`int_lit`, `refinement ->`, `negate/2`, lines 174, 349, 423-424,
  539-543, 858-860)
- `compiler/src/bs_check.erl` (`refine/3` 1549-1566, `alternatives/1`/`comparison/1` 4185-4231)
- `compiler/src/bs_emit.erl` (`e_neg`/`e_int` emission, 885, 997)
- `compiler/features/F2-interval-refinements.md`, `F51-float.md`
- `/tmp/otp-src/lib/stdlib/src/erl_lint.erl`, `erl_internal.erl`
- `/tmp/gleam-src/compiler-core/src/parse.rs`, `type_/expression.rs`, `erlang.rs`
