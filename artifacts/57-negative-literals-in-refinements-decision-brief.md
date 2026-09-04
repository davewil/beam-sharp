# Decision brief — 57 / ENG-239: negative literals in refinements

Not a resolution. David decides; this is the evidence.

## What's undecided

`type T = int where value >= -5` is refused with `opaque_refinement`, while the structurally
identical `Sign(<= -1) -> :neg` (pattern position, same literal, same operator) compiles. Both
sites should be able to say this. **The one open question is where the fix lives**: in the
grammar (so `-5` in a refinement becomes a literal AST node, the way `int_lit` already makes it
one in pattern position), or in the checker (so the node shape `-5` already produces —
`{e_op,'-',{e_int,0},{e_int,5}}` — is recognised as constant before `alternatives/1` gives up on
it). Nothing else about ticket 57 is open; both root cause and impact are settled in the ticket
text and reconfirmed below.

## What I verified against current HEAD

- `bs_parser.yrl:472-473` (`int_lit`), `:595` (`expr -> '-' expr`), and `:206` (`refinement ->
  expr`) match the ticket's citations exactly — nothing moved since 2026-08-23.
- The "one translator" comment is real and current, `bs_parser.yrl:201-206`: *"The predicate is
  an ordinary expression... and the checker then reads it back with the SAME `alternatives/1` a
  guard goes through. One translator, so a refinement and a guard cannot come to disagree about
  what `value >= 0` means (F2.5)."* `bs_check.erl:1299-1303` restates it even more pointedly:
  *"THE REFINEMENT AND THE GUARD GO THROUGH ONE TRANSLATOR, which is what makes F2.5 true by
  construction rather than by test... because `alternatives/1` is the only thing that reads either
  of them."*
- `bs_check.erl:3490` (current `comparison/1`) requires a bare `{e_int,_,K}` on one side of the
  comparison; `-5` fails that match because it parses to an `e_op` subtraction node, exactly as
  the ticket says.
- Reproduced the bug and the asymmetry live, against a clean `rebar3 compile` on this checkout
  (Erlang/OTP 25.3.2 — no version sensitivity here, this is a parser/checker defect, not a runtime
  one): `probes/Probe01` (refinement) fails with `opaque_refinement`; `probes/Probe02` (pattern,
  same literal/operator) compiles clean. Diagnostic text has drifted slightly from the ticket's
  excerpt (now four lines, mentioning the `WellFormed(value)` O(n) tier) but the defect is
  identical. Raw output: `probes/Probe01.output`, `probes/spike-results/baseline.output`.

## The finding that reframes the "grammar vs checker" question

**Guards do not already work.** I built `probes/Probe03` — two guard clauses partitioning `int` at
exactly `-5` (`when n >= -5` / `when n < -5`), which ought to be exhaustive. It compiles clean in
pattern position but **fails as `Classify is not exhaustive`** on current HEAD, because
`apply_guard/3` calls the identical `alternatives/1` → `comparison/1` path as `refine/3`, gets
`unknown` back for the same reason, and (per `bs_check.erl:3448-3465`, comment on line
3450-3458) *silently credits nothing* rather than erroring — so the guard's negative half
contributes nothing to the residual and the pair looks incomplete. `probes/Probe04` is the control
(`>= 5` / `< 5`): it compiles clean, confirming the guard mechanism itself is sound and the defect
is specific to the negative literal. Both are real: `probes/Probe03.output`,
`probes/Probe04.output`.

This matters because it settles what the ticket explicitly declined to guess: **the shared
`expr` grammar is not where the two sites disagree — they don't disagree, they're both broken,
identically, because they share the one narrow notion of "constant" in `comparison/1`.**
Refinements surface it loudly (`opaque_refinement`); guards swallow it silently into a spurious
"not exhaustive". A refinement-only grammar carve-out would leave guards broken and would be the
exact split the "one translator" comment exists to prevent — it fixes the loud failure and leaves
the silent one in place, which is arguably worse than either failing loudly.

## The two candidates, run for real

Both were implemented as spikes against a full checkout (`cp -r beam-sharp /tmp/beamsharp-spike-*`)
and built with `rebar3 escriptize`, not reasoned about. Diffs are `probes/spike-grammar.diff` and
`probes/spike-checker.diff` (a narrower checker variant is `probes/spike-checker-narrow.diff`, see
below). Full outputs per variant: `probes/spike-results/{grammar,checker,checker-narrow}.output`.

### Option A — grammar-side

Not the site-specific carve-out the ticket sketched (I could not find a way to narrow only
`refinement`'s grammar without literally duplicating the whole comparison/conjunction grammar out
of `expr`, which would be a large diff and would be the disagreement-risk the comment warns about,
realized). Instead: the **existing** `expr -> '-' expr` semantic action already sees the desugared
node it's about to build; I changed it to check whether its operand is already an `e_int` literal
and, if so, produce `{e_int, -N}` directly instead of the subtraction wrapper — a change to the
one production every negation in the language desugars through, not a new production and not a
refinement-specific rule.

```erlang
expr -> '-' expr :
    case '$2' of
        {e_int, _, N} -> {e_int, line('$1'), -N};
        _ -> {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}
    end.
```

- **Diff size**: 1 file (`bs_parser.yrl`), 4 lines changed (1 removed / 4 added).
- **Test suite**: `rebar3 eunit` — 620 passed, the same 1 pre-existing unrelated failure as
  baseline (`cli_tests:batch_runs_every_entry_in_one_vm_and_attributes_each`, a UTF-8/locale
  assertion, `probes/baseline-eunit.log` — fails identically on an untouched checkout). Every
  `bin/check-*.sh` gate that passes on baseline passes on this spike:
  `check-negation.sh`, `check-diagnostics.sh`, `check-examples.sh`, `check-feature-scenarios.sh`,
  `check-switch-diagnostics.sh`, `check-language.sh`. `check-residual-pasteable.sh` fails
  identically on baseline and spike (pre-existing, a printer-table staleness, unrelated to
  refinements).
- **Fixes**: Probe01 (refinement), Probe02 (pattern, already worked), Probe03 (guard — bonus,
  the silent failure above is also gone) and Probe04 (control) all compile clean. **No scope
  creep**: Probe05 (`value >= 2 + 3`) stays refused — general arithmetic never becomes a literal,
  only literal negation does, because that's the only shape this production folds. Probe06
  (`value >= n`) stays refused.
- **Strongest counterargument**: it changes the shape of the AST unary minus over a literal
  produces (`e_int` instead of `e_op`) for *every* `expr` in the language, not only inside
  refinements — an emitter or downstream pass that pattern-matches on `{e_op,'-',{e_int,0},_}`
  specifically (rather than going through `op_type('-')` generically, which the grammar's own
  comment at `:592-594` says is why negation was lowered this way in the first place) would see a
  different shape than before. I grepped for `{e_op,.*'-'.*e_int.*0` and found no such
  match-on-the-desugared-zero-subtraction pattern elsewhere in `bs_check.erl`, `bs_lower.erl`, or
  `bs_run.erl`, but I did not exhaustively read the emitter.

### Option B — checker-side

As the ticket phrases it — *"constant-folding a literal arithmetic node before asking whether the
comparand is constant"*, implemented generally (fold `+`, `-`, `*` over literals recursively) in
`comparison/1`:

- **Diff size**: 1 file (`bs_check.erl`), 28 lines added, 2 removed.
- **Test suite**: identical clean result to Option A — 620/621 eunit, same one pre-existing
  failure, same gate scripts all green, `check-residual-pasteable.sh` fails identically.
- **Fixes**: Probe01/02/03/04 all clean, same as Option A.
- **Measured scope creep — this is the sharp fact**: `probes/Probe05` (`value >= 2 + 3`), refused
  today, **flips to accepted** under this spike. That's not hypothetical; it's the literal
  behavior of implementing the ticket's own stated checker approach. `value >= n` (Probe06) still
  correctly stays refused — a bare variable never folds — so the risk is bounded to literal
  arithmetic, not open-ended, but it is real and it is unannounced: nothing in the ticket's
  five accepted/refused refinement examples exercises `2 + 3`, so this spike silently answers a
  question ("is arithmetic on refinement bounds allowed?") the ticket never posed.
- **Strongest counterargument**: this is exactly the "raises the question of where it stops"
  the ticket names. The general fold answers it by accident, in the direction of "more than `-5`,"
  the first time anyone writes `2 + 3` in a refinement.

### A narrower Option B variant (found during the spike, not asked for)

I also tried a checker-side fold that recognises *only* the exact shape the parser produces for a
literal negation — `{e_op,'-',{e_int,0},{e_int,K}}` — and nothing else (`probes/spike-checker-narrow.diff`,
9 lines net). It passes the same 620/621 eunit run, and Probe05 (`2 + 3`) correctly **stays
refused** — no scope creep. Structurally this is the checker-side mirror of Option A: same
recognised shape, same scope, implemented one file over. It is smaller than the general fold (9
lines vs. 28) but larger than Option A (9 vs. 4), and it does not touch the AST shape unary minus
produces for the rest of the compiler — the tradeoff is the reverse of Option A's counterargument:
this leaves `{e_op,'-',{e_int,0},K}` as a node other passes still have to know is "really" a
literal, in every place that isn't `comparison/1`.

## Recommendation

**Option A (grammar-side, the `-integer`-folds-to-a-literal semantic action), with the narrow
checker variant as the fallback if David doesn't want unary-minus-over-a-literal producing a
different AST shape everywhere in the language.**

The one piece of evidence that tips it: **Option A is the only candidate that fixes the guard
failure (Probe03) as a side effect of fixing the stated bug, using the smallest diff of the three
working candidates (4 lines), with zero scope creep (Probe05 stays refused) — and it does this
*without* touching `bs_check.erl` at all, so it cannot be the checker-side "where does the fold
stop" risk the ticket itself names, because there is no fold in the checker to stop.** The general
checker fold (the ticket's own literal phrasing) is the one candidate that measurably changes
behavior outside the ticket's five stated examples (Probe05), which is the exact risk the ticket
flagged as unresolved and did not want guessed at. The narrow checker fold avoids that but is
larger than Option A for no behavioral gain I could find — it recognises the same one shape,
in a different file.

## What I could not verify

- Whether any code outside `bs_check.erl`/`bs_lower.erl`/`bs_run.erl` (the three I grepped)
  pattern-matches the specific `{e_op,'-',{e_int,0},N}` shape rather than going through
  `op_type('-')`/`erl_op('-')` generically — I did not read every module, only grepped for the
  literal tuple shape. This is Option A's one live risk and it's a grep-scale check, not a
  read-everything one.
- Whether OTP version drift (28.5 pinned vs. 25.3.2 available here) affects `yecc`'s conflict
  resolution or output in a way that would change either spike's behavior — both spikes compiled
  with zero `yecc` conflict warnings on 25.3.2, but I have no way to build against 28.5 here
  (mise/asdf unavailable, github.com blocked) to confirm parity.
- `check-tour.sh` was not run against either spike — the baseline run on the real repo already
  fails on the "published page" comparison half, which reads as a network-dependent check (this
  sandbox blocks github.com/api.github.com), so it's uninformative here either way; I did not
  chase whether it would matter for this specific change (it shouldn't — this ticket never touches
  LANGUAGE.md/TOUR.md).
- I did not attempt a real hybrid grammar+checker option beyond the narrow-checker variant above;
  I don't believe one is needed given Option A's result, but I didn't rule it out by trying one.
- CLI-supplied runtime arguments (`bsc DIR Fn ARG`) do not appear to be checked against a
  parameter's refinement bounds at all — `Octet Id(Octet x)` accepts `300` on unmodified HEAD, not
  just under my spikes. This looks like a pre-existing, unrelated property of how `bsc`'s CLI
  argument path works (probably untyped literal parsing bypassing the boundary-kind machinery that
  guards ordinary calls), not something either candidate fix touches, but I did not chase it since
  it's out of scope for ticket 57.
