# ENG-239 / ticket 57 — a refinement cannot say `-5`: where does the fold belong?

Status of this brief: **decision left open.** Nothing here claims or resolves the ticket.

**Read the Evidence limits first.** `bsc` could not be built or run in this session (OTP 25 here; the repo pins 28.5 and uses `~kp` and leex's `error_location`). Every statement about `bsc` below is *cited from source, not executed*. Statements about Erlang and Elixir were executed (probes in `artifacts/probes/ENG-239/`). Elm and Gleam were not surveyed (see limits).

## What the ticket got stale (found by reading the source, not by running it)

The ticket's mechanism says `-5` "desugars to a subtraction" `{e_op,'-',{e_int,0},…}`. Since F51 that is no longer true: `bs_parser.yrl:587-591` makes unary minus its own node, and `negate/2` (`bs_parser.yrl:947-948`) is

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(L, E)                 -> {e_neg, L, E}.
```

So a negated **float** literal is already folded in the grammar; a negated **int** literal is not, and reaches the checker as `{e_neg, L, {e_int,…}}`. `comparison/1` (`bs_check.erl:5154-5155`) only matches `{e_int,_,K}` on the comparand, so it falls to `unknown`, and `refine/3` (`bs_check.erl:1983-1985`) turns that into `opaque_refinement`. The refusal is still real; the cause the ticket names is not. *Not re-executed: the ticket's own table and `prototypes/38b_divisor_expressiveness.sh` are recorded evidence.*

**Second finding the ticket did not raise: guards are in the same hole.** `apply_guard/3` (`bs_check.erl:5119-5131`) calls the same `alternatives/1`. By the source, `Classify((:ok, n)) when n <= -1 -> …` is a guard the checker cannot read, so it credits no coverage (`unknown -> {none, Ty}`). `LANGUAGE.md:465` prints that line as a residual to paste in, but ticket 42 (`42-interval-pattern-spelling.md:250,316`) says an interval residual now synthesises as a pattern (`Classify(<= -1)`), so that doc line may be a stale illustration; the guard hole itself follows from source only. **Unverified by execution** — a `bsc` run of a hand-written `when n <= -1` clause is the first thing the verifier should do.

## Sub-decisions

1. Where does the int-literal fold live?
2. How far does it go?
3. What does the diagnostic say afterwards?

(Whether patterns and refinements share one literal rule is folded into 1: it is the difference between its options. The fix must also cover guards because `alternatives/1` is shared — that is a requirement, not a choice.)

## 1. Where does the fold live?

The three programs below are what each answer accepts. They are **predicted from the source, not compiled**.

```csharp
type Delta = int where value >= -100 and value <= 100

Step(Delta d) -> d
Sign(<= -1)   -> :neg            // already compiles (int_lit, bs_parser.yrl:471-472)
Sign(n) when n >= -5 -> :near    // unreadable today: same alternatives/1
```

**Option A — fold at construction in the parser.** Add one clause beside the float one:

```erlang
negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};   % bs_parser.yrl, before the catch-all
```

Compiler delta: that clause; nothing in `bs_check.erl`. `-5` is an `e_int` everywhere, so `refine/3`, `apply_guard/3`, `comparison/1` need no change. Side effect to measure before choosing: `type_of({e_neg,…})` returns bare `int()` (`bs_check.erl:2963-2974`) while `type_of({e_int,_,N})` returns `range(N,N)` (`bs_check.erl:2956`). Folding would make every expression `-5` the literal type `-5` instead of `int`. Probably an improvement; it is also a behaviour change outside this ticket. `bs_emit.erl:1067` emits `{op,L,'-',…}` for `e_neg`; it would emit `{integer,L,-5}`. F48 (AST as a value) lists `e_neg`; its surface would change. None of this was run.

**Option B — fold in the checker.** One helper used by `comparison/1`:

```erlang
const_int({e_int, _, N})  -> {ok, N};
const_int({e_neg, _, E})  -> case const_int(E) of {ok, N} -> {ok, -N}; E2 -> E2 end;
const_int(_)              -> error.
```

`comparison/1` calls it for the comparand in both argument orders (the two clauses at `bs_check.erl:5154-5155`). The grammar, `type_of`, the emitter and F48 do not move. Expression `-5` keeps typing as `int`.

**Option C — the ticket's "grammar" option: a narrow `refinement` nonterminal** (`refinement -> value rel int_lit`). Compiler delta: replace `refinement -> expr_low` (`bs_parser.yrl:221`). It makes the two sites agree by construction, but it deletes the F2.5 property stated in the grammar comment at `bs_parser.yrl:219-221` ("a refinement and a guard cannot disagree about what `value >= 0` means"), because guards stay `expr`. Not recommended; included because the ticket asked for it.

### Evidence from the neighbours (executed)

- **Erlang's parser builds the same unary node in every position.** `probes/p1.out`: `f(X) when X >= -5`, `f(-5)` (pattern) and `X + -5` all produce `{op,'-',{integer,5}}`; `0-5` and `2+3` stay binary nodes. `erl_parse.yrl:270` (`pat_expr -> prefix_op pat_expr`) is the pattern rule — Erlang has no separate `int_lit` rule for a pattern, which is what B# has at `bs_parser.yrl:471-472`.
- **Erlang folds late, in two different places, and does not fold in the AST stages.** `probes/p2.out`: `+to_pp` and `+dexp` still show `{op,_,'-',{integer,_,5}}`, `'+'`, `'bsl'`. `+dcore` keeps calls but `+to_core` shows `>= -5`, `>= -5`, `>= 5`, `>= 8`, `>= -5` for the five guards (`-5`, `0-5`, `2+3`, `1 bsl 3`, `(2+3)*-1`). Final asm (`erlc -S`): `{test,is_ge,…,[{x,0},{integer,-5}]}`. The Core fold is `sys_core_fold.erl:866-878` (`fold_call_2`/`fold_lit_args`: "all arguments are literals" → evaluate). **Correction after verification:** `+to_kernel` is *after* the Core fold and does show the folded literals (`(_0, -5)`, `(_0, 5)`, `(_0, 8)`); the first version of `p2.out` printed a stale `fold.expand` file for that stage because the probe's cleanup omitted it. Fixed in `p2_fold_stage.sh` and `p2.out` regenerated.
- **Erlang's pattern check is a checking stage, not the parser.** `erl_lint.erl:1880-1892`: a pattern expression is valid iff `erl_eval:partial_eval/1` returns a literal. `probes/p6.out`: `p(2+3)` and `p(-(1 bsl 2))` compile and dispatch (`5→a`, `-4→b`); `p(X, 2+X)` is refused `illegal_pattern`; a guard `N >= 2+3` compiles. So Erlang's answer to this ticket is Option B's shape (checker-side evaluation of constant arithmetic), and it goes well past `-5`.
- **Elixir folds a negative integer in a pattern, and nowhere else.** `probes/p7.out` (added after the verifier found p3 never printed the pattern position): pattern `def p(-5)` is `{:integer,4,-5}`; guard `x >= -5` and body `-5` keep `{:op,_,:-,{:integer,_,5}}`; an injected literal `unquote(-5)` in a guard is `{:integer,3,-5}`. That is the same pattern-versus-guard split this ticket is about, so the neighbours do not uniformly "keep one node". Earlier p3 findings: `probes/p3.out`: `Code.string_to_quoted!("x >= -5")` is `{:-, _, [5]}`; the Erlang abstract code Elixir leaves in the BEAM for `def a(x) when x >= -5` is `{:op, 2, :-, {:integer, 2, 5}}` and for `x >= 2 + 3` is `{:op, 3, :+, …}` — Elixir hands folding to `erlc`. Compiled and called: `pat(-5)`, `x >= -5 and x <= 5`, `x in -5..5`, and a `defguard is_delta` over `-100..100` all behave correctly. `Macro.expand(quote(do: -5), __ENV__)` returns the integer `-5`, as do `-(5)` and `+5`; `-5.0`, `-x`, `0 - 5` and `2 + 3` stay as nodes (`p7.out`) — an integer-only unary fold in `Macro.expand` that the compiled guard/body forms do not use (mechanism inferred; Elixir's `.ex` sources are not installed).
- **Elm: not surveyed.** `probes/p4.out`: `elm make` needs `https://package.elm-lang.org/all-packages` and the proxy answers `403 Forbidden`; no workaround attempted. The Elm program `probes/elm/src/Main.elm` (negative literal in a `case` pattern and in an expression) was never compiled.
- **Gleam: not surveyed.** Not installed, no installable package; fetching a release binary was denied by the session's classifier, and I did not retry.

### Cost (approximate; NOT bsc)

`probes/p5.out` parses 10,000 `when X >= -N` clauses with `erl_parse` and then runs a generic constant-fold pass written for the probe over all forms (compiled code, 7 runs): parse median ≈ 61–64 ms, fold median ≈ 9 ms, 10,000 unary nodes before and 0 after. So a *whole-tree* checker fold is ≈ 15% of parse time on this synthetic input, an upper bound for B, which folds only comparands. An earlier run of the same probe under escript's default interpreter showed fold slower than parse; that was my methodology error (interpreted vs compiled), and the probe now carries `-mode(compile)`. Cost of A is zero at check time and not measured at all.

### Strongest counterargument to each

- **Against B:** two literal rules now exist (`int_lit` for patterns, `const_int/1` for comparands) and nothing but a test makes them agree; `-5` as an expression still types as `int`, so the language keeps one place where `-5` is a literal (a pattern) and another where it is an expression. A closes both with one clause and the float precedent already sits one line above.
- **Against A:** it changes the typing of every expression `-5` (`int` → `-5`) and the emitted/AST form, which this ticket's evidence cannot price. A decision about refinements would ship a change to expression typing that nobody asked a question about. (CLAUDE.md: a feature that needs a decision raises a ticket.)
- **Against C:** it splits refinement from guard, the exact divergence the grammar comment says the design avoids.

### Recommendation

**B**, with a gate that makes the two literal rules agree: for N in a range, `Sign(<= -N)` and `type T = int where value <= -N` and `when n <= -N` must denote the same interval (needs a `--self-test` that builds a mismatch and sees it red). Then raise a **separate ticket** for A's typing question (`-5` as `int` vs literal `-5`), since it is observable and unpriced. Reason, from the evidence: both Erlang and Elixir keep one unary node through parsing and decide in a later stage; B is the same shape, local to `alternatives/1`, and does not move expression typing. This reading agrees with the ticket's own lean ("the second looks right"), so the ticket's "should not guess" caution applies to my agreement too.

## 2. How far does the fold go?

```csharp
type A = int where value >= -5                 // every option: accepted
type B = int where value >= 2 + 3              // accepted only if sums fold
type C = int where value >= -(2 + 3)           // accepted only if both fold
type D = int where value >= limit              // refused under every option: not a constant
type E = int where value >= 7 / 2              // see below
```

- **Option 1 — `-` over an int literal only.** Delta: the `e_neg` clause of `const_int/1`. `B`, `C`, `E` stay refused with the (revised) diagnostic.
- **Option 2 — also `+`, `-`, `*` of folded integers.** Delta: three more `const_int/1` clauses over `{e_op,_,Op,L,R}`. Erlang's behaviour (`probes/p6.out`: `N >= 2+3` and `p(2+3)` both work) is the precedent.
- **Option 3 — named constants (`value >= limit`).** B# has no constant declaration (`grep -n -i "constant" LANGUAGE.md` finds none); this needs a new construct and its own ticket. Listed only so it is explicitly out.

`/`, `%`/`rem` are excluded from option 2 because ticket 38 (division and modulo) fixed their semantics and its §2 answer is the reason this ticket blocks nothing; a refinement that evaluates `7 / 2` would need to restate those rules.

**Evidence:** Erlang folds `+ - * bsl` (`probes/p2.out`); the folded set is wider than anything a B# refinement needs. **Prior decisions this must not contradict (grepped):** ticket 63's entry (no `not`) rests on `alternatives/1` being a fragment "closed by construction" under complement. With a constant on the right, `x >= K` complements to `x <= K-1` for any integer K, so option 1 and 2 both stay closed; option 3 would not be closed (a non-constant comparand falls out of the fragment). Ticket 63's cited lines (`bs_check.erl:2659-2693`) have drifted; `alternatives/1` is now at `bs_check.erl:5136`. Ticket 63 concerns boolean negation, not arithmetic minus; no conflict found. Ticket 38's note says 57 does not block it.

**Strongest counterargument to option 2:** every extra operator is a second place `value >= 2 + 3` can be mis-evaluated (overflow is not an issue for bignums, but `*` of two literals changes the interval bound silently), and nobody has written a refinement that needs it. Option 1 is the smallest thing that unblocks the signed domains the ticket names (`Delta`, a balance, a temperature).

**Recommendation: option 1.** Revisit option 2 when a program needs it; the fold is one clause per operator.

## 3. What does the diagnostic say?

Current text (`bs_diag.erl:2019-2027`): "comparisons on `value`, joined with `and`/`or`. `int where value >= 0 and value <= 255` is one." The ticket's complaint — the message recommends the form it refused — disappears once `-5` reads, but the next unreadable case (`value >= limit`, `value >= 7 / 2`) gets the same text.

- **Option 1 — leave it.** Cost: zero. Wrong for a comparand that is not an integer literal.
- **Option 2 — add one line** naming the rule: "the other side of the comparison must be an integer literal (a leading `-` is fine)." Delta: one string in `bs_diag:message/1`, plus the gate that pins the message text (grep for the gate that reads it before editing).

**Strongest counterargument to option 2:** the message is pinned by tests and by the tour; changing it moves the docs gates. **Recommendation: option 2**, landed with the fix so the message is true the day it ships.

## Evidence limits (what is not verified)

1. **`bsc` was never run.** No claim about what `bsc` accepts or prints is executed here, including the ticket's table, my claim that guards `when n >= -5` are also unreadable, and the typing difference between `e_neg` and `e_int` (`bs_check.erl:2956,2963`). The B# programs in this brief are predictions.
2. **OTP 25, not 28.5.** Erlang findings come from OTP 25 sources (`stdlib-4.3.1.3`, `compiler-8.2.6.3`); the fold sites may have moved in 28. Elixir is 1.14 on OTP 25; the `Macro.expand` behaviour is observed (p7) but its mechanism is inferred.
3. **Elm and Gleam are not surveyed**; the Elm program exists but did not compile because the registry is unreachable.
4. **Elixir source is not installed** (only `ebin`), so there is no Elixir file:line citation; Elixir claims rest on executed output only.
5. **The p5 cost figure is a proxy** (`erl_parse` plus a generic fold I wrote), not `bs_parser.yrl`/`bs_check.erl`. Run-to-run noise is large (parse min 36–38 ms vs median 61–64 ms).
6. **Verifier note for circularity:** every probe was written before its output was read, and the only edit made after seeing output was the `-mode(compile)` fix to p5 (disclosed above) plus a cosmetic edit to p3 that removed a digit-stripping regex I had added to shorten output. Neither changes a conclusion. **Verifier addendum:** an independent verifier re-ran all probes; it found p2's kernel rows were stale-file output (fixed above) and p3's pattern position missing (p7). p5 has no no-op-walk baseline, and `after=0` is the probe checking itself. p4 (Elm) could not succeed offline (`~/.elm` holds no `elm/core`), so Elm is not surveyed.

Reproduce: `artifacts/probes/ENG-239/run-all.sh` (re-runs p1–p6, diffs against the recorded `.out`; p5 timings are printed, not diffed).
