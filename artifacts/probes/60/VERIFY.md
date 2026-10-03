# Verifier report: brief 60 (independent; copy run in scratchpad/v60, original outputs untouched)

Method: copied probes/60 to scratch, retargeted W paths for 03/04, rebuilt base/proto/proto2 from compiler/src
(unchanged since 5133d97), re-ran every run.sh, diffed against captured run.out.

## Reproduction (probe by probe)
- 01, 02, 03 (all 12 cases x 3 builds), 07, 09, 11: byte-identical. REPRODUCED.
- 05 gleam: identical except compile times. 08 erlang: identical except an absolute path. 10, 12: identical except commit (HEAD is now b912842; compiler/ and .bs corpus unchanged). 06 elm: identical, 403 ProxyConnectException recorded, not bypassed. REPRODUCED / UNMEASURED as labelled.
- 04 timing (2 more x 12 runs x 3 builds): ORDERING reproduces, but the size does not match the brief's framing.
  In-VM medians (ms): base 1298/1265, v1 1360/1405, v1+v2 1573/1546 (author: 1288/1322/1378). v1+v2 is the slowest
  in all 3 sessions, +7% (author) to +22% (mine) over base. The brief says "below the noise ... not resolved";
  that is defensible for v1 (+5-11%, overlapping) but v2 looks real, about +250 ms in mine.
- micro: 1.76 us/call (brief 1.6-1.8), v2 filter 288 us/module at 200 (brief 286), 1497 us at 1000 (brief 1654). REPRODUCED.

## Findings against the brief
1. UNSUPPORTED (understated): "x201 modules = 57 ms per compile" assumes one imported_types call per module.
   type_env (which calls imported_types) is reached from four checker functions (bs_check.erl:326 declared, :371 polys_of,
   :384 types_of, :1548 implements_of). 4 x 58 ms ~ 230 ms matches the wall-clock gap I measured. The multiplier was
   not counted; the "1.7 s at 1001 modules" extrapolation inherits it. Direction of the brief's conclusion (v2 is O(modules x world)) stands.
2. Attribution: the "second site that must agree..." quote is ticket 40 line 298-299, not F12's own text (F12 line 113 has the
   private-versus-absent point). Brief says "F12 / ticket 40 §3": slightly loose, not wrong.
3. "Notes, last section" quote: the "Not owed a decision soon" line is ticket 60 line 62. OK.

## Circularity hunt: none found
- Patch (+33/-1 and +6/-3) read in full: only the Internal rule, no special-casing of fixture names.
- Accepted/refused pairs differ only in the property: Orders3 vs Reports3 differ only in module name; Peeker vs
  Billing/Reconcile vs Billing differ only in module name; Wide vs Wide2 differ in callee (Core vs Internal.Store).
- Failed attempts (03 #1-4, 01, 02, 07, 08) were changed for B# syntax / script mistakes; expectations did not move.
  Attempt 5 -> 6 added cases, did not edit any. Attempt 3 outcome (Orders2 accepted) is kept and drove v2.
- Compile-cost comparison is same generated tree, same sources, base vs patched, alternating runs: like with like.
- Go independent check holds (spy refused; parent, descendant, public face build).

## Claim verdicts
- add_module_import/5 :407-425 stale -> now /3 at bs_check.erl:511, caller add_import/7 :497 has Self: REPRODUCED.
- Ticket 41 §5 "SUB-MODULE, source-only" (line 490) vs F15.11 (own module): REPRODUCED.
- Corpus: 161 .bs files, 113 names, 7 using edges (I counted the non-foreign `using` lines by grep: 7), 4 modules named, no Internal dir: REPRODUCED.
- BEAM one export table / one entry label / no caller check: REPRODUCED.
- private_function diagnostic text and the `using`-is-dependency-list refusal: REPRODUCED.
- Option A prototype results incl. v1 type-site hole and misleading refusals at the second door: REPRODUCED.
- Subtree limit (Reports3 accepted): REPRODUCED.
- Gleam not enforced (path dep only; Hex UNMEASURED as stated); docs omit hidden items: REPRODUCED.
- Elixir doc-only (Module doc line 186 verified; no .ex sources installed, as stated): REPRODUCED.
- Erlang export/xref/-ignore_xref: REPRODUCED.
- Go citations: pkg.go:1472 (disallowInternal), :1564 HasPathPrefix, findInternal :1579 "final internal element": REPRODUCED.
- Probe 12 reader lines (299, 364, 375, 478; bs_emit 141; yrl 308-324; imported_types :1305): REPRODUCED.
- Whole-tree cost "below the noise": PARTLY NOT REPRODUCED for v2 (see finding 1).
- Option B and C deltas: UNMEASURED, labelled so. Elm, C#: UNMEASURED, labelled so.

## Overall: SOUND, with one correction owed
No circular probe. Everything reproduces except the compile-cost framing: v2's real cost looks ~4x the per-module
micro estimate (multiple type_env calls per module), so "A costs under 0.1%" holds only for the `using` site.
