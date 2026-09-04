# Verification — 57 / ENG-239 decision brief

Independent audit. Everything below was run fresh by the verifier: own `.bs` probes (not the
brief's `Probe01`–`Probe06`), own copies of the spikes rebuilt from the diffs by hand-applying
the exact hunks, own `eunit` runs, own gate-script runs, own greps. Nothing here reuses the
brief's `probes/*.output` as evidence — those were read only for comparison after the fact.

Verifier environment: Erlang/OTP 25.3.2, rebar3 3.19.0, same repo checkout, matches the brief's
stated environment.

## Claim-by-claim

### Line citations

| Citation | Claim | Verdict |
|---|---|---|
| `bs_parser.yrl:472-473` (`int_lit`) | exact match | **CONFIRMED** — read the file, byte-identical to the brief's quote |
| `bs_parser.yrl:595` (`expr -> '-' expr`) | exact match | **CONFIRMED** |
| `bs_parser.yrl:206` (`refinement -> expr`) | exact match | **CONFIRMED** |
| `bs_parser.yrl:201-206` ("one translator" comment) | quoted with `...` eliding one clause | **CONFIRMED** — the elided text is real prose, not a hidden qualifier; ellipsis used honestly |
| `bs_check.erl:1299-1303` (restated comment) | quoted with `...` eliding one sentence | **CONFIRMED**, same as above |
| `bs_check.erl:3490` (`comparison/1` literal requirement) | requires bare `{e_int,_,K}` | **CONFIRMED** — read lines 3490-3491, exact match |
| `bs_check.erl:3448-3465` / `3450-3458` (`apply_guard/3` silent-credit comment) | "Ticket 08: `HasSku(lines, sku)` credits nothing" / `{bs_types:none(), Ty}` branch | **CONFIRMED** — read lines 3440-3499, matches exactly |
| `bs_parser.yrl:592-594` (why negation was lowered this way) | cited in Option A's counterargument | **CONFIRMED**, exact match |

No misquotes-as-quotes found anywhere. All eight citations check out against the real file at
the stated lines.

### Base bug and the asymmetry

Wrote my own `MyCheck1` (`type Delta = int where value >= -5`) and `MyCheck2`
(`Cls(<= -5) -> :low` / `Cls(> -5) -> :high`) against unmodified HEAD (`rebar3 compile &&
rebar3 escriptize`, fresh build, no warnings).

- `MyCheck1`: fails with `opaque_refinement`, exit 1. **CONFIRMED.**
- `MyCheck2`: compiles clean, exit 0. **CONFIRMED.**

### The sharpest claim: "guards do not already work"

Wrote `MyCheck3` (`Cat(n) when n >= -5 -> :hi` / `Cat(n) when n < -5 -> :lo`) and `MyCheck4`
(same partition at `5`, no negative literal) independently, without copying the brief's
`Probe03`/`Probe04` wording.

- `MyCheck3` on unmodified HEAD: **fails** — `error: Cat is not exhaustive`. **CONFIRMED**, and
  this is the brief's load-bearing finding: the guard site is broken too, identically and
  silently (spurious "not exhaustive" rather than a diagnostic naming the real cause).
- `MyCheck4` (control, positive literal) on unmodified HEAD: compiles clean, exit 0.
  **CONFIRMED** — proves the failure is specific to the negative literal, not a general defect
  in guard exhaustiveness or in my own test.

This is independent, non-circular confirmation of the brief's central reframing.

### Both spikes, built and tested independently

I did not reuse the brief's spike trees. I made three fresh `cp -r` copies of the repo
(`/tmp/verify-spike-grammar`, `/tmp/verify-spike-checker`, `/tmp/verify-spike-checker-narrow`)
and hand-applied the exact hunks shown in `spike-grammar.diff`, `spike-checker.diff`, and
`spike-checker-narrow.diff` via `Edit`, matching the diffs' before/after text exactly. Each was
rebuilt clean (`rm -rf _build && rebar3 compile && rebar3 escriptize`) with **zero yecc conflict
warnings** on all three, confirming that specific brief claim too.

Ran `MyCheck1`–`MyCheck6` (see below for `MyCheck5`/`MyCheck6`) against baseline and all three
spikes:

| variant | MyCheck1 (refinement `-5`) | MyCheck2 (pattern) | MyCheck3 (guard `-5`) | MyCheck4 (guard control) |
|---|---|---|---|---|
| baseline | fail | pass | fail | pass |
| grammar (A) | **pass** | pass | **pass** | pass |
| checker (B) | **pass** | pass | **pass** | pass |
| checker-narrow | **pass** | pass | **pass** | pass |

All three spikes fix the refinement and the guard, and don't disturb the pattern site or the
positive-literal control. **CONFIRMED** for all three variants.

### `rebar3 eunit` parity

Ran on baseline and all three fresh spike copies, independently:

| variant | passed | failed | which test failed |
|---|---|---|---|
| baseline | 620 | 1 | `cli_tests:batch_runs_every_entry_in_one_vm_and_attributes_each` |
| grammar (A) | 620 | 1 | same test |
| checker (B) | 620 | 1 | same test |
| checker-narrow | 620 | 1 | same test |

Exact match to the brief's claim (620/621, same pre-existing failure, all three variants).
**CONFIRMED**, no discrepancy.

### Scope creep — Option B's sharpest claim

Wrote `MyCheck5` (`type Score = int where value >= 2 + 3`) and `MyCheck6`
(`type Score = int where value >= n`) independently, then ran against baseline and all three
spikes:

| variant | MyCheck5 (`2 + 3`) | MyCheck6 (bare var `n`) |
|---|---|---|
| baseline | refused | refused |
| grammar (A) | **stays refused** | refused |
| checker (B, general fold) | **flips to accepted** | refused |
| checker-narrow | **stays refused** | refused |

Exactly reproduces the brief's claim: only the general checker fold (Option B) accepts `2 + 3`;
Option A and the narrow checker variant both keep it refused; a bare variable never folds under
any variant. **CONFIRMED**, independently, bit-for-bit the same pattern as the brief's
Probe05/Probe06.

### Circularity check

**Verdict: no circularity.** Two independent reasons:

1. I wrote `MyCheck5` before re-reading the brief's `Probe05.bs`, from the ticket's own text, not
   the brief's framing.
2. More importantly: **the ticket itself names `2 + 3` as the example.** `wayfinder/issues/57-negative-literals-in-refinements.md` reads: *"raises the question of where it
   stops: `-5` certainly, `2 + 3` probably, `value >= n` never."* The brief's Probe05/Probe06 (and
   my MyCheck5/MyCheck6) are not a gotcha invented to make Option B look bad — they are the exact
   three cases the ticket itself poses as the open question. There was no way to choose this test
   to rig the outcome; the ticket picked it first, and the general-fold implementation's behavior
   on it was not knowable in advance without actually building it, which the brief (and I,
   independently) did.

### The grep claim ("what I could not verify")

Ran the brief's stated grep verbatim:

```
grep -n "{e_op,.*'-'.*e_int.*0" compiler/src/bs_check.erl compiler/src/bs_lower.erl compiler/src/bs_run.erl
```

Result: no matches (exit 1). **CONFIRMED** — the grep genuinely finds nothing in those three
files.

**FLAGGED, methodology gap (not a false claim):** `bs_lower.erl` and `bs_run.erl` contain **no
references to `e_op` at all** — they are dead-end checks for this question, since they don't
touch the AST shape in question either way. The file that actually *does* pattern-match on
`e_op` nodes and lower them (i.e., "the emitter" the brief's own counterargument names as the
risk) is `bs_emit.erl`, which the brief did not grep. I checked it independently:

```
compiler/src/bs_emit.erl:770:  expr({e_op, L, Op, A, B}, C)  -> {op, L, erl_op(Op), expr(A, C), expr(B, C)};
...
compiler/src/bs_emit.erl:925:  erl_op(Op)   -> Op.   % + - * < > >=
```

`bs_emit.erl` handles `'-'` generically through the catch-all `erl_op(Op) -> Op` clause — there
is no special case anywhere in it matching `{e_op,'-',{e_int,0},_}` specifically. So **the
brief's ultimate conclusion holds** (Option A's AST-shape risk is real in principle but not
realized anywhere in this codebase today), but the "what I could not verify" section's framing —
naming three files "the ones I grepped" — overstates how much of the relevant surface was
actually covered, since two of the three never could have contained a match. This doesn't change
the verdict, but the brief should grep `bs_emit.erl` (and ideally the rest of `compiler/src/*.erl`)
before stating this as settled.

### CLI refinement-bounds claim

Compiled `Octet Id(Octet x)` with `type Octet = int where value >= 0 and value <= 255` on
unmodified HEAD and ran `bsc OctetCheck Id 300`: **output `300`, exit 0** — the out-of-bounds
argument is silently accepted at the CLI boundary. **CONFIRMED**, matches the brief's disclosed
(and correctly out-of-scope-flagged) finding exactly.

### Gate scripts (`check-negation.sh` etc.)

**Minor path nit:** the brief writes `bin/check-*.sh`; these scripts actually live under
`compiler/bin/`, not the repo-root `bin/` (which holds a different set of wayfinder/map gates:
`check-map.sh`, `check-links.sh`, etc. — none of the six scripts the brief names exist there).
Cosmetic, not substantive — in context "the compiler's gates" is unambiguous, and I ran the
compiler-tree scripts the brief clearly meant.

Ran all seven named scripts (`check-negation.sh`, `check-diagnostics.sh`, `check-examples.sh`,
`check-feature-scenarios.sh`, `check-switch-diagnostics.sh`, `check-language.sh`,
`check-residual-pasteable.sh`) on baseline and independently on the grammar spike (Option A, the
recommended candidate):

- The six that pass on baseline pass on the grammar spike too, with **byte-identical stdout/stderr**
  (`diff -q` confirmed identical for all six).
- `check-residual-pasteable.sh` fails on both, for the same pre-existing reason (a residual
  round-trip table needing a printer-table update, unrelated to refinements).

**CONFIRMED** in substance.

### Diff-size claims — discrepancies found

I counted actual added/removed lines in the three diff files directly (`grep -c '^+'` /
`'^-'` excluding the `+++`/`---` file-header lines), rather than trusting the brief's prose.

| variant | brief claims | actual (measured) | verdict |
|---|---|---|---|
| Option A (grammar) | "4 lines changed (1 removed / 4 added)" | **1 removed / 5 added** (net +4) | **FLAGGED** — added-line count is off by one. Net delta (+4) is right, but the parenthetical breakdown is not: it's 5 added, not 4. |
| Option B (general checker fold) | "28 lines added, 2 removed" | **28 added / 2 removed** | **CONFIRMED**, exact |
| Option B narrow variant | "9 lines net" / "9 lines vs. 28" / "9 vs. 4" | **17 added / 2 removed** (net +15) | **FLAGGED** — materially wrong. The real size is roughly double what's claimed. The *ordering* (narrow < general fold, narrow > Option A) still holds — 17 < 28 and 17 > 5 — but the specific numbers used to sell "the narrow variant is nearly as small as Option A" are not accurate; 17 is much closer to 28 than to 5. |

This is worth fixing before the brief goes to David: the narrow-checker-variant size claim
understates its cost by about half, and it's one of the two numbers doing the comparative-size
argument for the fallback recommendation.

## Overall

**Confidence: HIGH**, with two caveats that should be corrected before this brief is used to
decide, neither of which overturns the recommendation:

1. The diff-size arithmetic for Option A (5 added, not 4) and especially the narrow checker
   variant (17 added / net +15, not "9 lines net") is measurably wrong — the narrow variant is
   roughly twice the size claimed, though it's still smaller than the general fold and larger
   than Option A, so the ordering argument survives even though the numbers don't.
2. The "what I could not verify" grep section names three files as checked, but two of them
   (`bs_lower.erl`, `bs_run.erl`) never reference `e_op` at all and so were never going to find
   anything; the one file that actually matters for this risk (`bs_emit.erl`, the code generator)
   was not grepped. I checked it myself and it confirms the brief's conclusion (no
   special-cased match on the desugared-zero-subtraction shape exists anywhere), so this doesn't
   change the answer, but the brief's methodology description oversells its own coverage here.

Everything that actually decides the question — the base bug, the pattern/refinement asymmetry,
the guard failure (the brief's sharpest and most load-bearing claim), the scope-creep flip under
the general checker fold vs. its absence under Option A and the narrow checker variant, the
`eunit` parity across all three spikes, and the zero-yecc-conflict / gate-script parity for the
recommended option — reproduced exactly under my own independent tests, written before I
re-examined the brief's own probes, with no circularity (the sharpest scope-creep test, `2 + 3`,
is the ticket's own named example, not an invented one).

**I would recommend the same option the brief does: Option A (grammar-side).** It is the only
candidate that fixes the guard failure as a side effect without touching `bs_check.erl` at all,
carries zero measured scope creep, and — even correcting the brief's own line-count error — is
still the smallest of the three working diffs (6 total changed lines vs. 19 for the narrow
checker variant vs. 30 for the general fold, using my corrected counts). The narrow checker
variant remains a reasonable fallback if unary-minus-over-a-literal producing a different AST
shape (`e_int` vs. `e_op`) turns out to matter to David for reasons beyond what a grep of
`bs_check.erl`/`bs_lower.erl`/`bs_run.erl`/`bs_emit.erl` can show.
