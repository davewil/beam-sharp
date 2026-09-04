# Decision brief: A refinement cannot say `-5`, though a pattern can (ticket #57, ENG-239)

## Sub-decisions

The ticket names one question but it splits into three once probed:

1. **Where does the fix belong** — the grammar (mirror `int_lit`'s `'-' integer` production for
   the refinement's comparand) or the checker (constant-fold the unary-minus-over-literal node
   `alternatives`/`comparison` already receives)? This is the ticket's own named question.
2. **How far does a checker-side fold generalize** — negation of a literal only, or arbitrary
   closed-form arithmetic (`2 + 3`, `1 bsl 4`)? The ticket raises this as an open cost of Option B
   without resolving it ("`-5` certainly, `2 + 3` probably, `value >= n` never").
3. **(New, found during verification, not in the ticket text) Does the same defect reach guards,
   not just refinements?** `refine/3` and `apply_guard/2` both call `alternatives/1` →
   `comparison/1`. If so, a fix scoped to the refinement's own grammar (Option A, narrowly read)
   cannot reach it, which bears directly on sub-decision 1.

## Evidence

### Sub-decision 3 first, because it reorders the other two: the bug is not refinement-only

- Probe: `artifacts/57-probes/neg_guard_exhaustive.bs` vs
  `artifacts/57-probes/pos_guard_exhaustive.bs` — claim: "a guard with a negative-literal
  boundary hits the same `comparison/1` blind spot as a refinement, and — because a guard the
  checker can't read simply *credits nothing* rather than erroring loudly — the visible symptom
  is a false `not exhaustive`, not `opaque_refinement`."
  Command: `bsc /tmp/NegGuardExhaustive/a.bs` vs `bsc /tmp/PosGuardExhaustive/a.bs` (identical
  two-clause shape, only the boundary differs: `-5`/`>= -5`/`< -5` vs `5`/`>= 5`/`< 5`)
  Output:
  ```
  ######## negative boundary ########
  /tmp/NegGuardExhaustive/a.bs:13: error: Classify is not exhaustive
    no clause matches:
      Classify(n) -> ...
  exit=1

  ######## positive boundary (control) ########
  exit=0
  ```
  Re-verified from a clean `rebar3 escriptize` rebuild, with the boundary changed to `-3`/`>= -3`
  and the clause order swapped (`artifacts/57-probes/run_all.output`, plus an ad-hoc rerun not
  saved as a file — `/tmp/OrderSwap/a.bs`, same result) to rule out clause order or the specific
  value `-5` as confounds. Both `-3` variants fail the same way; a `3`-boundary control compiles.
  **This means a fix confined to the refinement's own grammar production (a literal `int_lit`-style
  rule used only where `refinement -> ...` is parsed) leaves this guard defect standing untouched**
  — guards have no analogous "refinement" nonterminal to special-case; `when n >= -5` is ordinary
  `expr` in `when` position, by the same design choice (`bs_check.erl:1299-1303`) that makes a
  refinement `expr`-typed in the first place.

- Source: `compiler/src/bs_check.erl:1317-1337` (`refine/3`) and `:3442-3465` (`apply_guard/2`)
  both dispatch to `alternatives/1` (`:3471-3488`), which bottoms out in `comparison/1`
  (`:3490-3497`):
  ```erlang
  comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
  comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
  ...
  comparison(_) -> unknown.
  ```
  Both clauses require the non-`e_var` side to already be a bare `{e_int, _, K}` node. `value >=
  -5` parses (per `bs_parser.yrl:595`, `expr -> '-' expr : {e_op, line, '-', {e_int, line, 0},
  '$2'}`) to `{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}` — the right side is an
  `e_op` node, not an `e_int`, so `comparison/1` falls through to `unknown` for *both* callers.
  `refine/3` turns `unknown` into a hard `opaque_refinement` error (`:1319`); `apply_guard/2` turns
  it into "credits nothing" (`:3449-3458`), silently subtracting nothing from the residual — which
  is what produces the false non-exhaustive verdict rather than a diagnostic naming the guard.

### Sub-decision 1: grammar vs. checker

- Probe: `artifacts/57-probes/neg_refinement.bs` / `neg_pattern.bs` — claim: "the ticket's own
  repro reproduces verbatim on the current tree; line numbers in the ticket's citation of
  `bs_parser.yrl` and `bs_check.erl` still match."
  Command: `bsc /tmp/NegRefinement/a.bs` ; `bsc /tmp/NegPattern/a.bs`
  Output:
  ```
  /tmp/NegRefinement/a.bs:3: error: this refinement is not a predicate the checker can read
    a refinement narrows a type, so the compiler has to be able to
    reason about it: comparisons on `value`, joined with `and`/`or`.
    ...
  exit=1

  (NegPattern: Sign(<= -1) -> :neg  compiles clean)
  exit=0
  ```
  Grammar line numbers independently confirmed by grep against the live `bs_parser.yrl`:
  `int_lit -> integer : value('$1').` / `int_lit -> '-' integer : -value('$2').` at lines 472-473
  (ticket cites the same); `expr -> '-' expr : {e_op, ...}` at line 595 (ticket cites the same).
  Also re-ran the ticket's own probe unmodified — `wayfinder/prototypes/38b_divisor_expressiveness.sh`
  — all 7 of its assertions passed against the current tree (`artifacts/57-probes/run_all.output`).

- Survey — **Erlang** (`/usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_parse.yrl:147,240,270,519-522`):
  **no dedicated negative-literal production anywhere** — `type`, `expr`, and `pat_expr` all reach
  a negative number through the *same* generic `prefix_op -> '-'` rule (`?mkop1`). Confirmed by
  parsing `X >= -5` for real:
  ```
  Parsed form for `f(X) when X >= -5 -> ok.`:
    {function,1,f,1,[{clause,1,[{var,1,'X'}],
       [[{op,1,'>=',{var,1,'X'},{op,1,'-',{integer,1,5}}}]],
       [{atom,1,ok}]}]}
  ```
  (`artifacts/57-probes/erlang_guard.erl`, run via `erl`). The literal `-5` is `{op,'-',{integer,
  5}}` in a *guard* exactly as in beam-sharp's refinement — Erlang's own grammar has the identical
  "shape" beam-sharp is being asked to special-case. Type spec confirms this is deliberate:
  `af_integer() :: {'integer', anno(), non_neg_integer()}` (`erl_parse.erl:943`) — an Erlang
  integer literal AST node is *by type* never negative.
  Where the split actually happens: `v3_core.erl:2056-2059` (`compiler-8.2.6.3`), in the **pattern
  compiler**, not the grammar:
  ```erlang
  pattern({op,_Line,_Op,_A}=Op, St) -> pattern(erl_eval:partial_eval(Op), St);
  pattern({op,_Line,_Op,_L,_R}=Op, St) -> pattern(erl_eval:partial_eval(Op), St).
  ```
  `erl_eval:partial_eval/1` (`erl_eval.erl:1608-1627`) evaluates a closed-form operator tree
  (`ev_expr`, which has no clause for `{var,...}` and so throws — caught — leaving the node
  unfolded whenever it touches a variable) and replaces it with a literal when it succeeds. This
  is genuinely general, not limited to negation. Verified directly, in pattern position (not
  guard):
  ```
  f(-5)     = neg_five
  f(5)      = two_plus_three   % pattern `2 + 3` folded to literal 5
  f(16)     = shift            % pattern `1 bsl 4` folded to literal 16
  f(0)      = other
  ```
  (`artifacts/57-probes/erlang_pattern_fold.erl`). And the boundary is exactly "closed terms
  only": `f(Y, Y + 1) -> ok.` is refused — `illegal pattern` — because `Y` keeps the node open
  (`/tmp/erlang_var_in_pattern.erl`, re-verified independently as a fresh adversarial probe, not
  a rerun of an existing script). **This is independently corroborated inside beam-sharp's own
  decisions**: `wayfinder/decisions.md:165` and `:1594` already record "`erlc` constant-folds …
  only when *both* operands are literals" (found while researching tickets 10 and 38,
  respectively) — the same boundary, reached from a different angle, before this ticket existed.
  A *guard* needs no such fold in Erlang at all — `classify(X) when X >= -5 -> hi` **works
  correctly at runtime** without any literal-folding, because a guard compiles to code that
  executes `-/1` as a real (guard-safe) BIF call at call time; Erlang has no static
  exhaustiveness/interval algebra reading the guard the way beam-sharp's checker does, so it never
  needed to solve beam-sharp's actual problem.

- Survey — **Elixir 1.14.0**: same absence of a grammar-level literal at *parse* time —
  `elixir_parser.yrl:755-756` (`build_unary_op`) produces `{Op, meta, [Expr]}` uniformly for `-5`
  and `-x` alike; `elixir_tokenizer.erl` has no distinct negative-number token (`Token::Minus` is
  always its own token). Yet **pattern position accepts `-5` and refuses `2 + 3`**, proving a
  fold/allowance exists somewhere past parsing that is *narrower* than Erlang's:
  ```
  sign(-5): :neg_five        # accepted
  ** (CompileError) ...: cannot invoke remote function :erlang.+/2 inside a match   # refused
  ```
  (`artifacts/57-probes/elixir_guard.exs`, `elixir_pattern_arith.exs`). Whitespace between `-` and
  the digit does not change this (`- 5` and `-5` both accepted as patterns —
  `elixir_pattern_space.exs`/`elixir_pattern_space2.exs`), so it is not a tokenizer-adjacency
  trick either; some later pass narrowly special-cases "unary `+`/`-` over a numeric literal" and
  nothing wider. **The exact pass was not pinned down within scope** (grepped
  `elixir_expand.erl`, `elixir_erl_pass.erl`, `elixir_erl_clauses.erl` at the matching tag without
  finding the specific clause) — reported as behavior confirmed by direct execution, mechanism
  not fully traced; flagged rather than guessed at. Guards independently confirmed to allow real
  binary arithmetic over two *bound variables*, not just literals — `x - y >= 0` compiles and
  runs correctly (`classify2/2` in `elixir_guard.exs`) — because Elixir's guard BIF whitelist
  includes arithmetic operators as executable BIFs, the same reason Erlang's guard needs no fold.

- Survey — **Gleam 1.9.1**: the only one of the four with a **genuine lexer-level negative-number
  production**, contextually disambiguated from subtraction by lookback on the *preceding* token —
  `compiler-core/src/parse/lexer.rs:900-906`:
  ```rust
  fn is_number_start(&self, c: char, c1: Option<char>) -> bool {
      match c {
          '0'..='9' => true,
          '-' => matches!(c1, Some('0'..='9')),
          _ => false,
      }
  }
  ```
  paired with `consume_normal` (`:146-169`), which *forces* a bare `Token::Minus` (blocking the
  number lexer from claiming the `-`) whenever the previous token was a name or number — so `x-1`
  lexes as `x`, `-`, `1` (subtraction) while `>= -5` or `(-5` lexes `-5` as one `Token::Int`
  token. Verified: both a guard and a pattern using the identical literal compile clean, and the
  compiler's own generated Erlang shows the guard rendered with a plain literal (`X >= -5.0`),
  consistent with the guard side never having gone through a `NegateInt`-then-fold step at all —
  it was never anything but a literal:
  ```
  case X of
      _ when X >= -5.0 -> ...
  sign(N) -> case N of
      -1 -> "neg_one"; ...
  ```
  (`artifacts/57-probes/gleam_probe.gleam` → `gleam_probe_generated.erl`, `gleam build`). Because
  the literal is resolved before the parser ever distinguishes "this is a guard" from "this is a
  pattern," **Gleam's grammar has no expr/pattern split to disagree across in the first place** —
  the exact tension the ticket names ("a refinement is deliberately an `expr` so that it and a
  guard cannot come to disagree") is dissolved by construction, at the cost of a lexer-level
  lookback rule.

- Survey — **Elm 0.19.1/0.19.2**: **could not be executed** — `elm init`/`elm make` need
  `package.elm-lang.org`, which this environment's egress policy blocks (`curl` to it returns a
  403 from the proxy; confirmed, not assumed). Reported from real compiler source only, at the
  matching git tag (Elm's compiler repo has no `0.19.2` tag; `0.19.1` is the last language-level
  release and the one fetched). **This overturns the premise handed to me for this survey** ("Elm
  patterns DO allow negative integer/float literals, e.g. `case n of -1 -> ...`") — the compiler's
  own diagnostic says otherwise, `compiler/src/Reporting/Error/Syntax.hs:4776-4790`:
  ```haskell
  Code.Operator "-" ->
    ...
    Report.Report "UNEXPECTED SYMBOL" region [] $ ...
      ( D.reflow "I ran into a minus sign unexpectedly in this pattern:"
      , D.reflow "It is not possible to pattern match on negative numbers at this \
                  \time. Try using an `if` expression for that sort of thing for now."
      )
  ```
  `compiler/src/Parse/Pattern.hs` has no `Minus`/negate handling in `term`/`termHelp` at all (only
  `record`/`tuple`/`list`/wildcard/var/ctor/number/string/char), and `Parse.Number.number`
  (`Parse/Number.hs:49-58`) requires the *first* character to already be a decimal digit — so a
  leading `-` in pattern position is never consumed as part of a number and instead falls through
  to the dedicated `Code.Operator "-"` error case above. On the expression side,
  `Parse/Expression.hs:336-343` (`possiblyNegativeTerm`) parses `-expr` into an ordinary
  `Src.Negate expr` AST node — the same shape as beam-sharp's `expr -> '-' expr` desugar, not a
  literal. **Elm's answer to the tension is neither "fold" nor "give patterns their own literal
  rule" — it is to refuse the pattern-side construct entirely** and push the negative case to a
  general `if`/`else`, sidestepping the disagreement rather than resolving it. This is *sourced,
  not executed*, and is reported with that caveat; it is however about as strong as
  non-executed evidence gets — a diagnostic message written specifically for this exact
  input shape, not an inference from adjacent code.
  **Correction for the record**: my task instructions asserted Elm patterns allow this; the
  verification step below re-checked this specifically and the source is unambiguous enough that
  I am reporting the correction rather than the original premise.

### Sub-decision 2: how far a checker-side fold should generalize

- Already answered by the Erlang/Elixir contrast above, without needing new probes: Erlang folds
  *any* closed-form arithmetic (`2+3`, `1 bsl 4`, presumably nested combinations); Elixir folds
  only unary `+`/`-` over a bare numeric literal and refuses everything else, even in the same
  (pattern) position. Both are self-consistent, shipped, production designs. beam-sharp's own
  ticket 38 finding (`decisions.md:1594`, independent of this ticket) already treats "folds only
  when both operands are literals" as the expected shape of a constant-fold in this codebase, and
  the concrete shape beam-sharp needs is narrower still — cancelling exactly the parser's own
  `expr -> '-' expr` desugar (`bs_parser.yrl:595`) when its operand is already an `e_int`, i.e.
  `{e_op,'-',{e_int,_,0},{e_int,_,K}} -> {e_int,_,-K}`. `value >= n` is never a candidate under
  this rule since it does not match that shape (n is `e_var`, not `e_int`), which is the same
  "closed term only" boundary Erlang enforces structurally via `ev_expr` having no `{var,...}`
  clause.

## Options

### Option A: fix in the grammar

What it looks like: extend `bs_parser.yrl` so wherever a refinement's comparand is parsed, a
leading `'-' integer` collapses to a negative `int_lit`-shaped literal node at parse time,
mirroring lines 472-473. Concretely this means either (a) narrowing the refinement's comparand
grammar away from bare `expr` to something `int_lit`-aware (which the ticket already flags as
reintroducing the refinement/guard split `bs_check.erl:1299-1303` was written to prevent), or (b)
going further and doing what Gleam does — a lexer-level negative-number token disambiguated by
lookback on the preceding token, shared uniformly by `expr`, patterns, and guards, so there is no
refinement-specific carve-out at all.

- Evidence for: Gleam demonstrates (b) is a real, shipped, coherent design — it dissolves the
  refinement/guard disagreement risk by construction rather than by discipline, because there is
  only one literal production system-wide.
- Strongest counterargument: (b) is the only version of Option A that actually reaches the guard
  bug found in sub-decision 3 — a narrow refinement-only grammar rule (a) does not, since guards
  have no dedicated nonterminal to special-case and are not going to get one (that would recreate
  exactly the three-way fragmentation `bs_check.erl`'s comment warns about: pattern's `int_lit`,
  a new guard literal, and a new refinement literal, all separately). (b) is also the largest,
  riskiest change surveyed: a lexer-level lookback rule touches every place a `-` can appear in
  the whole language, not just refinements, and Gleam's own lexer comment ("We want to lex `1-1`
  and `x-1` as `1 - 1` and `x - 1`") shows this rule carries its own edge cases to get right.

### Option B: fix in the checker (constant-fold)

What it looks like: in `bs_check.erl`, add a narrow fold — recognize
`{e_op, _, '-', {e_int, _, 0}, {e_int, _, K}}` (exactly the shape the parser's own line-595 desugar
produces for a literal negation) and reduce it to `{e_int, _, -K}` before `comparison/1` pattern-
matches on it. The natural place is a small `fold_const/1` called at the top of `comparison/1`
(or inline as two more clauses of `comparison/1` itself), since `comparison/1` is the single
function both `refine/3` and `apply_guard/2` already funnel through.

```csharp
type Delta = int where value >= -100 and value <= 100   // compiles after the fix
Classify(n) when n >= -5 -> :hi                          // exhaustive after the fix, paired
Classify(n) when n < -5  -> :lo                          // with its complement
```

- Evidence for: fixes **both** bugs in sub-decision 3's evidence at once, in the one place the
  codebase's own design comment (`bs_check.erl:1299-1303`) already declares canonical — "the
  refinement and the guard go through one translator." Matches Erlang's own precedent for the
  *structurally* closest case (pattern-position op-trees needing to become concrete values for a
  static consumer downstream — Core Erlang's pattern compiler there, beam-sharp's interval algebra
  here) via `erl_eval:partial_eval`, and matches Elixir's narrower "fold negation of a literal
  only" scope, which is also the scope beam-sharp actually needs (sub-decision 2). Requires no
  grammar change, so patterns, refinements, and guards keep reading `-5` through the exact same
  `expr` grammar they already share — zero new productions, zero new ways for two sites to
  disagree, which is a stronger version of the invariant the existing comment claims than Option A
  achieves even in its lexer-level form (b).
- Strongest counterargument: the ticket's own worry about scope creep is real even at this narrow
  width — the fold has to live somewhere precise enough that it does not quietly start reducing
  other `e_op` shapes nobody asked it to (Erlang's general `partial_eval` is more powerful than
  beam-sharp needs and was not shown to be *necessary* here, only sufficient elsewhere); the
  narrow single-shape version above avoids that by being syntactic rather than evaluative, but
  whoever implements it has to resist widening it opportunistically later without a fresh ticket.

## Recommendation

**Option B**, scoped narrowly (fold exactly the parser's own `'-' literal` desugar shape, not
general constant arithmetic). The deciding evidence is sub-decision 3, which the ticket text does
not mention: the identical `alternatives`/`comparison` codepath silently mis-checks a *guard* with
a negative-literal boundary today (`Classify(n) when n >= -5` / `when n < -5` is wrongly reported
`not exhaustive`), and a refinement-only grammar fix (Option A's narrow form) cannot touch that at
all, while Option B fixes both from one place by construction. Option A's only version that
*would* reach the guard bug — a Gleam-style lexer-level literal shared by every syntactic position
— is also the largest and most invasive change surveyed, touching every `-` in the language for a
defect that is really about one function (`comparison/1`) not reading one AST shape. The survey
across Erlang, Elixir, and Gleam shows three different production languages that all had to answer
this exact question, and none of them chose "give the refinement/guard side its own literal
grammar production": two folded post-parse (Erlang generally, Elixir narrowly — both closer to
Option B), and the one that did put it in the grammar (Gleam) did so as a language-wide lexer rule
covering every position at once, not a refinement-specific carve-out, because a carve-out would
have reintroduced exactly the disagreement risk beam-sharp's own comment already worries about.

## Verification

**No nested-agent-spawning tool (`Task`/`Agent`) or `ListAgents` was available in this session** —
searched via `ToolSearch` for both and found neither, so the common brief's "spawn one verifier
subagent" step could not be carried out as written. In its place I ran the independent-verification
checklist myself, from clean state, rather than skipping it:

- Rebuilt `bsc` from a fully clean `rebar3 escriptize` (deleted `_build` first) and re-ran the
  entire probe suite (`artifacts/57-probes/run_all.sh`) against the fresh binary; diffed the new
  output against the recorded one — identical except a compile-time timestamp
  (`   Compiled in 0.25s` vs `0.26s`, Gleam's own build-time report).
- Checked for circular/self-confirming probes specifically: the guard-exhaustiveness finding
  (sub-decision 3) was re-tested with a *different* boundary value (`-3` instead of `-5`) and
  *swapped* clause order, not just re-run verbatim — both still fail, and a positive-boundary
  control with the same swap still compiles, ruling out clause order or the specific value `-5` as
  the actual cause. The Erlang "folds only closed terms" claim was re-tested adversarially with a
  pattern never mentioned in the drafted evidence (`f(Y, Y + 1) -> ok.`, a variable inside the
  arithmetic) rather than re-reading the already-recorded `partial_eval`/`ev_expr` source — it is
  refused with `illegal pattern`, independently confirming the closed-term boundary rather than
  merely restating what the source claims it does.
- Caught and corrected one claim in my own working notes before it reached the brief: I had
  initially treated my task instructions' assertion that "Elm patterns allow negative literal
  patterns" as true and started probing on that basis; reading Elm's own error-reporting source
  turned up a diagnostic written specifically to refuse exactly that construct
  (`Reporting/Error/Syntax.hs:4776-4790`), which is the opposite claim. This is flagged above as a
  correction rather than folded in silently, and is explicitly marked *sourced, not executed*
  (network to `package.elm-lang.org` is blocked in this environment — confirmed via `curl`, not
  assumed) since I could not run `elm make` to double-check it against real compiler behavior.
- One claim in the draft is explicitly left unresolved rather than asserted past what was checked:
  exactly which Elixir pass allows `-5` but refuses `2 + 3` in pattern position was not located
  within scope (`elixir_expand.erl`, `elixir_erl_pass.erl`, `elixir_erl_clauses.erl` searched at
  the pinned tag without finding the specific clause) — the *behavior* is executed and verified
  twice (including the whitespace-insensitivity check), but the *mechanism* is reported as
  unlocated rather than guessed at.
