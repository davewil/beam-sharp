# Brief: ticket 57 — negative literals in refinements

Research brief, not a decision. Does not resolve ticket 57; its `Status:` line and
`## Decisions entry` are untouched. `compiler/src/*` in the main working tree is untouched —
every patch below was built and tested in a separate `git worktree`, and `/home/user/beam-sharp`
is clean at the end of this session (`git status`: nothing to commit), HEAD
`7065fa0d97822a5f3126d88ecab087fd0427cbc1`.

## Sub-decisions extracted

1. **Grammar-fold vs checker-fold.** Named in the ticket, and the ticket's own framing of what
   "grammar" means turns out to be too narrow — see § 2 below. Both were built and measured; see
   § 4.
2. **If checker-fold, exactly what folds.** Literal negation only, or general constant arithmetic
   (`2 + 3`, `-(2 + 3)`, `10 - 15`)? Measured directly: the minimal fix (mirroring `negate/2`'s
   existing float case) handles literal negation only and leaves `2 + 3` refused; a second,
   independent fix in `bs_check.erl` handles the general case. See § 4.
3. **Does the guard side need the same fix, since guards and refinements share `expr`?** Not asked
   by the ticket in these words, but forced by its own cited design intent — "a refinement and a
   guard cannot come to disagree about what they mean" — and the answer is **yes**: a negative
   literal in a **guard** is independently broken today, confirmed by a real compile (§ 3), and
   neither of the ticket's two named options as literally described (a grammar rule scoped to
   `refinement`'s comparand; a fold inside `refine/3`) would fix it. Both patches actually built
   below fix the guard case too, because both intervene at a point the two share.
4. **Does pattern-position parsing need to change too?** No. `pattern -> '-' integer` (line 335)
   and `int_lit -> '-' integer` (lines 409–410) are separate, narrower grammar productions that
   already fold at parse time and go nowhere near `expr_low`. They are correct today and orthogonal
   to whichever fix is chosen. Confirmed unaffected by both patches (§ 4).

## Methodology

Every claim below with a `$` prompt, a `bsc` transcript, or a `file:line` citation was executed or
read in this session against the toolchain in `RESEARCH_ENVIRONMENT.md` (OTP 28.5, erts-16.4,
Elixir 1.19.5, Gleam 1.18.1; `bsc` built at `compiler/_build/default/bin/bsc`). Probe `.bs` files
live under this session's scratchpad at `ticket57/probes/` and `ticket57/verify/`, one directory
per module (`bsc`'s own rule: one directory is one module). Both patches were built as isolated
`git diff`s, applied with `git apply` inside a fresh `git worktree`, built with
`rebar3 escriptize`, and tested against the pristine baseline binary side by side. No
subagent-spawning tool was available in this environment (`ToolSearch` for an `Agent`/`Task` tool
returned nothing matching a general-purpose subagent); § Verification is instead an independent,
adversarial second pass — fresh worktrees built directly from the saved `.diff` files (not the
already-built ones), with new probes designed to falsify the first pass rather than confirm it.

## 1. The source, read before probing — and the ticket's own root cause is now stale

The ticket traces the bug to unary minus desugaring to `{e_op, '-', {e_int,0}, expr}`. **That is no
longer what the grammar does.** `compiler/src/bs_parser.yrl:498` (confirmed at HEAD):

```erlang
expr_low -> '-' expr_low : negate(line('$1'), '$2').
```

`negate/2`, `bs_parser.yrl:793–794`:

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(L, E)                 -> {e_neg, L, E}.
```

This is F51's work (`float`, done 2026-09-16 — the day before ticket 57 was raised had already
passed by the time this session ran; F51 landed nine days after the ticket). Unary minus is now
its own AST node, `e_neg`, not a subtraction — the comment at line 494–497 explains why: `0 - e`
put an `int` beside a `float` at one operator, which ticket 80 refuses. **But the float-only
special case in `negate/2` is exactly ticket 57's bug, preserved through a refactor**: negating a
float literal folds to the literal; negating an int literal does not. `-5` produces
`{e_neg, L, {e_int, L2, 5}}`, an unfolded node, in every `expr_low` position — refinement
comparand, guard comparand, ordinary expression alike.

The other productions, confirmed at HEAD:

```erlang
171  refinement -> expr_low : '$1'.
335  pattern -> '-' integer : {p_int, line('$1'), -value('$2')}.
409  int_lit -> integer     : value('$1').
410  int_lit -> '-' integer : -value('$2').
```

`int_lit` feeds `rel_test` (`>=`/`>`/`<=`/`<` over a relational pattern, e.g. `Sign(<= -1)`), and
`pattern -> '-' integer` feeds an ordinary literal pattern (`f(-5) -> ...`). Both are narrow,
two-token productions that fold at parse time and never touch `expr_low` or `e_neg`. They are
correct today, independent of the bug, and out of scope for either fix.

`compiler/src/bs_check.erl`. `refine/3`, lines 1995–2013, calls `alternatives/1` (line 1996);
`resolve/3`'s `t_refined` clause (lines 1982–1983) is what invokes `refine/3` for a `type T = ...
where ...` declaration. `alternatives/1` and its helper `comparison/1`, lines 5287–5314:

```erlang
5307  comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
5308  comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
...
5313  comparison(_) -> unknown.
```

`comparison/1` matches a bare `{e_int, _, K}` literally. `value >= -5` reaches it as
`{e_op, '>=', {e_var, value}, {e_neg, _, {e_int, _, 5}}}` — the RHS is `e_neg`, not `e_int`, so
neither clause matches, it falls to the catch-all, `unknown` propagates out of `alternatives/1`,
and `refine/3` raises `opaque_refinement`. Confirmed exactly as traced, modulo the AST shape
(`e_neg` wrapping a literal, not a subtraction over `e_op`).

**`apply_guard/3` (lines 5264–5283, the guard's own narrowing) calls this exact same
`alternatives/1`.** This is the mechanism behind sub-decision 3: whatever breaks refinements breaks
guards identically, because they are one function, not two — the design intent the ticket cites
("one translator... so a parameter declared `Octet` and a clause guarded `when n > 128` cannot
disagree") is *already* upheld by the code today. It is upheld for the wrong reason: both are
broken the same way, not both correct the same way.

## 2. Confirmed baseline — reproduced, not trusted from the ticket

Every row, compiled for real against the untouched `compiler/_build/default/bin/bsc`:

```
$ bsc -o /tmp/out T1/T1.bs        # type T = int where value >= -5
T1/T1.bs:3:1: error: this refinement is not a predicate the checker can read
  a refinement narrows a type, so the compiler has to be able to
  reason about it: comparisons on `value`, joined with `and`/`or`.
  `int where value >= 0 and value <= 255` is one.
  A predicate that reads the value instead — `WellFormed(value)` —
  is the O(n) tier. It is established once at a boundary and never
  reasoned about, and this compiler has no site to establish it at.
exit: 1

$ bsc -o /tmp/out T2/T2.bs        # ... and value <= 5
(same error)                      exit: 1

$ bsc -o /tmp/out T3/T3.bs        # value >= 1 or value <= -1
(same error)                      exit: 1

$ bsc -o /tmp/out T4/T4.bs        # value <= 3 or value >= 10
(nothing printed)                 exit: 0

$ bsc -o /tmp/out T5/T5.bs        # value != 0
(nothing printed)                 exit: 0
```

Matches the ticket's table exactly. Also reproduced, and **not in the ticket**:

```
$ bsc -o /tmp/out Sign/Sign.bs
Classify(<= -1) -> :neg   /   Classify(0) -> :zero   /   Classify(>= 1) -> :pos
(nothing printed)                 exit: 0
```

Pattern position works, as the ticket says. And the new finding, sub-decision 3:

```
$ cat GuardExhaustSig/GuardExhaustSig.bs
module GuardExhaustSig
atom Classify(int n)
Classify(n) when n >= -5 -> :ok
Classify(n) when n < -5  -> :neg

$ bsc -o /tmp/out GuardExhaustSig/GuardExhaustSig.bs
GuardExhaustSig/GuardExhaustSig.bs:3:6: error: Classify is not exhaustive
  no clause matches:
    Classify(n) -> ...
exit: 1
```

The positive-literal control (`n >= 5` / `n < 5`, otherwise identical) compiles clean, only a
benign "function is unused" warning. **The same bug exists in guards, today, with no ticket
raised for it** — it surfaces as a false `not exhaustive` rather than `opaque_refinement`, because
`apply_guard/3` treats `unknown` as "credits nothing" (sound but silent) rather than raising, so
two guarded clauses that mathematically cover `int` completely are reported as leaving a gap.

## 3. Both patches, built and measured

### Patch A — grammar-fold (in `bs_parser.yrl`)

One line, in `negate/2`, mirroring the float case immediately above it:

```diff
-%% A negated float literal is the literal; anything else is the BEAM's unary
-%% minus, typed by its operand (F51).
+%% A negated float or int LITERAL is the literal; anything else is the BEAM's
+%% unary minus, typed by its operand (F51). ...
 negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
+negate(_L, {e_int, IL, K})   -> {e_int, IL, -K};
 negate(L, E)                 -> {e_neg, L, E}.
```

Diff: **13 lines (11 insertions, 2 deletions)**, of which **one line is code** and the rest is
comment. This is *not* the grammar option as the ticket literally describes it — the ticket's
"grammar" option was a rule scoped to `refinement`'s own comparand, mirroring `int_lit`, which
would narrow `refinement -> expr` and reintroduce the two-grammar split the ticket itself warns
against. This patch instead fixes the one general-purpose AST-construction function every
`expr_low` position shares, so `refinement -> expr_low` needs no change and the split never opens.
It is "in the grammar" only in the sense of being in `bs_parser.yrl`, at parse time — `bs_check.erl`
is untouched.

Build: `rebar3 escriptize` — **5 shift/reduce, 0 reduce/reduce conflicts, identical to the
unpatched baseline** (measured by touching `bs_parser.yrl` on the untouched tree and rebuilding,
same count). No new conflicts.

Results, same probes as § 2:

| probe | baseline | Patch A |
|---|---|---|
| T1 `value >= -5` | refused | **compiles** |
| T2 `... and value <= 5` | refused | **compiles** |
| T3 `value >= 1 or value <= -1` | refused | **compiles** |
| T4 `value <= 3 or value >= 10` | compiles | compiles |
| T5 `value != 0` | compiles | compiles |
| T6 `value >= 2 + 3` | refused | refused (unchanged) |
| T7 `value >= -(2 + 3)` | refused | refused (unchanged) |
| T8 `value >= 10 - 15` | refused | refused (unchanged) |
| T9 `Compare(value, n) when value >= n` (guard, RHS a variable) | refused, `not exhaustive` | refused, `not exhaustive` (unchanged — correct) |
| Sign (relational pattern) | compiles | compiles |
| GuardExhaustSig (guard, `n >= -5`/`n < -5`) | refused, `not exhaustive` | **compiles** |

So Patch A fixes every literal-negation case, in refinements and in guards, changes nothing about
`2 + 3`-shaped constants, and does not touch the genuinely-unreadable variable case.

`rebar3 eunit`: **all 1008 tests passed.**
`bin/check-boundary-range.sh`, `bin/check-boundary-kind.sh`, `bin/check-residual-pasteable.sh`,
`bin/check-exemplar-frontier.sh` (the gates the ticket names plus F2's other exercised scripts,
per `F2-interval-refinements.md`'s scenario references): **all green**, output byte-identical to
the baseline run.

### Patch B — checker-fold (in `bs_check.erl`)

Adds `const_int/1` and `const_arith/3`, called from `comparison/1` before it decides whether an
operand is constant:

```erlang
comparison({e_op, _, Op, {e_var, _, V}, RHS}) ->
    case const_int(RHS) of
        unknown -> unknown;
        K       -> int_cmp(Op, V, K)
    end;
comparison({e_op, _, Op, LHS, {e_var, _, V}}) ->
    case const_int(LHS) of
        unknown -> unknown;
        K       -> int_cmp(flip(Op), V, K)
    end;
...

const_int({e_int, _, K})        -> K;
const_int({e_neg, _, E})        -> case const_int(E) of unknown -> unknown; K -> -K end;
const_int({e_op, _, '+', A, B}) -> const_arith(fun(X,Y) -> X+Y end, A, B);
const_int({e_op, _, '-', A, B}) -> const_arith(fun(X,Y) -> X-Y end, A, B);
const_int({e_op, _, '*', A, B}) -> const_arith(fun(X,Y) -> X*Y end, A, B);
const_int(_)                    -> unknown.

const_arith(F, A, B) ->
    case {const_int(A), const_int(B)} of
        {unknown, _} -> unknown;
        {_, unknown} -> unknown;
        {X, Y}       -> F(X, Y)
    end.
```

Diff: **42 lines (40 insertions, 2 deletions)** — roughly 3× Patch A. `bs_parser.yrl` untouched;
builds with the same 5/0 conflict count as baseline (the grammar did not change).

Results, same probes:

| probe | baseline | Patch B |
|---|---|---|
| T1–T5 | as § 2 | same as Patch A (all correct) |
| T6 `value >= 2 + 3` | refused | **compiles** |
| T7 `value >= -(2 + 3)` | refused | **compiles** |
| T8 `value >= 10 - 15` | refused | **compiles** |
| T9 (guard, variable RHS) | refused, `not exhaustive` | **refused, `not exhaustive` — unchanged, correctly** |
| Sign | compiles | compiles |
| GuardExhaustSig | refused | **compiles** |

**Where it stops, measured, not assumed**: T9's `Compare(value, n) when value >= n` still fails
exhaustiveness under Patch B. `const_int({e_var, _, _})` has no matching clause and falls to the
catch-all `unknown`, so a variable comparand is still refused rather than silently mis-evaluated —
this is the sub-decision 2 stopping line the ticket asked for, and it is enforced by
`const_int`'s own fall-through, not by a separate guard.

`rebar3 eunit`: **all 1008 tests passed.**
Same four gate scripts: **all green**, byte-identical output to baseline.

### Both patches leave patterns alone

`Sign/Sign.bs` (relational pattern, `Classify(<= -1)`) compiles under both — unsurprising, since
neither patch touches `pattern -> '-' integer` or `int_lit`, confirming sub-decision 4. Ordinary
subtraction is unaffected under both: `Sub(a, b) -> a - b` run as `Sub(10, 3)` returns `7` under
baseline and both patches, identically (verified in § Verification).

## 4. Cross-language survey — where the three closest precedents actually fold

**Erlang** does not fold at grammar/parse time, in *any* position. `erl_parse.yrl` gives unary
minus one uniform production wherever an operand can appear (`expr`, `pat_expr`, `bit_expr`, lines
269, 301, 339), producing `{op, Line, '-', Operand}` — never a folded literal. Confirmed by reading
the raw abstract form of a compiled module (`beam_lib:chunks(..., [abstract_code])`,
`raw_abstract_v1`): `f(-5) -> ...` parses to `[{op,{4,3},'-',{integer,{4,4},5}}]` as the pattern,
unfolded.

The fold happens **later, and asymmetrically between pattern and guard**:

- **Pattern position folds unconditionally**, in the mandatory Core-Erlang lowering pass —
  `lib/compiler/src/v3_core.erl:2638–2641`:
  ```erlang
  pattern({op,_Line,_Op,_A}=Op, St) -> pattern(erl_eval:partial_eval(Op), St);
  pattern({op,_Line,_Op,_L,_R}=Op, St) -> pattern(erl_eval:partial_eval(Op), St).
  ```
  under the comment "Evaluate compile-time expressions" (line 2625). `erl_eval:partial_eval/1`
  (`lib/stdlib/src/erl_eval.erl:2204–2223`) recursively evaluates **any** op tree over literals —
  `+`, `-`, `*`, tuples, cons cells, not just unary minus — via `ev_expr/1`
  (`erl_eval.erl:2214–2223`: `ev_expr({op,_,Op,L,R}) -> erlang:Op(ev_expr(L), ev_expr(R))`).
- **Guard position does not fold in the same mandatory pass.** Compiled with `+no_copt` (optimizer
  disabled) and dumped with `+to_core`, `n >= -3` in a guard shows up as a live runtime call —
  `call 'erlang':'-'(3)` wrapped in a `try`/`catch` — not a literal. It is only folded by the
  **optional** constant-folding optimization, `lib/compiler/src/sys_core_fold.erl:870–896`
  (`fold_call/5`, dispatching on `erl_bifs:is_pure/3`). With optimizations on (the default), the
  optimized Core dump shows `-3` as a folded literal; with `+no_copt`, it does not. **Erlang's own
  pattern and guard positions are not symmetric on this point today** — pattern folding is
  semantic (part of what a pattern *means*), guard folding is an optimizer's best effort (guards
  can't observe whether the subtraction ran at compile time or run time, so nothing depends on it).

**Elixir** matches Erlang's non-folding at the front end exactly. `elixir_parser.yrl` gives unary
minus one production, `build_unary_op/2` (`lib/elixir/src/elixir_parser.yrl:770–771`), applied
uniformly via `unary_op_eol matched_expr` etc. (lines 156–177) with no separate pattern grammar at
all. Confirmed directly: `quote do -5 end` returns `{:-, [...], [5]}`, unfolded, and the same shape
appears nested inside a guard's quoted AST. Yet `def f(-5), do: :neg5` matches `-5` correctly at
run time — Elixir defers entirely to its Erlang backend (it emits Erlang abstract forms and lets
`v3_core`'s pattern fold, described above, do the work), rather than folding anything itself.

**Gleam** folds earliest of the three, in the **lexer**, before any grammar production runs.
`compiler-core/src/parse/lexer.rs:886–917` treats a leading `-` immediately before a digit as part
of the number token itself (`is_negative`, `lex_decimal_number`), producing a single `Token::Int`
carrying a negative value. Line 172–177 disambiguates from binary subtraction by tracking whether
the *previous* token could be a left operand (`check_for_minus`, set after a name or number) — only
then does a following `-5` lex as `Minus` then `5`; everywhere else (start of a pattern, start of a
guard comparand, start of any expression) `-5` is one token. Verified end to end with a real
compiled and run program (`gleam run`, vendored `gleam_stdlib`):
```gleam
pub fn classify(n: Int) -> String {
  case n {
    -5 -> "neg5"
    n if n >= -3 -> "ge_neg3"
    _ -> "other"
  }
}
```
prints `"neg5"`, `"ge_neg3"`, `"ge_neg3"` for inputs `-5`, `-2`, `10` — pattern and guard agree,
by construction, because there is only one token stream.

**Reading across all three**: none of the three folds the way the ticket's literal "grammar"
option describes (a production scoped to one syntactic position, mirroring `int_lit`). The real
precedents cluster at two different points, both *earlier or later than* a position-scoped grammar
rule: Gleam folds at the lexer, uniformly, before parsing begins; Erlang and Elixir fold nowhere at
parse time and defer to a compiler pass after parsing — mandatory for patterns, optional
(optimization-only) for guards in Erlang's case. beam-sharp's own actual grammar option, Patch A
(fixing `negate/2`, a parser action invoked uniformly for every `expr_low`), sits closest to
Gleam's precedent in spirit — fold early, fold uniformly, no position-scoped rule — while Patch B
sits closest to Erlang's `v3_core:pattern/2` — fold in a dedicated pass, general over `+`/`-`/`*`,
gated on every leaf being a literal.

## 5. Options

### Option 1 — Patch A: fold `e_neg` over an int literal in `negate/2` (grammar)

**Evidence**: 13-line diff (1 line of code); fixes T1–T3 and GuardExhaustSig; 5/0 conflicts,
unchanged; 1008/1008 eunit; four gates green; closest real precedent is Gleam's lexer-level fold.
Fixes the guard bug the ticket didn't ask about, for free, because it intervenes at the one place
every `expr_low` position shares.

**Strongest counterargument**: it does not generalize. `2 + 3`, `10 - 15`, `-(2 + 3)` stay refused
(T6–T8, measured, unchanged from baseline). If "a refinement should read a comparand a human
would call constant" is the actual bar — and the ticket's own §2 phrasing floats `2 + 3` as
"probably" wanted — Patch A does not clear it and would need a second, later patch anyway.

### Option 2 — Patch B: `const_int`/`const_arith` in `comparison/1` (checker), stopped at `+`/`-`/`*` over literals

**Evidence**: 42-line diff; fixes T1–T3, T6–T8, and GuardExhaustSig; correctly still refuses T9
(`value >= n`, a variable) as `opaque_refinement`/`not exhaustive`, not silently; 1008/1008 eunit;
four gates green; closest real precedent is `v3_core:pattern/2` calling `erl_eval:partial_eval/1`,
which is exactly this shape — a dedicated pass, general over literal arithmetic, gated on every
leaf reducing to a literal.

**Strongest counterargument**: it is the larger diff for the same *measured* outcome on the
ticket's own five probes (T1–T5) — Patch A already fixes those, and the general-arithmetic
capability (T6–T8) was not asked for by any of the ticket's cited motivating cases (`Delta`,
`Fuel`/ticket 38's divisor). It also has to define and defend a stopping line — `+`/`-`/`*` here,
not `/` or `rem`, a choice this brief made but the ticket did not — where Patch A needs no such
line because it folds exactly one shape (a literal under a single negation) that `int_lit` and
`negate/2`'s existing float clause already establish as the language's convention.

### Option 3 — fold in a shared AST-normalization pass, distinct from both call sites

Not built (time did not permit a third full patch), but the survey in § 4 makes the shape
concrete: a pass that runs once, after parsing and before `bs_check` sees the tree, folding every
constant-arithmetic subtree everywhere (not just in `comparison/1`'s two operand positions) —
closer to Erlang's `v3_core` stage than to either Patch A or Patch B, since it would also normalize
a literal used in an ordinary expression, not only a refinement/guard comparand.

**Evidence for it existing as a live option**: `expr_vars/1` (`bs_check.erl:2847`) and
`type_of/3`'s `e_neg` clause (`bs_check.erl:3192`) show the checker already walks `e_neg` nodes in
several places beyond `comparison/1` — a normalization pass would collapse all of those call sites
to one.

**Strongest counterargument**: no measured evidence it is needed. Every gate and every probe in
this brief is satisfied by Patch A alone (or Patch B, for the wider arithmetic case) without
touching anywhere else `e_neg` is read. Building a shared pass for a generalization nothing in the
corpus asks for is exactly the kind of increment the working rules ask sessions not to take
speculatively.

## Recommendation

**Option 1 (Patch A).** It is the smallest change, it is already what beam-sharp's own pattern
grammar does in spirit (`int_lit`'s existing fold, and the float clause `negate/2` already
carried), it fixes the guard bug this session found that neither of the ticket's two named options
would have caught on its own, and it is the closer analogue of the survey's one clean precedent
(Gleam) rather than the messier one (Erlang's pattern/guard asymmetry). If `2 + 3`-shaped
refinements are wanted later, Option 2's `const_int`/`const_arith` is a self-contained addition on
top of Option 1 — the two are not mutually exclusive, and nothing in Option 1 needs to be undone to
add it. Ship Option 1 now; raise Option 2's general-arithmetic case as its own decision if and when
an exemplar actually needs `2 + 3` in a refinement, rather than deciding the stopping line today
against no real program that needs it.

## Verification

No subagent-spawning tool was available in this environment (`ToolSearch` queries for `Agent`,
`Task`, and `general-purpose` subagent surfaced no matching tool — confirmed the same absence noted
independently in `artifacts/59-boundary-guard-scope-brief.md`). This section is instead an
adversarial second pass, done in this same session but deliberately from scratch: two **new** git
worktrees (`/tmp/ticket57-verify-grammar`, `/tmp/ticket57-verify-checker`), each built by
`git apply`-ing the exact saved `.diff` files (`ticket57/patches/grammar-fix.diff`,
`checker-fix.diff`) rather than reusing the already-built binaries, then `rebar3 escriptize` from
clean. Both diffs applied without fuzz and both built with the same 5/0 conflict count as baseline.

**Checking for the named failure mode — a fix that only handles the ticket's own literal
examples.** Five new probes, none reusing the ticket's `-5`/`-1`/`-3` magnitudes or variable names:

| probe | construction | baseline | Patch A (fresh) | Patch B (fresh) |
|---|---|---|---|---|
| VA | `value >= -42` | refused | **compiles** | **compiles** |
| VB | `value >= -(-7)` (double negation) | refused | **compiles** | **compiles** |
| VC | `-10 <= value` (literal-first, flipped operand order) | refused | **compiles** | **compiles** |
| VD | guard, variable named `score`, bound `-999` | refused, `not exhaustive` | **compiles** | **compiles** |
| VE | guard, `score > -999` / `score < -999` — a genuine, deliberately introduced exhaustiveness gap at exactly `-999` | refused, `not exhaustive` | **refused, `not exhaustive` — correctly** | **refused, `not exhaustive` — correctly** |

VA rules out hard-coding to the ticket's own magnitude. VB confirms both fixes recurse (a
double-negation is two `e_neg`/two-fold applications for Patch A, one `const_int` recursion for
Patch B) rather than handling exactly one level of nesting. VC confirms `comparison/1`'s
literal-first clause (line 5308, untouched by Patch A, folded-through by Patch B) is exercised, not
only the variable-first clause the ticket's own examples all use. VD generalizes the guard fix past
the specific variable name and magnitude used in the main probes. **VE is the check against
"a check whose pass/fail was misread"**: it is constructed to leave a real one-integer gap
(`score` strictly between `-999` exclusive both ways has no clause), and both patches correctly
still refuse it as not exhaustive — proving neither patch works by suppressing the exhaustiveness
check generally once a negative literal is present; both still compute the real residual and both
detect a genuine gap correctly.

**Checking that ordinary subtraction is unaffected**: `Sub(a, b) -> a - b`, run as `Sub(10, 3)`,
returns `7` under the baseline and under both fresh patch builds, identically — `negate/2` is
reached only by the unary-minus production (`expr_low -> '-' expr_low`), never by binary `-`
(`expr_low -> expr_low '-' expr_low`, a separate production), so Patch A cannot touch subtraction,
and Patch B changes nothing in the parser at all.

**No circularity found.** Both patches generalize correctly beyond every example the ticket itself
gives, both correctly preserve the refusal of a genuinely non-constant comparand (T9/VE), and
neither patch's test suite pass was self-referential — the eunit suite and the four gate scripts
existed before this session touched anything and were not modified to accommodate either patch.

Both scratch worktrees created for this verification pass, and the two used to build and measure
the patches in § 3, were removed with `git worktree remove` before this brief was written; none of
their contents were merged into `/home/user/beam-sharp`.
