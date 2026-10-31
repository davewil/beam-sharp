# Verification of the ticket-60 decision brief

Method: probes copied to a fresh /tmp dir (/tmp/ver60/probes), run there with TMPDIR pointed at a separate data dir,
using each probe's documented command (p2 with N=100, 1000, 3000). Mutants made as sed edits of the copies in
/tmp/ver60/mut. Nothing in the brief or probes was edited. OTP 25, Elixir 1.14.0.

## 1. Re-run versus saved .out

All 8 invocations exited 0 and printed the "ASSERTIONS HELD" / no-FAIL path. Semantic content identical to the saved .out
for p1, p2 (all three N), p2b, p3, p4 (counts 508/5106/51045 edges and 9/108/1048 violations reproduce exactly), p5, p6.
Only numbers that differ (timings):

| probe | saved | fresh |
|---|---|---|
| p2 N=3000 add_directory / query | 446 ms / 46 ms | 587 ms / 104 ms |
| p2 N=3000 erlc | 4863 ms | 4236 ms |
| p4 EDGE 10001 / SITE 10001 | 276 ms / 3803 ms | 237 ms / 3693 ms |
| p5 read-back | 8.0 us | 5.9 us (a second fresh run during mutation gave 8.0) |
| p6 caller-check ratio | 2.7x | 2.0x (2.1x on a later run) |

p5 byte sizes (799.6 / +32.0 / +248.0) are deterministic and reproduced.
The p2 N=3000 xref numbers varied by 30 to 120 percent between runs, so C4 as a single run is only an ordering.

## 2. Per-probe verdict (execution, circularity, mutation)

- **p1 PASS.** Assertions compare to observed R1/R2 (`pub`, `{'EXIT',{undef,_}}`), not to constants the probe produced.
  Mutants: exporting `hidden/0` in the callee, and changing the expected value, both went red (crash, rc 127).
  Weak spot: the source scan (C2) is printed, not asserted, so a scan that matched nothing would still print "ASSERTIONS HELD".
  I confirmed independently that the single hit (beam_ssa_pre_codegen.erl:27) is the comment "optimization-friendly".
  The scan covers only `src/*.erl` of five apps and one regex, as the brief says.
- **p2 PASS.** Expected set comes from the generator's recorded plants; Found comes from xref `ME` plus an Erlang filter.
  Mutants: `same_group` forced true gives found=0 and FAIL (rc 1); generator not emitting the violating call gives
  found=1 vs planted=10 and FAIL. The "native-language" `||` query is printed only (11 edges), never asserted. It is
  consistent with 10 own-group callers plus 1 planted, but the pass/fail rests on the Erlang-side filter (a group-token
  compare), not on a path prefix and not on xref's `||`. Brief wording "with a prefix filter" slightly overstates this.
- **p2b PASS.** Mutant compiling both runs with debug_info gives edges 1/1 and FAIL. I also confirmed the brief's
  side claim: with `warnings,false` set (as p2 does) the "Skipping" lines vanish and edges stay 0.
- **p3 PASS for C6/C7, with one misleading line.** Assertions are on observed values. The diagnostics capture is not
  vacuous: a mutant adding an unused variable made `diags` non-empty (an Elixir warning string) and tripped `"" = diags`.
  Changing `recompute` to `x*3` tripped the `{42,1}` match. Flag: the `fetch_docs` branch substitutes a hard-coded
  `{:docs_v1,0,:elixir,"",:none,%{},[]}` on error, so the printed "moduledoc marker: {:none, 0}" is synthetic, and the
  final line "Elixir hides from docs (convention)" is printed unconditionally and is not established by anything run
  (the brief correctly marks C8 UNPROBED; the probe's success message overclaims). Not CIRCULAR for the claims actually
  cited, since nothing is asserted on that synthetic value.
- **p4 PASS.** Truth (token-list prefix) is written independently of the checkers (binary segment-boundary match).
  Mutants: removing the boundary test gives mismatch on EDGE and SITE, Spy unflagged, FAIL. Making the "naive" mutant
  use the correct function leaves "agrees with truth" true and FAIL (so the oracle can fail). Extra check: naive-prefix
  misses 1 (N=101, Spy only), 4 (N=1001) and 5 (N=10001) true violations; excluding Spy, 0 / 3 / 4. So the
  Shop.G10-vs-Shop.G1 failure is real in the generated data at N>=1000 (none at N=101, which has only 5 groups), and the
  brief's statement is supported. Limits: SITE is a generic abstract-form walk over synthetic forms with 40 identical
  calls per module and does not model the real checker (the brief says so); the SITE vs EDGE comparison is
  apples-to-oranges by design and is labelled as an upper bound.
- **p5 PASS.** Mutant dropping the module-level attribute trips "size ordering unexpected" FAIL. Bytes are
  deterministic. The attribute is a hand-built Erlang form `bs_internal_to`, not what bsc would emit.
- **p6 PASS.** Mutant putting `caller_tail` in a non-tail position (`{x,X}`) printed tail=true and FAIL. (A first mutant
  `X = f(), X` stayed red-free because the Erlang compiler turns it back into a tail call; that is the compiler, not a
  probe defect.) The timing ratio is not asserted and is volatile.
- **run_all.sh:** not separately run (each probe command was run directly); its comment "each exits non-zero if its
  own assertions fail" is true for p1, p2, p2b, p4, p5, p6; p3 failures surface as an uncaught MatchError (also non-zero
  in principle; my p3 mutants printed the exception, and the `tail` in my pipeline hid the rc).

No probe is CIRCULAR. No fallback converts a failing observation into a pass; the only synthetic value is p3's fetch_docs stub.

## 3. Claims table and citations

Established by their probe: C1, C3, C5, C6, C7, C9, C10 (the numbers), C12, C13 (tail blindness; the "2.7x" is a single
volatile figure, fresh runs gave 2.0 to 2.1x). C2 holds as bounded by the regex (hit confirmed to be a comment).
C8, C11, C22 are honestly marked unprobed/unmeasured. C14, C15, C18, C19, C23 are marked inherited.

Misstated or imprecise:
1. **Wrong line cite:** brief section 3 says `visibility -> 'public' | 'private'` is at `bs_parser.yrl:262-268` "per F12".
   F12 contains no such citation, and lines 262-268 of bs_parser.yrl are `type_prim` rules. The rule is at
   bs_parser.yrl:325-326 (used at :310 and :322).
2. **C18 / "five readers test `=:= public`":** repeated from F12's amendment, but the code does not bear it out.
   `=:= public` appears at bs_check.erl:362, :373, bs_emit.erl:140 (and a comment at bs_api.erl:149); `=/= public`
   (still closed-by-default in effect) appears at bs_check.erl:296 and :476 (`private_of/1`). The safety conclusion
   (a new value is treated as non-public) holds either way, but the "all readers test `=:= public`" description is
   stale. Marked inherited, so mild.
3. **`import_env` / `add_import` lines:** brief gives `bs_check.erl:497`, `:494-497`, `:494-509`. Actual: `add_import/7`
   starts at :494, the `maps:is_key(M, World)` branch is :495-497. Cites for :3850, :4391, :4470, :475-479 and
   bsc.erl:227-239 are correct. The "~482" comment cite is accurate (:481-ish comment "Import tables use modules checked
   in this invocation").
4. **C21:** `grep unclassified compiler/src` finds more than the two cited sites (bs_diag.erl:75, :77, :708, :2162, :2167
   as well as bs_api.erl:280, bsc.erl:897), all the same diagnostic tag, so the conclusion stands but "only" at two
   locations is under-counted.
5. **C4/C10 timing:** quoted as measured; fresh runs differ by up to ~2x for xref at N=3000 (see table). The brief
   calls them single runs, so this is disclosed.
6. **C13 "~2.7x":** not reproduced (2.0 to 2.1x on two fresh runs); brief says "indicative only".
7. Brief's "p4 EDGE ... 2.4 ms at 100 modules": saved .out says 2.43 ms; fresh 3.0 ms. Fine as stated.
8. C20 dates check: ticket 24 resolved 2026-08-13, F12 done/amended 2026-08-17. Confirmed. The ticket-22 quote about
   `RecomputeTotal/1` landing `unclassified` is present (22-how-opinionated.md:393).

Nothing in the brief is stated as measured that was in fact unexecuted; the "UNPROBED"/"NOT MEASURED"/"INHERITED"
labels are accurate. I did not independently verify the external-language claims (Rust, Scala, Java, Gleam, Elm, C#),
which the brief labels unprobed.

## 4. Verdict

PASS with minor corrections. All seven probe scripts reproduce semantically, every assertion-bearing probe goes red
under a targeted mutant, none is circular. Corrections needed before relying on the brief: fix the bs_parser.yrl
citation (325-326), soften "five readers test `=:= public`" (two readers use `=/= public`), shift the add_import cite
to :494-497, note that p3's closing message and moduledoc line are not evidence, and treat the 2.7x and p2 timing
figures as roughly 2x-volatile.
