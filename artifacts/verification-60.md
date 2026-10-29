# Verification of decision-brief-60 (independent)

Verifier: fresh copy of `artifacts/probes-60/` in `/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/verify-60/p/`; originals untouched (only the copy's `go/run.sh` GOCACHE path was edited). Tools: gleam 1.12.0, Elixir 1.14/mix, OTP 25, **Go 1.24.7 at /usr/local/go/bin/go**. bsc not built. Repo HEAD now `c314b37` (58 commits; brief read `c07bb7f`); `git diff c07bb7f HEAD -- compiler/src` is empty, so source line numbers are unaffected.

## Probe table

| Probe | Reproduced? | Circularity | Citations / notes |
|---|---|---|---|
| 1 gleam/run.sh | YES, output identical (apart from path). Also ran full `gleam build` (rc from gleam itself = 0). | none for the claim. Caveat: `run.sh` prints `rc=$?` after `| tail`, so the printed rc is tail's, not gleam's (I re-ran: gleam rc=0, so claim holds). Control (non-`pub` fn) exercises a different rule (private visibility) than `internal_modules`; it proves the harness can go red, not that internal is "enforced elsewhere". Weak control, not circular. | **Extra variant I ran:** dependency as a `git` dep (local repo, manifest `source = "git"`): same result, builds rc 0, no warning. So "not enforced" is not a path-dep artefact; only hex remains unprobed (unreachable offline). Real cross-package access: yes (separate gleam.toml/package names `app_internal` vs `lib`). |
| 2 elixir/run.sh | YES, identical (diff empty). | none | Claims about `:hidden` docs, warning-not-error, UndefinedFunctionError, xref callers all match. |
| 3 erlang/run.sh | YES, identical. | none | `error_handler.erl:39-46` ok (function starts :38). |
| 3b friend.escript | YES. Also confirmed the no-`+debug_info` claim: xref returns `[]` for edges and undefined calls. | **suspect (mild)**: the "rule" hard-codes the `_internal` suffix and the fixture is named to match, so the single violation is manufactured by construction. It demonstrates only that xref exposes module edges, not that a real rule is expressible. Brief words it as "implementable"; acceptable. | |
| 3c xref_time | YES on figures, but range misquoted. 5 runs: load 941-1667 ms, query 47-64, check 3. | none | Brief says "load 0.73-1.06 s (3 runs: 1057, 908, 881)": the recorded runs are 0.88-1.06, so "0.73" has no support, and my load times were higher (to 1.67 s). Machine-variance; the "dominated by loading" conclusion stands. |
| 3d attrs | YES, identical. | none | `erl_lint.erl:258-259` ok. `-ignore_xref` is in ea.erl but never probed; brief admits it. |
| 5 go/run.sh | YES, identical. | none for the claim; negative control (billing) goes through the same loader path. | See independent probe below. |
| 4 cost/model.escript | YES, 3 repeats: 8,000 edges 19.2-19.5 ms min; all-pairs N=1000 min 3.25-3.40 s (median 4.4 s); N=100/10 within noise (one run had N=10 at 348 us). | **suspect.** (a) Linear-in-edges is true by construction: the model iterates edges and does a map lookup. It measures Erlang list-comprehension speed on synthetic atoms and says nothing about bsc. (b) The all-pairs baseline is a strawman, quadratic by construction, and the control shows 2.2 s of its 3.4 s is pair enumeration with no rule at all. (c) The negative control (no restricted modules) is 15.3 ms vs 19.4 ms, so the rule is ~20% of an already trivial loop; fair, and the brief says so. Brief already hedges ("read the shape, not the constant"). Treat the cost row as "no reason to fear", not evidence. | |
| 6 source reads | n/a | n/a | All checked, see below. |

## Citation spot-check
- `bs_check.erl:495` add_import/7, `:509-523` add_module_import/3, `:488` Known, `:524` add_namespace_import, `:587` children/2, `:4558` qualified_module, `:4566-4570` module_not_imported, `:4470` private_callee: **all correct.** `is_child/2` used in the Option A sketch does not exist (pseudo-code, fine).
- `bsc.erl:227-239` World entry: correct (no `scope` key). `:293` is the cache-load entry (~289-293): ok.
- `bs_diag.erl:669` built clause, `:2095` message clause: correct.
- F12 amendment cited as `F12...md:7-12`: **actual heading is line 11** (lines 7-10 are Depends/header text). Content correct. `F12:185` "Two words" correct. `F12:175` cited for "same cost for a keyword": line 175 is mid-sentence about check-tokens; loose but the section (editor grammars) is right.
- Ticket 22:133,435; 60:19,31-34; 41:490; F15:31 and :217-231; LANGUAGE.md:155-158; 24:219 (`every function in an aggregate is exported today`) and :402: all correct.
- **Mismatch:** brief says "In tickets the only hits are 22:133,435, 60:19,31-34, F12:185, 41:490" for `internal/friend/sealed/visible_to`. A plain `grep -w` over `wayfinder/issues/` also hits 03, 05, 10, 11, 12, 15, 16, 18 (other senses: "internal consumer", "sealed inside a declaration", "false friend"). The claim is true only if restricted to the module-visibility sense; as written it is overstated. CONTEXT.md: 0 hits, confirmed.
- `0b761f6`: `git cat-file -t` fails, repo is shallow: **confirmed absent**. Ticket 60 itself (not the brief) carries the 407-425 and `add_module_import/5` text.
- "Repo HEAD c07bb7f (51 commits)": c07bb7f exists, repo has since grown; harmless.

## Labelling
MEASURED-HERE items are all genuinely executable and reproduced. The brief labels probe 4 "MEASURED-HERE (model)", which is honest. Item 6 is RECORDED-NOT-RERUN and correct. The Go row is labelled "added because it is installed": true. Limitation "Gleam probed on a path dependency only" is now partly superseded (git dep also unenforced).

## Independent probe (load-bearing claim: Go `internal` is subtree-scoped and enforced)
Written fresh at `.../verify-60/go2/m` with different names and shapes: allowed = `a/b/c` (deep descendant), `a/b` (the parent itself), `a/q` (under `a/` for `a/internal/top`), and an importer inside `internal` itself; refused = `a/bx` (string-prefix sibling of `a/b`, so the rule is path-segment aware), `z`, `z2`. An external `b_test` package in `a/b` imported the internal package without complaint. Result: **agrees with the brief**: subtree rule keyed on the parent of `internal/`, refused with `use of internal package ... not allowed`.
One imprecision the brief inherits ("compiler-enforced"): the check is made by the **go command's package loader**, not the Go compiler. `go tool compile` with a hand-built importcfg compiled the "refused" `z` package with rc 0. Enforcement is at the build-system layer, which matters for the analogy: bsc is both loader and checker, so no such bypass exists unless `--api`/lenient modes skip it (see `add_import` Mode).

## Verdict
Probes reproduce exactly; nothing fabricated. Strongest finding (Gleam/Elixir do not enforce, Go does at subtree scope) is sound and survives the git-dep variant and my independent Go probe. Weak spots: cost model is circular as evidence (by construction linear), friend.escript is fixture-matched, the "only hits" grep claim is overstated, minor line/range misquotes (F12 7-12, xref 0.73 s), and "compiler-enforced" should read "go-command-enforced". Hex dependency for Gleam, Elm, `-ignore_xref` remain unverified. None of this changes the recommendation.
