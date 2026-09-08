# Ticket 57 — decision brief (autonomous research, not a decision)

**This is research for David's review.** Nothing in ticket 57, ticket 38, ENG-239, or any
other tracked file was edited to produce it — every experimental grammar/checker change
described below was applied to a scratch copy or reverted immediately after measurement, and
`git status --short compiler/` was re-confirmed clean (twice, once mid-session and once at the
very end) throughout. No `Agent`/`Task` tool exists in this environment to spawn a genuinely
separate verifier subagent — only `SendMessage` to an already-listed peer, which needs one to
exist first, and none did. That is recorded rather than papered over. In its place: every claim
below was re-executed **independently**, a second time, from a from-scratch `leex`/`yecc`/`erlc`
build in a separate scratch directory (`/tmp/verify2`, since deleted), patched by a small Python
script rather than the same edit tool used the first time, with exit codes asserted
programmatically rather than eyeballed. Results matched exactly on every probe. This is a
weaker substitute than a second reasoner and is flagged as such, per the instructions.

**Toolchain note.** This container ships Erlang/OTP 25 (`erts-13.2.2.5`), not the
`.tool-versions`-pinned 28.5, and has no `rebar3` binary anywhere on disk (one appeared at
`/usr/local/bin/rebar3` partway through the session, apparently from background provisioning,
but `rebar3 escriptize` still fails: `bs_lexer.xrl`'s `{error_location, column}` option
(`compiler/rebar.config`) is an OTP 26+ addition to `leex`, confirmed by reading
`/usr/lib/erlang/lib/parsetools-2.4.1/src/leex.erl`'s `all_options/0`, which does not list it).
`bsc` was therefore built by hand — `leex:file/2` without that one option, `yecc:file/1`,
`erlc` over all of `compiler/src/*.erl` — into a scratch `ebin`, wrapped in a shell script that
calls `bsc:main/1` directly. Every real-compiler claim below ran through that build. This is an
environment gap, not a repo defect, and does not touch anything CI verifies.

## 1. The repro, confirmed against the real, built `bsc`

```
$ bsc /tmp/.../T1        # module T1 { type T = int where value >= -5; ... }
T1/a.bs:2:1: error: this refinement is not a predicate the checker can read
  a refinement narrows a type, so the compiler has to be able to
  reason about it: comparisons on `value`, joined with `and`/`or`.
  ...
exit code: 1
```
Byte-for-byte what ticket 57 recorded (the ticket's paste is a subset of the same prose; the
full message adds an "O(n) tier" paragraph the ticket didn't quote). Re-ran the ticket's own
prototype, adapted for this build (`38b_divisor_expressiveness.sh`'s seven cases): **all seven
matched what ticket 38/57 recorded**, exit codes included. The interval-algebra residual claim
(`subtract(-10..10, range(0,0))` → `-10..-1 | 1..10`) was also re-run directly against
`bs_types:subtract/2` and matches exactly.

## 2. Where it actually happens — read from the real source, not guessed

**It is a checker issue, not a lexer issue, and the grammar already parses `-5` — just not into
a literal.** `bs_lexer.xrl` has no negative-number token; `-` and `5` are always two tokens.
`bs_parser.yrl` genuinely has **two competing productions for what `-` does to what follows it**,
and the one a refinement predicate reaches is the wrong one for this purpose:

```erlang
% compiler/src/bs_parser.yrl:448  -- a bare literal
expr -> integer  : {e_int, line('$1'), value('$1')}.

% compiler/src/bs_parser.yrl:452  -- general unary minus, ALWAYS desugars to subtraction
expr -> '-' expr : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.

% compiler/src/bs_parser.yrl:579  -- binary subtraction, same operator, same AST shape
expr -> expr '-'  expr : {e_op, line('$2'), '-',  '$1', '$3'}.

% compiler/src/bs_parser.yrl:171 -- a refinement is exactly this `expr` grammar, deliberately
refinement -> expr : '$1'.
```
So `value >= -5` parses to `{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}` — a real,
well-formed parse, just one whose right-hand side is an *arithmetic node* rather than a
constant. Contrast the pattern grammar, which has a **separate, narrower rule that exists
nowhere else**:

```erlang
% compiler/src/bs_parser.yrl:368-369
int_lit -> integer     : value('$1').
int_lit -> '-' integer : -value('$2').   % folds AT PARSE TIME, only here
```
`rel_test -> '>=' int_lit` (line 360) is why `Sign(<= -1)` reads the literal fine — patterns
never route through general `expr`, so they never meet rule 452.

The refusal itself is `bs_check.erl`'s `comparison/1` (lines 3111-3118), which only recognizes
a comparand that is *already* an `{e_int,_,K}` node:

```erlang
comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
...
comparison(_) -> unknown.
```
`{e_op,'-',{e_int,0},{e_int,5}}` matches none of these heads (its second element is `e_op`, not
`e_int`), falls to the catch-all, and `alternatives/1` (line 3105) propagates `unknown` up
through the `and`/`or` combinators, at which point `refine/3` raises `opaque_refinement`.
**Confirmed directly**, not inferred: calling `bs_check:comparison/1` on the real parsed node
for `value >= -5` returns the atom `unknown`.

**Verified independently: this is not lexer-, parser-ambiguity-, or type-algebra-shaped. It is
one checker function drawing its "is this a constant?" line one AST shape too narrowly**, on an
AST the parser was always going to hand it that way (`bs_parser.yrl:452` is 2026-08-13-vintage
walking-skeleton code, predating refinements entirely).

## 3. A finding the ticket doesn't mention: **guards have the identical defect**

`bs_parser.yrl:171`'s own comment says a refinement is deliberately `expr` so "a refinement and
a guard cannot disagree" — and `guard_expr -> expr` (line 445) means a guard's `-5` desugars
*identically*, reaching the *same* `comparison/1`. Refinements hard-error; guards do something
quieter and arguably worse. Measured on the real compiler, **before any fix**:

```csharp
module GuardNegExhaust
public atom F(int n)
F(n) when n >= -5 and n <= -1 -> :small_neg
F(n) when n <= -6 or n >= 0   -> :other
```
This pair of guards is jointly exhaustive over all of `int` *if* the checker reads both — and
today it does not: `alternatives/1` returns `unknown` for each clause, `apply_guard` "credits
nothing" (the ticket-08 rule that stops `F(n) when Weird(n)` from being miscredited as
exhaustive), and **the compiler reports `F` as not exhaustive**, exit 1 — with no diagnostic
naming a negative literal anywhere, just a plain "no clause matches" the reader has to puzzle
out. (An earlier draft of this brief reported this case compiling clean; that was a test-harness
ordering artifact in a batched shell command — re-run in isolation, twice, it reliably reports
inexhaustive on an unmodified `bs_check.erl`, and reliably reports exhaustive once either fix
below is applied.) **Whatever fixes ticket 57 fixes this identically**, by construction — both
routes go through the same `alternatives/comparison` pair — but it is worth David knowing the
blast radius is "refinements and guards," not "refinements."

## 4. Prior art, from real BEAM-family source and real runs — not recollection

**Erlang's own grammar takes option B's shape, not option A's**, confirmed by reading
`/usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_parse.yrl` (OTP 25, this machine):

```erlang
% erl_parse.yrl:240 -- expressions
expr -> prefix_op expr : ?mkop1('$1', '$2').
% erl_parse.yrl:270 -- PATTERNS, the identical shape, not a separate literal rule
pat_expr -> prefix_op pat_expr : ?mkop1('$1', '$2').
% erl_parse.yrl:519-522
prefix_op -> '+' | '-' | 'bnot' | 'not'.
```
No `pat_expr -> '-' integer` literal-fold rule exists anywhere in Erlang's own grammar — `-5` in
a *pattern* builds the exact same `{op,Anno,'-',{integer,Anno,5}}` node it would in an
expression. Legality is decided **later**, in `erl_lint.erl`:

```erlang
% erl_lint.erl:1904-1907 -- and it is not limited to unary minus of a bare literal
is_pattern_expr_1({op,_Anno,Op,A}) ->
    erl_internal:arith_op(Op, 1) andalso is_pattern_expr_1(A);
is_pattern_expr_1({op,_Anno,Op,A1,A2}) ->
    erl_internal:arith_op(Op, 2) andalso all(fun is_pattern_expr/1, [A1,A2]);
% erl_lint.erl:1880-1892 -- and then it is actually EVALUATED, not just shape-checked
is_pattern_expr(Expr) ->
    case is_pattern_expr_1(Expr) of
        false -> false;
        true -> case erl_eval:partial_eval(Expr) of
                    {integer,_,_} -> true; ... ; _ -> false
                end
    end.
```
Compiled and ran this for real (`erlc`/`erl`, OTP 25, this container, re-verified a second time
independently):

```erlang
f(-5) -> neg5;
f(2+3) -> five;
f(-(2+3)) -> negfive;   % erlc: "Warning: this clause cannot match because a
                        %        previous clause at line 3 always matches" --
                        %        the compiler evaluated -(2+3) to -5 and saw
                        %        clause 1 already covers it.
f(_) -> other.
```
`f(-5)` → `neg5`, `f(5)` → `five`, `f(-6)` → `other`. **Erlang's answer to "where does the fold
stop" — the exact question ticket 57 raises and declines to answer — is "any expression built
only from arithmetic operators over literals, checked by actually evaluating it."** That is
option B, generalized past a single unary-minus special case.

**Elixir draws the line tighter than Erlang, not looser.** Compiled and ran for real
(`elixir` 1.14, this container, re-verified independently):

```elixir
defguard small_neg(n) when n >= -5 and n <= -1
def f(n) when small_neg(n), do: :small_neg    # -3 -> :small_neg  (real run)
def f(-5), do: :neg5                          # negative literal pattern: fine
def f(2 + 3), do: :five                       # ** (CompileError) cannot invoke
                                               #    remote function :erlang.+/2
                                               #    inside a match
```
So a bare negative literal is fine in both a guard and a pattern (Elixir most likely lexes `-5`
as one token in these positions rather than folding a subtraction node — this was not traced
into Elixir's own grammar source, since none is vendored here, so treat that mechanism as
inferred rather than measured; the *behavior* is measured). General constant arithmetic is
**refused** in pattern position, unlike raw Erlang. Two real BEAM languages, sharing a runtime,
made different calls about how far "constant" reaches in a pattern — which is exactly the
open question ticket 57 leaves.

**Elm could not be verified in this environment**, and that is reported rather than guessed
around: `elm make` and `elm repl` both fail identically —
`ProxyConnectException "package.elm-lang.org" 443 (Status 403 Forbidden)` — because `elm`
cannot resolve `Basics`/`elm/core` without fetching the package registry, and this container's
egress proxy denies that host by policy. No cached `elm/core` exists anywhere on disk to route
around it. **Any Elm claim below is therefore unverified**, carrying the same caveat the task
gave for Gleam: Elm is widely documented as requiring parens around a negative pattern literal
(`(-5)`, since a bare `-5` in that position lexes as part of an infix operator ambiguity with
the preceding token), but this was not compiled here and should not be cited as measured.

## 5. Option A — fold in the grammar, mirroring `int_lit`

```erlang
%% inserted at bs_parser.yrl, immediately before the existing unary-minus rule
expr -> '-' integer : {e_int, line('$1'), -value('$2')}.
expr -> '-' expr    : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.   % existing
```

**Measured, independently, twice.** Baseline `yecc:file/1` on `bs_parser.yrl` unmodified: **225
shift/reduce conflicts, all resolved by the declared operator precedences, 0 reduce/reduce, 0
left unresolved** (yecc's own report; `{ok,...}` with no warnings on a plain, non-verbose
compile). With this one rule added: **268 conflicts (+43)**. Unlike the baseline's 225, these 43
are **not** precedence-table conflicts — they are a genuine reduce/reduce-shaped ambiguity, all
in one state, reported for every possible lookahead token:

```
Parse action conflict scanning symbol '+' in state 253:
   Reduce to expr from integer (rule 113 at location 448:1)
      vs.
   reduce to expr from '-' integer (rule 114 at location 453:1).
Resolved in favor of expr.
```
This is LALR state-merging: after shifting `'-' integer`, the parser cannot tell "this `-` just
started a fresh literal" from "this `-` was the binary-subtraction operator and `integer` is its
right operand" — both reach the identical stack shape. yecc resolves it silently, by which rule
was declared first in the file, **not** by the `Left 400 '+' '-'` precedence declaration (this
is a reduce/reduce tie, precedence only arbitrates shift/reduce). That is a real fragility: the
correct behavior today depends on rule 114 being written before rule 452 textually, which nothing
enforces or would obviously break loudly if violated by a later edit.

**Despite that, it behaves correctly on every case constructed to probe it — including cases
past ticket 57's own scope.** Rebuilt in full, then:
- Ordinary and chained subtraction unaffected: `a - 5` → `{e_op,'-',a,5}`; `10 - a - 3` →
  correctly left-associated; `- -5` → `{e_op,'-',0,{e_int,-5}}` (outer general unary, inner
  literal-folded — semantically correct double negation).
- **The ticket's own headline example now compiles and behaves correctly end to end,
  including the call site**:
  ```csharp
  type D = int where value >= -100 and value <= 100
  public int Id(D b)
  Id(b) -> b
  public int Go()
  Go() -> Id(-50)     // accepted
  Go() -> Id(-101)     // refused: "argument 1 is not covered ... -101"
  ```
  This is because the fix is at the parser: **every** site that sees `-N`, not only refinement
  predicates, now gets a real `e_int` — call arguments included.
- Full `compiler/examples/` corpus (16 modules, correctly invoked) compiles clean, no
  regressions.

**Counter-argument.** The reduce/reduce ambiguity is real and is the kind of thing that reads
fine today and bites later: any future grammar edit that reorders these two rules, or adds a
third production reachable from the same state, changes behavior silently, with no compiler
warning pointing at the actual risk (yecc reports the conflict count but not "this one is
order-dependent, watch it"). It also touches the **shared** `expr` grammar that guards, call
arguments, and every other expression position read from — which is *why* it fixes more than
the ticket asked for, but is also a wider blast radius for one patch than the ticket's own
"reintroduces exactly the guard/refinement split" worry about a *narrower* refinement-only
grammar fork. (That narrower fork — giving `refinement` its own comparand grammar instead of
`expr` — was not separately built: it would mean forking every comparison operator and the
`and`/`or` combinators away from `expr`/`guard_expr`, a materially bigger change than one rule,
and is the literal "reintroduces the split" ticket 57 already argues against.)

## 6. Option B — fold in the checker, mirroring Erlang's `is_pattern_expr`/`partial_eval`

```erlang
%% inserted at bs_check.erl, immediately before comparison/1's existing e_var/e_int clauses
comparison({e_op, L, Op, V = {e_var, _, _}, {e_op, _, '-', {e_int, _, 0}, {e_int, _, K}}}) ->
    comparison({e_op, L, Op, V, {e_int, L, -K}});
comparison({e_op, L, Op, {e_op, _, '-', {e_int, _, 0}, {e_int, _, K}}, V = {e_var, _, _}}) ->
    comparison({e_op, L, Op, {e_int, L, -K}, V});
comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);   % existing
```

**Measured, independently, twice.** Zero grammar changes — `bs_parser.yrl` untouched, so the
yecc conflict count stays at baseline (225, 0 reduce/reduce). All three of ticket 57's exact
refused cases now accept (`NegSingle`/`NegAnd`/`NegOr` from the adapted `38b` probe). **Also
fixes the guard-crediting gap from §3** — `GuardNegExhaust` goes from inexhaustive to exhaustive
— for free, since `comparison/1` is the one shared function both routes call.

**Full `eunit` suite run, twice** (once against this patch, once against a byte-verified-clean
control build of the original `bs_check.erl`): **692 passed, 3 failed, identically, on both.**
The three failures (`cli_tests:batch_runs_every_entry_in_one_vm...`, a UTF-8 round-trip mismatch;
`ffi_tests:a_stray_semicolon_says_what_to_do_test`, a message-text mismatch; and
`negation_tests:bang_is_taught_test`, which crashes inside `bs_diag:message/1` on the
*unmodified* control build too) are environment artifacts of this container's OTP 25 versus the
pinned 28.5 (and, for the first, of this session's hand-rolled CLI wrapper rather than a real
escript) — **not** caused by this patch. Confirmed by running the same three tests against a
hash-verified unmodified `bs_check.beam`: identical failures.

**Counter-argument, measured rather than assumed.** The version tested here is deliberately
narrow — one unary-minus-of-literal shape, matching exactly what `comparison/1` needs. It does
**not** repair the ticket's own headline call-site case:
```csharp
type D = int where value >= -100 and value <= 100
...
Go() -> Id(-50)
```
still fails under option B alone, refused with `argument 1 is not covered by Id's declared type:
int <= -101 | int >= 101` — a **wrong-shaped** message that names the type's own residual rather
than the actual argument, because a call argument's type is inferred by an entirely different
code path than `comparison/1`, one this patch never touches. **This is real, not theoretical**:
verified by reverting to a byte-identical original `bs_check.erl` and confirming the *type
declaration itself* now fails there for the expected, different reason (the pre-existing
`opaque_refinement`), proving the call-site failure under option B is a distinct, still-open
gap and not a leftover from the type declaration being unbuildable. Closing it requires finding
and patching the argument-type-inference site too — not attempted here, out of scope for a
single `comparison/1` clause, and the honest reading of Erlang's own `is_pattern_expr` design is
that this narrow patch is the *first* of several sites that would eventually want the same
"evaluate a constant arithmetic subtree" helper, not a complete answer by itself.

## 7. Option C — require parens around a negative comparand (Elm-flavored)

```csharp
type T = int where value >= (-5)     // parens mandatory; bare `-5` stays refused
```
Cheapest possible grammar change (one rule, parenthesized, no ambiguity with binary subtraction
since `(` forces a fresh sub-expression state) — but weighed against real, measured evidence
against it:
- **Unverifiable here** (§4) — the Elm motivation for this spelling could not be confirmed by an
  actual compile in this environment, only cited as documented behavior.
- **It contradicts a decision already on record.** Ticket 42 (resolved 2026-08-15) put a
  relational **pattern** in the language specifically so `Sign(<= -1)` reads a bare `-1`, no
  parens, and its own answer leans on "one translator, so a guard and a refinement cannot
  disagree" (bs_parser.yrl:168-170, quoted in §2 above). Requiring parens *only* in refinement
  position, while patterns and guards stay bare, is a **new**, unforced asymmetry between three
  syntactic positions that ticket 42 and the refinement-is-`expr` design both already argue
  against creating. It is the ticket's own "grammar" option (§"The question") in a slightly
  different shape, carrying the same objection the ticket already raised about it.

Included because the task asked for it as a candidate shape; not carried forward as a serious
contender given ticket 42's standing decision.

## 8. Recommendation

**Option B's philosophy — fold in the checker, not the grammar — over Option A, on the strength
of real BEAM prior art and a real, measured grammar risk that Option A alone does not have.**
Erlang's own parser (§4) does not special-case unary-minus-of-literal in its grammar either; it
lets the general operator production stand and settles constancy afterward, by evaluation. That
is a closer match to this codebase's own stated intent at `bs_parser.yrl:168-170` ("a refinement
and a guard cannot disagree... read back by the same `alternatives/1`") than Option A's route,
which fixes the problem by making the *shared* `expr` grammar quietly context-sensitive about
literal-ness, with a measured, silently-order-dependent reduce/reduce ambiguity as the price.

**But the version measured here is not a complete fix**, only a demonstration that the approach
works and costs nothing in grammar risk. §6's counter-argument is real: closing the ticket
properly this way means finding wherever a call argument's type is inferred and giving it the
same treatment `comparison/1` got — ideally as one shared helper (a `bs_check` analogue of
Erlang's `is_pattern_expr/1` + `erl_eval:partial_eval/1`) rather than two independent patches
that can drift apart, which would also let it generalize past unary minus to whatever
constant-arithmetic scope David wants to commit to (ticket 57's own open question). That scoping
— how far the fold reaches, and whether it lives in one shared function or several — is exactly
the kind of question CLAUDE.md's working rules say should be answered as B# code plus a
compiler delta, not as a menu; §6 and §4 give the concrete shape of what that delta touches
if this is the direction taken. Left for David's call, with the evidence, not the decision,
in the ticket.
