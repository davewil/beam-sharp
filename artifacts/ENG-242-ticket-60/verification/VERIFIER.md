# Verifier report: ticket 60 / ENG-242 brief

Toolchain: OTP 25.3, Elixir 1.14.0, Elm 0.19.3 (package site 403, as expected). I did not modify any author file. Reruns are the `*.rerun.out` files beside this one. I ran p5 with `SCRATCH` pointed at my own dir. p6 and p7 hard-code the author's scratch path, so I ran copies with that line changed to `S=$SCRATCH`. The scripts are otherwise identical, and the copies are in my scratchpad.

## Per-probe table

| probe | reproduced | notes |
|---|---|---|
| p1 xref | yes, byte-identical | The `other_thing` edge is present despite `-ignore_xref`. 1 violation, 1 allowed caller. The "H1 check" is only `lists:member(other_thing, Viol)`, which tests the author's own filter. What proves "no permission needed" is that `erlc` accepted the module. It was never run, but the claim is trivially true. The p1 run1 failure (no `debug_info`) was a real setup fault. The fix, `+debug_info`, repaired the probe and not the expectation. |
| p2 Elixir hidden | yes, identical | `Kernel.Utils.announce_struct/1` returns `:ok` with no error, and both modules report `:hidden`. The brief says only that the docs chunk and the call succeed, which is accurate. I could not inspect the "rewritten twice" history, and the final script is sound. |
| p3 tracer | yes for the three correctness lines. Timing holds only in a solo run. | Inside is `:ok`, outside is rejected with the same message, and outside with no tracer is `:ok`. Timing: my first run overlapped with p1, p2 and p4 and read N=100 1.31 s vs 1.70 s (+30%). A solo rerun (`rerun2_solo`) read N=100 1.33 s vs 1.39 s (+5%) and N=1000 16.77 s vs 16.56 s (-1%). The recorded absolute times (2.26 s, 22.2 s) are about 1.4x slower than mine, which is VM variance. "Inside noise" holds, but the noise is about ±5% to 30% on a 1.3 s run. The probe is blind to a sub-millisecond check, since `Code.compile_string` dominates. It shows nothing about B# (the brief says so). |
| p4 Elm | yes, inconclusive (403) | The brief labels it inconclusive and puts Elm in the UNVERIFIED column, which is honest. The script header says it "exits 2" on an unreachable package site, but it exits 0 and prints INCONCLUSIVE. Elm also prints "Dependencies ready!" right after the 403. Cosmetic. |
| p5 checker site | yes for H1-H3, identical | H4 timings: base/dirA ns per import were 14198/13010 at N=100, 124277/140883 at N=1000, 2.08M/2.13M at N=10000. The recorded numbers were 16128/20873, 183700/159848, 2.69M/3.01M. The brief's "about 16 µs at N=100 and 2.7 ms at N=10 000" is within about 15-30% of my numbers (14 µs and 2.1 ms). The sign of the base-vs-patched delta flips between runs (mine: -8%, +13%, +2%), so the brief is right that it is noise. See "Circularity" for what H2 and H3 can and cannot show. |
| p6 check alone | yes | 459 ns at N=100 and 477 ns at N=10 000 (recorded 506 and 481). The N-independence claim holds. The empty loop is 2-3 ns. This measures the best case, an insider matching the first of 2 prefixes. The reject path and longer lists are untimed. |
| p7 namespace leak | yes, identical | The naive patch leaks `Shop.Orders` through `using Shop`. With children filtered, the outsider gets `Shop.Reports` only and the insider gets both. |

## Patched checker: diff against `compiler/src/bs_check.erl`

I diffed all variants against the real file at HEAD.
- `bs_check_a` differs by 3 hunks: the `-module` line, one line at 497 (the `true -> ...` arm), and an 11-line `visible_to/4` appended at the end. Nothing else differs.
- `bs_check_b` differs the same way (`may_use/4`).
- `bs_check_c` is `a` plus one line at 504 and a `visible_p/3` helper.

The patch is minimal and does what the brief says. The "cost" comparison uses one harness, `import_env/4`, on the same hand-built Worlds with the same patched module name. It is fair in construction. It is also uninformative, because `import_env` rebuilds three whole-World tables on every call and that swamps a 0.5 µs check (about 3% of an import at N=100). Only p6's isolated number carries the cost claim, and p6 times the author's own function directly.

## Circularity and weak-probe flags

1. **p5 H2 and H3 are unit tests of the author's own patch.** The patch rejects when the prefix is absent from a list that the fixture put in the World, so the expected output follows from the code by construction. They show only that the hook site at line 497 is reachable and that nothing in `import_env` interferes. The only fact about the real checker is the H1 control (unpatched accepts both). H3 (option 3) also hand-places `may_use` in the World entry of `Self`. In the real checker the caller's declarations come from `Decls`, not from the World entry for `Self`, so option 3's "same site" claim is untested.
2. **p7 H1 is a hypothesis written after reading `add_import`'s two branches.** It confirms a visible code path and could not have failed unless the source read was wrong. That is fine as a regression demonstration, but it is not a discovery.
3. **p3's "outside rejected" proves nothing.** The tracer was written to raise on exactly that name. Only the timing carries information, and it is noise-limited.
4. **Fixed probes.** p1 run1, p4 run1, p5 run1 and run2, and p6 run1 are all genuine harness faults, and the fixes repaired the probes. Their failed `.out` files match the described defects. I saw no sign of a patched expectation. The p6 run1 versus final difference (5.9 µs vs 0.5 µs) really is interpreted `erl -eval` vs a compiled loop. I re-measured only the compiled one, and the brief's choice of the compiled loop is correct.
5. **MEASURED vs RECORDED labelling is mostly clean.** The `qualified_module` claim is correctly labelled RECORDED. But §1 states "using is the only way to name another module", and that is false for types (below).

## Wrong or overstated claims

- **FALSE: "`using` is the only way to name another module; one checkpoint covers qualified calls too."** `imported_types/2` (`bs_check.erl:1320ff`, `Full = ...`) adds every World module's types under their fully qualified names regardless of `using`. I confirmed it by running the checker: with `imported=[]` for `Other.X`, the type env still contains `'Shop.Orders.Order'`, and `Shop.Orders` carries `visible_to`. Ticket 73 and F44 §5 say a qualified type name works "anywhere". So a restricted module's types and records can be named from outside with no `using`, and a check at `add_import` does not cover that. Calls are covered by `qualified_module`/`require_imported` (`bs_check.erl:4557-4572`, which does require `imported`). Option 2's compiler-delta list (four items) is missing a type-environment filter. The "recommended option 2" cost is understated.
- **Overstated: the sixteenth-keyword "budget".** Ticket 22 (`22-how-opinionated.md:22`) says only that the `incomplete` marker is not built, so "the sixteenth keyword is not spent". Line 189 says the language "has taken the keyword twice already under exactly this pressure". There is no budget or cap. Soften the counterargument to "a keyword would be a third precedent". The brief's phrasing, "the thing ticket 22 closed to avoid spending", is not supported.
- **Imprecise: `bs_check.erl:509-520` and "reads only the callee's export set".** `add_module_import/3` runs 509-523 and also reads `types` from the Entry. The ticket's own claim of "export set only" is slightly out of date, and the brief repeats it. The ticket's `407-425` now points at `qualify_refs/2`, as the brief says.
- **Citations that check out:** `bs_check.erl:497-507` (`add_import`), `:491` (`import_env`'s table), `:587-589` (`children/2`, which ends at 590), `:4557-4572`, `F12` (amended private-by-default, 2026-08-17), and `F15` (directory is a module). The `RecomputeTotal` point is sound: ticket 24 §2 predates F12's default and says "every function is exported today". The brief's inference that the case has narrowed is valid and is its best insight.
- **Not addressed, though it bears on cost.** `import_env` has four callers, three of them in `lenient` mode (`exports_of`, `types_of`, `implements_of`, lines 322/368/381/1568). A `not_visible_to` raised in `add_import` would also fire during `--api` and producer passes, and the brief doesn't say what should happen there. A transitive leak is also unaddressed: a public type of a restricted module that appears in another module's exported signature.
- **No probe behind "I grepped 11 phrasings, no friction entry."** There is no saved command or hit list. My own grep found hits only in tickets 22, 24, 40, 41, 48, 60, F12 and research/48, and I found no friction entry asking for the feature either. The claim is plausible but unreproducible as written.
- **The brief's own admissions:** the real `bsc` was never run, and the checker was driven through hand-built Worlds, so parse, diagnostics, `--api` and multi-file behaviour are untested. This is disclosed in §6.

## Verdict

**Stand (reproduced):** p1, p2 and p7 results; p5 H1 (unpatched accepts both); p5 H2 and H3 as demonstrations of a hook, but not as validation; p6's cost of about 0.5 µs, independent of N, within noise (459-506 ns); p3's correctness lines and "no measurable tracer overhead" on a solo run; the minimal patch; the namespace-import leak (p7); the F12/F15/ticket 24 reading of the consumer; Elm and Gleam correctly marked UNVERIFIED.

**Must be softened or fixed:**
1. Drop or correct "`using` is the only way to name another module". It is false for types (fully qualified type names bypass `using`). Add a type-env filter to option 2's compiler delta, and re-read the "namespace filter is the only extra" language.
2. Reword the sixteenth-keyword counterargument (no budget exists, only a precedent argument).
3. Describe p5 H2 and H3 as demonstrating the hook site and not as verification of the design. The `may_use` model does not reflect where the real caller list would live.
4. The p3 overhead numbers need the caveat that noise exceeds the effect (I saw +30% in a contended run and +5% in a solo one). Say it shows only that a tracer is not obviously expensive.
5. Mention the lenient-mode callers and transitive type leakage as untested.
6. Replace the unreproducible grep claim with the actual command and hits, or say it is unreproducible.

The recommendation (option 1, build nothing now) is unaffected by these findings. If anything it is strengthened, since the missed type-name path makes option 2 costlier than stated.
