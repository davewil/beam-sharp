# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

**Status of the ticket: left open.** This brief recommends; it decides nothing.
Probes: `artifacts/probes/57/` (outputs beside each script as `output-*.txt`). Toolchain and caveats: `artifacts/probes/README.md`.

## The gating question (ask this one alone)

> Does the fold of `-5` live in **the checker's reader** (`comparison/1`) or in **the parser's `negate/2`**?

Everything else (how far the fold goes, what the message says) follows from the answer and is cheap.

## What the ticket got wrong, found by running it

1. **The mechanism it describes is out of date.** The ticket says `-5` reaches the checker as `0 - 5`. Since F51 the parser emits a node of its own: `{e_neg,{2,29},{e_int,{2,30},5}}` (probe 57/probe P7, `bs_parser.yrl:590`, `:947-948`). `negate/2` already folds a negated **float** literal and leaves an **integer** one as `e_neg`.
2. **The defect is not refinement-only.** Refinements and guards both read through `alternatives/1` → `comparison/1` (`bs_check.erl:4998-5027`). Probe P6: two guards that cover `int` compile with `5` and are refused with `-5`:

   ```csharp
   H(n) when n >= 5  -> :hi      // compiles, exhaustive
   H(n) when n < 5   -> :lo

   H(n) when n >= -5 -> :hi      // error: H is not exhaustive   (the guards are unread, credit no coverage)
   H(n) when n < -5  -> :lo
   ```

   So the ticket's "grammar at the refinement site" option cannot be the whole fix: it would leave the guard reader unable to see `-5`. The ticket's own argument (one grammar so refinement and guard cannot disagree) is the measured one.
3. All five spellings of a negative bound are refused in a refinement today: `-5`, `(-5)`, `-(5)`, `- 5`, `0 - 5` (P5). `2 + 3` in a refinement is refused as well (P4, `opaque_refinement`); as a guard it compiles but the checker cannot read it, so it credits no coverage.

## Sub-decisions

| # | Sub-decision | Settled by |
|---|---|---|
| a | Where the fold lives (checker or parser) | the gating question |
| b | How far it goes: `-N` only, or constant arithmetic (`2 + 3`, `-(2+3)`)? | follows from (a); `value >= n` stays refused either way |
| c | Does one fix cover refinement and guard? | measured: yes, they share `comparison/1` — not a free choice |
| d | The `opaque_refinement` text recommends `value >= 0` and never mentions signs | cosmetic, follows the fix |

## Evidence

**Baseline (P1–P6, `output-probe.txt`).** Refinement `value >= -5` refused (`opaque_refinement`); pattern `Sign(<= -1)` compiles and runs (`:neg`); guard `when n >= -5` compiles and runs (single guard is fine because an unread guard only matters for exhaustiveness).

**Two prototypes, each a scratch build of `compiler/src` with a 1–3 line patch (`57/proto/*.patch`, rebuilt by `build-variants.sh`).** Not in the repo.

| probe (variants.sh) | baseline | A: checker fold | B: parser fold |
|---|---|---|---|
| `type Delta = int where value >= -100 and value <= 100` | refused | `-7` accepted and returned | accepted |
| two guards over `-5` (exhaustive?) | "H is not exhaustive" | compiles | compiles |
| emitted `-5`, `-9223372036854775808`, `- -5` | -5, min_int, 5 | same | same |

The probes were chosen before the patches were written and were run unchanged against all three builds; they are the ticket's own repro plus the guard case (the guard case was not in the ticket).

**Verifier finding: A and B are not equivalent** (`artifacts/verification/ENG-239.md`). Beyond the author's probes: `value < -(-5)` and `value >= - -5` are accepted by B and refused by A; a refinement `-9..-1` with `G() -> -4` compiles under B and is refused under A ("returns a value its signature does not declare") because `type_of(e_neg)` answers plain `int`; and `x / -0` crashes at run time under baseline and A while B refuses it at compile time. Every difference favours B, but B changes expression typing and the zero-divisor check, so the gates matter more for B than I implied.

**Cost.**
- Term size of the node the checker sees: `e_neg(e_int 5)` = **14 words**, folded `e_int -5` = **7 words** (`measure.sh`, `erts_debug:flat_size`).
- Compile time of a 7-line module with one refinement and two guards, 200 compiles in one VM: saved run 4811 / 4830 / 4902 µs (baseline / checker / parser); the verifier's rerun 5248 / 5542 / 5462 µs. That is **noise, not a difference**; neither the numbers nor any ordering between variants should be read.
- Regression signal is weak, say so plainly: the existing eunit suite has **448 failures on this toolchain even on the unmodified compiler** (OTP 29 / no rebar3; tests expecting diagnostics on stderr see empty output). The failing set is identical across baseline, A and B (`57/eunit.sh`), so the suite neither supports nor contradicts either patch. The `compiler/` gates should be run on the chosen option (`./bin/verify.sh`) before any claim.

## Survey (what neighbouring languages do with a negative literal)

| language | what the parser keeps | where it is folded | evidence |
|---|---|---|---|
| Erlang | `{op,1,'-',{integer,1,5}}` in both pattern and guard | downstream: Core has `-5`, asm has `{integer,-5}`; `erl_parse:normalise` folds on request (`stdlib-8.1.1/src/erl_parse.yrl:1984`) | `57/probe.sh` P8 (executed); `erl_parse.yrl:623-624` `prefix_op -> '-'` |
| Elixir 1.20.4 | `{:-, [line: 1], [5]}` from `Code.string_to_quoted` for `-5`, `- 5` and `-(5)` alike | in Elixir's own translation: the abstract form handed to Erlang for `when x >= -5` is `{:integer,{2,19},-5}` | `57/neighbours.sh` (executed) |
| Gleam 1.19.1 | not observable (compiler is a binary here, no source) | `-5` works as a pattern and in an `if` guard; BEAM asm has `{test,is_eq_exact,…,{integer,-5}}` and `is_ge … {integer,-5}` | `57/neighbours.sh` (executed) |
| Elm 0.19.1 | not probed | **could not run**: `package.elm-lang.org` is unreachable from this sandbox, so `elm make` cannot fetch `elm/core` | `57/neighbours.sh` prints the HTTP status |

Reading: every neighbour keeps the operator as a node at parse time and folds later in the consumer or the translation to Erlang; none has a refinement type, so none confronts the "refinement is an expr" choice. Citations for Elixir and Gleam are executed behaviour, not file:line, because their compiler sources are not installed (only `erl_parse.yrl` and `sys_core_fold.erl` are).

## Options (each is B# that compiles under it, plus the compiler delta)

**A. Fold in the checker.** `comparison/1` learns `{e_neg,_,{e_int,_,K}}` on either side (patch: 2 clauses, mirrored for `flip`).
```csharp
type Delta = int where value >= -100 and value <= 100   // compiles
H(n) when n >= -5 -> :hi                                // compiles; with `n < -5 -> :lo` the pair is exhaustive
type T = int where value >= 2 + 3                       // still refused
```
Strongest counterargument: it fixes the reader, not the AST, so every *future* consumer of an `e_int` comparand (a residual printer, `with` diagnostics, F48's "AST as a B# value") has to remember the same two clauses. The float case already went the other way.

**B. Fold in the parser, as floats already are.** `negate(_L, {e_int,IL,K}) -> {e_int,IL,-K}` (patch: 1 line, `bs_parser.yrl:947`).
Same acceptance as A in every probe above. (I claimed the emitted `.abstr` then holds a literal `-5`; the verifier's grep found nothing under any variant, so that is unbacked.)
Strongest counterargument: it changes the AST shape for **every** pass at once, not just the two readers measured here — I ran only the (environment-broken) eunit suite against it, and only the probes above. Any pass that matched `{e_neg,_,{e_int,…}}` to recover how the author wrote the number loses it; `grep -n e_neg compiler/src` finds `expr_vars` (`bs_check.erl:2601`), `type_of` (`:2889`), `used_vars` and `expr` in `bs_emit.erl` (`:743`, `:1067`) — grep shows they all handle `e_neg` generically rather than matching an int inside it, but I read only the matching lines, not the passes, and did not run the full gates.

**C. The ticket's first option: narrow the grammar at the refinement site only.** Not built. P6 shows the guard reader fails identically, so C leaves guards broken and re-creates the two-readers split the checker's `refinement` comment says it exists to prevent.

## Recommendation

**B**, conditional on `./bin/verify.sh` passing twice on a real toolchain — more strictly than I first wrote, since B alters typing of negative literals and the zero-divisor check (verifier-measured). On every extra input tried it accepts more correct programs than A; one line instead of two clauses plus their mirror, 7 words of AST instead of 14, and it makes every present and future consumer of an integer comparand agree by construction — the floats precedent (`bs_parser.yrl:947`) says the project already prefers this. If David would rather keep `e_neg` visible for diagnostics (F48 will want the author's spelling), take A. Evidence here does not separate them on behaviour; the choice is about where the next consumer's bug would come from.

## Not done / limits

- No gate run (`verify.sh`) — no rebar3, OTP 29, and 448 environmental eunit failures.
- Elm unprobed. Gleam and Elixir cited by executed output only.
- Fold extent (`2 + 3`) is not prototyped; the ticket's "where does it stop" is left for the answer to the gating question.
