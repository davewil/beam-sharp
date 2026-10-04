# Verification of the ticket 60 brief (independent re-run, 2026-10-04)

Method: fresh copies of `compiler/` under `/tmp/v60/{base,a,a1,b,d,i}` (HEAD sources; compiler/src is
unchanged between 98d9835 and the current HEAD 06e2dd9, `git diff --stat` empty), each `.patch` applied
by me with `patch -p1`, rebuilt with `/tmp/tc/rebar3 escriptize` on OTP 28. Probe scripts were copied to
`/tmp/v60/probes` with only their `/tmp/...` paths rewritten (so I did not overwrite the author's temp
dirs); outputs are in `verify/`. `i` is my own re-creation of the author's two-line instrumented copy.
Nothing under `brief.md`, `probes/`, `wayfinder/`, `compiler/` was edited; no commit, no Linear.

## 1. Probes re-run

| probe | result | note |
|---|---|---|
| 01 | REPRODUCED | identical output |
| 02 | REPRODUCED | needed my re-made instrumented copy; five `add_import` per `using`, one strict + four `expect=undefined` (lenient), as claimed |
| 03 | REPRODUCED | identical, five scenarios |
| 04 | REPRODUCED | v1 refuses `Acme.Dash` (a module that never names Rules) |
| 05 | REPRODUCED | identical |
| 06 | REPRODUCED | `cmp` says IDENTICAL; only the `ls -l` byte size differs (960 vs 952, longer temp path in CInf) |
| 07 | REPRODUCED | identical |
| 08 | REPRODUCED | identical |
| 09 | REPRODUCED | only the printed HEAD sha differs (06e2dd9 now; brief says 98d9835, which exists in the log) |
| 10 Gleam 1.12.0 | REPRODUCED | no error, ran, docs list only `lib` and `lib/helpers`, `exported=true call=6` (one "Compiled in 0.89s" vs 0.82s) |
| 11 Elixir 1.14 | REPRODUCED | `:hidden`, 36 of 253, warning on private call, exit 0 |
| 12 Erlang | REPRODUCED | 24 of 95 `-moduledoc false`; xref returns `{'Acme.Billing','Acme.Orders.Rules'}` |
| 13 Elm | REPRODUCED as "not reproducible" | `elm init` is refused by the proxy; strings counts 8 and 0 as claimed |
| 14 Rust 1.97.0 | REPRODUCED | E0603 for module and function; ok.rs prints `10 6` |
| 19 Go 1.24.7 | REPRODUCED | sibling refused, last `internal` wins, symbol still exported (count 3) |
| 16 | REPRODUCED (counts), timings are noise | 9,900 `add_import` calls, 321 modules, 1,980 `using`; medians 3.1/3.6/4.0/3.5/3.4 s, ranges overlap, so "not measurable" holds |
| 16b | **DIFFERS** | see section 2, "under 50 ms" |
| 17 | REPRODUCED (see below) | |
| 18 | REPRODUCED, plus my own control | see section 3 |
| 20 | REPRODUCED | identical, HEAD prints `1` on the same tree |
| 15 | not run on its own | it is the generator that 16 calls |

Eunit (`LANG=C.UTF-8` where stated; logs `verify/eunit_*.log`):

| copy | result | brief's claim |
|---|---|---|
| unpatched, ambient locale, no `../aoc` | **1305 passed, 4 failed** (body_check, cli, diagnostic_json, non_numeric_operand) | same, REPRODUCED |
| unpatched, C.UTF-8, aoc linked | **1309 passed, 0 failed** | "all four modules pass" REPRODUCED |
| A (within), C.UTF-8, aoc, plus `17_within_tests.erl` | **1314 passed** (1309 + 5 new) | brief says 1305/4 for the whole suite (that run had no within_tests and the ambient locale) and "119 tests with 5 new" for the four-module run; consistent, REPRODUCED |
| A' (path-derived) | **1309 passed** | REPRODUCED |

The wall times (about 450 s each when four ran at once) are not comparable with the brief's 8 m 8 s / 6 m 19 s.

## 2. Factual claims

- `add_module_import/3` at `bs_check.erl:511-525`, called from `add_import/7` at `:499`: **TRUE** (opened; the function ends at 525 and reads `exports` and `types`).
- Ticket's 407-425 is `qualify_refs`: **TRUE** (407 is `qualify_refs`, lines before are `crossing`).
- `bs_parser.yrl:323-324` `visibility`: **TRUE**. `bs_check.erl:41` `vis = private` in `#fn`: **TRUE**.
- `0b761f6` not in the clone: TRUE (`Not a valid object name`). HEAD 98d9835: **TRUE as a commit**, but it is not the HEAD now (06e2dd9); compiler/src is identical, so no consequence.
- Option C site list (`:299 364 375 478 602 2350`, `bs_emit.erl:141`, `:3656` and `:4200`): **TRUE**. The ctx record has no module field: TRUE (I read the record; probe 09's last output line `1` is uninterpretable on its own, a stray count of the word "module" in a comment).
- Patch sizes **170 lines** (`03_prototype_within.patch`) and **76 lines** (`20_path_derived.patch`): TRUE (`wc -l`; 08 is 96, TRUE). Caveat: 170 counts diff context and hunk headers, and the 76-line A' patch has no lexer, parser or `bsc.erl` change, which I confirmed from the file list.
- "under 50 ms for 9,900 evaluations": **NOT REPRODUCED as a bound.** Six runs of probe 16b gave 53, 75, 43, 74, 35 and 38 ms (and the author's 48). It is an interpreted fun in the shell with a first-call warm-up, load-dependent. What survives: about 4-7 microseconds per evaluation interpreted, so 9,900 of them are a few percent of a 3 s compile at worst, and compiled code is faster. The conclusion (negligible) stands; the figure "48 ms, firm" does not. The brief calls this the only firm bound in section 8, which overstates it.
- "9,900 calls for 1,980 using lines, five passes": TRUE (instrumented count 9,900 reproduced).
- "byte-identical `.beam` with and without `within`": **TRUE** (`cmp` IDENTICAL, outside Erlang caller returns 60, `apply/3` returns 6). The baseline puts a comment on the `within` line so line numbers match: sound, and the two failed earlier outputs are retained.
- Surveys: Gleam, Elixir, Erlang, Rust, Go all re-run and match. Elm cannot be run (network); the brief says so. C# is not run; the brief says so. Gleam 1.18.1 was not available, so "no error at 1.12.0" is a statement about 1.12.0 only and the brief is explicit about that.
- Ticket 41 `Internal/` label at line 490, and F15.11 as the superseding row: TRUE.
- I found no `.bs` file that uses `within` as an identifier, so the new reserved word breaks no existing source. The brief does not claim this.

## 3. Circularity audit

For each prototype I ran the same programs on the unpatched compiler.

- **Option A (03, 05, 07, 18).** With every `within` line deleted, the unpatched `bsc` compiles all six programs in probe 03 (`Billing` prints 6, `OrdersExtra` 1, `Zed.Outer` 42, `Odd` 1). The refusals are therefore produced by the patch. With the `within` line left in, the unpatched compiler fails with `names no module and no namespace` (the file does not parse), an unrelated error, so a bare "refused on HEAD" would be misleading; the deleted-line control is the right one and it is clean. The refusal text in 03 steps 1b, 3, 5, 05 last step, 07 step 4 is the new diagnostic (`not_visible_here`, `within_not_enclosing`), read in full, not an incidental error.
  - Weak spot: probe 03 step 4 (the namespace case) is refused by the **old** `module_not_imported` diagnostic, not by the new one, because v2 silently drops the swept child. It does not prove a visibility check, only that the drop happened; the brief says as much in section 2.
- **The admitted false positive (04/05).** Not hidden. The v1 binary (my `a1`) still refuses the original probe-04 input, and v2 (`a`) compiles that exact same input (`Acme/Dash` with `using Acme`, no Dash2) and prints 3. The author's second input moved the consumers to `Out/` because a consumer inside the swept namespace yields a pre-existing import-cycle error; I reproduced that cycle with Dash and Dash2 side by side (`05_first_attempt_import_cycle.out`). So the test input changed for a stated, real reason, and the fix does not depend on the change. I also ran v1 on the cleaned `Out/Dash` input: it still refuses (the same false positive), and v2 passes.
- **Hand-written .out files.** All `.out` files I diffed (01-14, 16, 18, 19, 20) match my re-runs except where noted; I saw no sign of hand editing. `03_v1_first_run.out` and `05_first_attempt_import_cycle.out`, `06_first_run_lines_shifted.out`, `06_second_run_outdir_differs.out` are kept, and the v1 text and the import-cycle text are exactly what the v1 binary and the cycle produce when I rebuild them. The final probes were not tuned to dodge them: the v1 binary is a patch in `probes/` and still shows its failure; the 06 baseline change (comment line) removes the line-shift artefact only, and the final `cmp` is on the same output directory name.
- **Probes that cannot fail.**
  - `17_within_tests.erl`: on the unpatched compiler 3 of 5 fail (sibling refused, parent/descendant, `within` not enclosing) and 2 pass. `no_within_means_anyone_may_name_it_test` passing is the intended control. **`acme_ordersextra_is_not_inside_acme_orders_test` asserts only `rc:1`, which the unpatched compiler also returns (the `within` line is a parse error)**, so that test cannot distinguish the segment-prefix rule from no feature. FLAG for the build-order step ("failing test first"). The test file also has no namespace-sweep test, though recommendation 5 asks for one.
  - Probe 18 pathless case: the author prints only the accepted result for `Acme.Orders.Evil`; with no negative control it could be passing because the check never runs on the pathless route. I added the control (`bs_check:check/2`, same World, `Self = Acme.Billing`): it **is** refused (`not_visible_here`), so the "declared name is trusted" claim is a real measurement.
  - Probe 16 timing: cannot show a difference by design; the brief says so.
- **Option B (08).** The `allows only` refusal exists only in the patched `b`; the unpatched compiler does not know `allow`. Fine.
- **Option A' (20).** Unpatched `bsc` compiles the same tree and prints 1; the patched one refuses with the `Internal` diagnostic. Not circular.

## 4. "A caller-side allow line binds nothing because the author of the caller can delete it" (probe 08)

Mixed. **Measured:** step 4 shows that with the `allow` line deleted the module compiles, and step 3 shows the line refuses while present. **Argued:** that the party who writes the caller is the one who deletes the line, and that this is the same party ticket 24 worries about, comes from ticket 24's premise, which the brief itself says was not reproduced (no agent was run). In the script the deletion is done by `sed`, so it demonstrates only that the language has no lock on the file, not that an agent would do it.

The comparison is also asymmetric: probe 07 step 7 shows that under Option A the agent can equally make the sibling compile by editing the callee's `within` line, and the brief concedes this in section 6, limit 1. The surviving difference (one file edited is the callee's, where a reviewer or a different owner might see it) is again an argument, not something probe 08 measures. Option B's remaining merit is for a callee in an unmodifiable dependency, which the brief concedes.

## Verdict

PASS: citations (stale ones are stale as stated), patch sizes, eunit counts (1305/4 ambient, 1309 and 1314 utf8), probes 01-14/18-20 reproduce, byte-identical beam, Go/Rust/Gleam/Elixir/Erlang survey outputs, the five-passes-per-module claim, refusals are not circular.
FLAG: (1) the "under 50 ms" bound is not firm (35-75 ms over six runs); (2) `acme_ordersextra` test passes vacuously on the unpatched compiler; (3) probe 03 step 4 is refused by an old diagnostic, so it shows the drop, not a check; (4) the probe-08 claim is an argument resting on ticket 24's unreproduced premise, and the same escape exists in A; (5) Elm and C# unverified, Gleam only at 1.12.0; (6) A' rename cost and group-vs-list drift remain reasoning, as the brief says.

**Safe to rely on: yes, with caveats** (the direction question and the A vs A' choice are not settled by measurements, and the cost figure should be quoted as "negligible, not measurable", not "under 50 ms").
