# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`

Prepared 2026-10-01 by a scheduled run. **Nothing is resolved.** Probes and patches are under
`artifacts/probes/57/`. `bsc` built from HEAD `0dddf8b` under OTP 27.3.4; the prototypes are patches
applied to a scratch copy, never to the tree.

## What the ticket gets right and what it misses

Reproduced at HEAD (`p1_repro_at_head.sh`): `int where value >= -5` is refused with
`opaque_refinement`, and so are `!= -1`, `== -1`, `-5 <= value` and `-(5)`, and so is `value >= 2 + 3`.
`<= 3 or >= 10` and `!= 0` are accepted, as the ticket's table says. **The mechanism text is stale:**
unary minus no longer lowers to `0 - e`; since F51 it is an `e_neg` node (`bs_parser.yrl:589`,
`negate/2` at `:944`). Same symptom, different node.

**The ticket frames the choice as grammar vs checker. The code says the choice is wider, and two
facts it did not know change it:**

1. **Guards share the gap.** `alternatives/1` and `comparison/1` (`bs_check.erl:4923`, `:4941`) serve
   refinements *and* clause guards. A guard with `-5` is read as `unknown` and credits no coverage, so
   an exhaustive function is refused (`p2_guards_share_the_gap.sh`):
   ```
   public atom F(int n)
   F(n) when n >= -5 -> :a
   F(n) when n < -5  -> :b          // error: F is not exhaustive      (HEAD)
   F(n) when n >= 5 -> :a ; F(n) when n < 5 -> :b      // accepted: the control with a non-negative literal
   F(>= -5) -> :a ; F(< -5) -> :b                      // accepted: the pattern form
   ```
   So the defect is not "refinement only", and a fix scoped to refinements leaves the guard half.
2. **The "grammar" fix already has an in-tree precedent that is not narrowing.** `negate/2` already
   folds a negated *float* literal to a literal (`bs_parser.yrl:944`). Folding an *int* literal there
   is one line and changes no grammar rule.

## Sub-decisions

1. Where does a negated literal become a constant: at parse (`negate/2`), in the checker's
   `comparison/1`, or in a general constant folder?
2. Does the fold stop at `-5`, or reach `2 + 3`?
3. Do refinements and guards stay one reader (they are one function today)?

## Neighbour survey

- **Erlang**: the parser keeps `-5` as `{op,1,'-',{integer,1,5}}` in a guard *and* in a pattern
  (measured, `p5`); folding happens later: `erl_parse.yrl:1799 normalise({op,_,'-',{integer,_,I}}) -> -I`
  for term conversion only (it is `normalise/1`, not a folder); the real support for "Erlang folds after parsing" is that the compiler folds general constants (`erlc -S` of `X >= 2 + 3` emits
  `{test,is_ge,...,[{x,0},{integer,5}]}`). So Erlang folds **after** parsing, generally.
- **Elixir** (1.14): `quote do: x >= -5` is `{:-, _, [5]}`, a unary-op node; `-5` and `2 + 3`
  both work as guard comparands (measured). Folding is a later pass. Sources not installed: behaviour only.
- **Gleam** (1.18.1): `case x { -5 -> ..; n if n >= -5 -> ..; n if n >= 2 + 3 -> .. }` compiles
  (measured). No refinement or exhaustiveness-over-int analogue, so only the literal handling transfers.
- **Elm**: not measured (cannot build a project offline).

## Prototypes (`p3_prototype_variants.sh`, patches beside it)

Each patch was applied to a fresh copy and the **same unchanged** probe scripts p1 and p2 re-run.

| variant | change | refinement table | `2 + 3` | guard G1 |
|---|---|---|---|---|
| A. parse-time: `negate(_, {e_int,IL,I}) -> {e_int,IL,-I}` | **1 line**, `bs_parser.yrl` | all accepted | refused | **accepted** |
| B. checker: `comparison/1` reads `{e_neg,_,{e_int,_,K}}` | **2 lines**, `bs_check.erl` | all accepted | refused | **accepted** |
| C. checker: a `const_int/1` folder (`+ - *`, unary `-`) | **22 lines** | all accepted | **accepted** | accepted |

Meaning, not just acceptance (`p4`): under A and B, `type Delta = int where value >= -5 and value <= 5`
accepts `-5, 0, 5` and the exported boundary rejects `-6` and `6` with `function_clause`.
Full `rebar3 eunit` for A and for B: **1299 passed, 4 failed**, the same four that fail on an
unpatched HEAD checkout in this sandbox (baseline: 1298 passed, 5 failed, the fifth, `diagnostic_term_tests:the_diagnostics_gate_passes_test`, fails only because `check-diagnostics.sh` needs a built `bsc` that the eunit-only archive copy lacked, so that baseline comparison was slightly asymmetric). **No regression attributable to
either patch.** The four are `every_aoc_program_still_compiles`, `batch_runs_every_entry_in_one_vm_and_attributes_each`, `a_path_is_utf8_on_the_wire` and `a_non_ascii_literal_is_advised_as_written`; the verifier traced them: `every_aoc_program_still_compiles` needs `../aoc`, which a `compiler/`-only copy lacks, and the other three read UTF-8 test literals as latin1 under the POSIX locale (environmental, not caused by either patch).

## Options

**A. Fold an int literal in `negate/2`.** `-5` is an `e_int` from the parser on.
Compiler delta: one clause. *Strongest counterargument:* it rewrites the AST for **every** `-<int
literal>` in the language, not only comparands, so any later pass that wants to tell `-5` from a
negated expression loses the distinction (none does today: the suite is baseline-equal), and it
differs from Erlang and Elixir, which keep the unary node and fold later (Gleam, like A, produces a literal and leaves `2 + 3` unfolded).

**B. The checker reads a negated int literal.** Compiler delta: two `comparison/1` clauses.
*Strongest counterargument:* the fold lives in one consumer; a second reader of expressions that wants
constants (a future `Take(n)` bound, a `ToJson` width) must rediscover it.

**C. A general constant folder in the checker.** Compiler delta: ~22 lines, admits `2 + 3` and
`-(2*3)`. *Strongest counterargument:* the ticket's own question, "where does it stop", becomes a
standing design surface (`value >= 10 / 2`? division by zero? overflow semantics?) for a
spelling nobody has asked for; CLAUDE.md's rule is one occurrence gets a sentence, not a feature.

## A and B are not equivalent at call sites (verifier finding, reproduced)

With `type Neg = int where value <= -1`, a call `Take(-3)` is **accepted under A** (the parser makes
`-3` an `e_int`, which types as a singleton) and **refused under B and C** (B's `type_of(e_neg ..)`
returns plain `int`). `- -5` is accepted by A and refused by B; `-(2+3)` only by C. So B repairs the
declaration (refinement, guard) but not the *use* of a negative literal where a signed refinement is
expected, which is the program the refinement exists to serve. Earlier briefs on this ticket found the
same (`Half(-5)`, `Id(-50)`). The verifier also found an unrelated HEAD bug: `value >= 5 and
value <= 8 or value == 100` fails with "bad range type" when an exported function uses the type.

## Recommendation

**Option A** (fold the int literal in `negate/2`). I first preferred B; the call-site finding reverses
that. A is one line, fixes refinements, guards *and* literal arguments, mirrors the float fold already
in `negate/2`, and Gleam does the same. Its cost is the AST-wide effect named above (earlier briefs
measured that a bare `-1 = x` line may newly parse as a literal pattern; I did not). C is the follow-up
only if `2 + 3` ever appears in a real program; B alone is not enough. Either way the ticket should be
re-titled (it is not refinement-only) and `F2`'s all-non-negative scenarios should gain a negative one
*and a guard one*.

## Caveats

- OTP 27 here, repo baseline OTP 28. The four baseline failures are environmental and unexplained.
- Gleam/Elixir cited by behaviour (no installed sources); Elm not measured.
- Variant patches are prototypes: no B# test was added, per the task's "do not implement".

## Verification

An independent verifier (`artifacts/probes/57/verify/REPORT.md`) rebuilt all three variants from `git archive HEAD` + the patches (p3 output identical), reproduced p1, p2, p4, p5, the full eunit counts (A and B: 1299 passed / 4 failed, same set) and the Erlang/Elixir/Gleam claims, and found no probe-specific text. It noted that p2 has no over-acceptance control (its own gap probes show A, B and C all refuse the gap cases correctly) and that a green suite says nothing about negative refinements because no test pins them. The call-site finding and the changed recommendation are its.
