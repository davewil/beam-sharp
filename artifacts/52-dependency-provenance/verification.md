# Verification of brief 52 (dependency provenance)

Verifier: independent re-run, 2026-10-11. Env: OTP 29 (kernel-11.0.4, erts-17.1), Elixir 1.20.4, Gleam 1.19.1. Repo HEAD is 6887dd0; the brief says d8a3bd8, but `git diff d8a3bd8 HEAD -- compiler/src` is empty, so the compiler under test is the same. Re-run copy: `$S/verify52/` (probes, prototype, my own scripts in `mine/`). brief.md was not modified. Nothing committed.

## Overall verdict: VERIFIED WITH CORRECTIONS

Every probe reproduced except for timing noise and path strings. All four headline refutations re-tested with independently written scripts. The prototype's absence detection is not circular. The corrections are about the prototype's Option A/B ownership check, which the brief under-reports, and a few smaller points.

## 1. Per-probe verdict (fresh `run-all.sh`, fixtures and `_proto` rebuilt from scratch, diffed against committed .out with scratchpad paths normalised)

| Probe | Verdict | Diff |
|---|---|---|
| p1_undef_only_at_call_site | reproduces | only an absolute path in one line |
| p2_presence | reproduces | identical |
| p2b_modes_and_transitive | reproduces | only the .app read cost: 339.5 us vs 278.3 us (see section 2) |
| p3a_elixir_mix | reproduces | path strings only |
| p3b_erlang | reproduces | dialyzer elapsed time only |
| p3c_gleam | reproduces | "Compiled in 0.44s" vs 0.52s, paths |
| p3d_elm | reproduces | identical |
| p4_derivable | reproduces | identical |
| p5_prototype | reproduces | identical (all A/B/C/Kw runs, --api, bs_deps attribute) |
| m1_check_cost | reproduces in shape, numbers differ by load | cold which 21.6 vs 20.2 us, lib_dir 12.1 vs 11.0, app_load 209.6 vs 186.8 (other jobs were running on the box) |
| m2_beam_size | reproduces | the V1/V2/V4 deltas (+176/+64/+308 debug_info) and Many (+604/+60) are identical. V3 Dep debug_info delta is +212, committed +216. Baseline beam sizes shift with output path length (1588 B vs 1696 B). |
| m3_pipeline_cost | reproduces | warm median 526 us vs 535; whole file_to_dir median 7.6 ms vs 7.1 ms |
| m4_cli_wall | reproduces in shape | stock 435 ms vs 481, prototype 451/454; ranges overlap, brief's "not resolvable at CLI level" stands |

No probe failed to run.

## 2. Numbers and citations

- 20 us `code:which` cold: 5 runs of m1 gave cold `which` medians 23.0, 22.8, 22.9, 24.5, 24.1 us (plus 21.6 from run-all). **Brief's 20.2 is the low end; spread over six runs is 20 to 24.5 us** under shared load. Cold `where_is_file`: 5.7, 6.0, 6.4, 6.4, 6.9, 6.3 us (brief 4.7). Claim "about 20 us" holds; "4.7 us" is a fast sample, 5 to 7 us is more representative.
- 278 us `.app` read: re-run gave 339.5 us (one run). Treat as 280 to 340 us. Brief's figure is a single sample and should say so.
- m3 warm check, 5 further runs: 508, 556, 502, 502, 528 us (brief 0.54 ms; spread 0.50 to 0.56). Whole `file_to_dir` median over those runs: 7.7, 9.0, 7.6, 9.5, 8.2 ms, so the committed 7.1 ms is optimistic by 10 to 30 percent on this box. The conclusion (the check is about 6 to 7 percent of compile) holds.
- 60 B vs 176 to 604 B: reproduced exactly (V2 +64 debug_info, +40 without; V1 +176 to +604).
- yecc conflicts: I ran `yecc:file` on the original `compiler/src/bs_parser.yrl` and on the patched copy. Both print `conflicts: 6 shift/reduce, 0 reduce/reduce`. Confirmed.
- Ticket 22 line 89: `**1. There is no attribute grammar, and there never has been.**` Exact.
- Citations in `kernel-11.0.4/src/code_server.erl` (confirmed that this is the installed file, under the conda OTP 29): 643-652 is `get_name` / `get_name_from_splitted` (correct); 1036-1039 is `do_dir(_Root,{lib_dir,Name},NameDb)` returning `{error, bad_name}` (correct); 141-151 is `get_user_lib_dirs_1`, "Only add paths trailing with ./ebin" (correct); 104-114 is the `IPath = case Mode of interactive` block (correct); 843-870 covers `insert_name` / `archive_subdirs` (correct, loosely). `dialyzer_cl.erl:739` has "Unknown functions:" and `systools_make.erl:638` returns `{error,{not_found, Name ++ ".app"}}`. No mis-cited lines found.

## 3. Independent re-tests of the headline refutations (my scripts, `mine/`)

- (a) ta.sh: own module `zzmod` in `zzapp`; compile on `ERL_LIBS=libB` prints nothing, exit 0, writes `T.abstr` and `T.beam`. Run: `crashed: error:undef`, exit 1. Same program on libA: 101. Function that touches nothing foreign on libB: 2. **Confirmed.**
- (b) tb.escript, my fixtures. Dir `noapp/ebin` with beam, no `.app`: `lib_dir(noapp)` returns the dir (false positive), `where_is_file("noapp.app")` returns non_existing. Dir `diffname/ebin` holding app `trueapp`: `lib_dir(trueapp)` is `{error,bad_name}` (false negative), `lib_dir(diffname)` returns the dir, `where_is_file("trueapp.app")` finds it and `application:load(trueapp)` is ok. **Wrong in both directions, confirmed.**
- (c) tc.sh: a Gleam project with no dependencies and `@external(erlang, "nonexistent_zz", "f")`: `gleam build` exit 0 ("Compiled in 0.44s"), no warning; `gleam run` fails with "A function was called but it did not exist ... nonexistent_zz.f". **Confirmed.**
- (d) td.sh: mix project calling `Zzz.Absent.run(x)`: `warning: Zzz.Absent.run/1 is undefined (module Zzz.Absent is not available or is yet to be defined)`, then `Generated mx app`, exit 0. **Confirmed, a warning only.**

## 4. Circularity audit

Read `prototype/deps.patch` and `bs_deps_proto.erl`.

- Detection mechanism: option C calls `code:which(M)` on the `using` module; option A calls `code:where_is_file("<app>.app")` and then reads the owner from the `.app` beside the beam. Both query the compiling VM's code path, which is what `ERL_LIBS` shapes. "Machine 2" is a genuinely different `ERL_LIBS` (empty root), not a fixture trick like a renamed module. The check does detect absence for the stated reason.
- Fresh build, no stale ebin: `prototype/build.sh` does `rm -rf` of the output, copies compiler/src, applies the patch, runs leex and yecc, and `erlc`s. The ebin I used was built minutes before the runs. In both p5 and my own tp.sh, the **negative control is green and the absent case is red**: option C, module present: `101`, no warning; module absent: `bsc: warning: ... not on the code path` then `error:undef`. Option A, app present: `101`; app absent: `bsc: error: application zzapp ... not on the code path`.
- Fixture fidelity: `exdep` is a tiny mix-built app (`ExDep.shout` calls `String.upcase`), same `ebin/*.beam` + `.app` layout as a hex package, but without a real dependency tree. The brief says so in section 7. Req's real situation (an Elixir module present, its own dependency app missing) is only exercised at run time (machine 3 in p1). The prototype check would **not** catch it: `exdep.app` and `Elixir.ExDep` are both present, and only `elixir` is missing. The brief states that A "would not have caught that", so this is disclosed. But one detail: machine 3's `error:undef` is printed without a stack, so the attribution to the missing `elixir` app (rather than any other cause) is an inference from `ExDep.shout` calling `String.upcase` (confirmed in the fixture source) and from p2b's transitive listing, not an observed module name.
- Extra scenarios the author did not run (tp.sh, `mine/w2`), patched compiler:

| Scenario | C (module only) | A (`in zzapp`) |
|---|---|---|
| module present, normal dir | `101`, no warning | `101` |
| absent | warning, then undef (red, correct) | error (red, correct) |
| app in dir `weirddir/` named differently | `101` | `101` (correct, ownership via sibling `.app`) |
| app inside an `.ez` archive on ERL_LIBS | `101` (correct) | **false error: "module :zzmod belongs to application `unknown`, not `zzapp`"** |
| module on `-pa`, no `.app`, app declared | `101` (correct) | error "application not on the code path" (arguably right, but the module is loadable) |
| two `.app` files in one ebin | n/a | **false error "belongs to application `unknown`"** |

  Raw primitives for the archive case: `code:which(zzmod)` = `.../zzapp-1.ez/zzapp-1/ebin/zzmod.beam`, `where_is_file("zzapp.app")` finds it, `lib_dir(zzapp)` = `.../zzapp-1`. So `where_is_file` and `which` work with archives; the failure is the prototype's `owner/1` (`filelib:wildcard` cannot list inside a zip). This confirms the recommendation to use `where_is_file` and also exposes that Option A's "ownership" step is the fragile part.

Flagged probes: none circular or manufactured. The one weak spot is the m1/m3/m4 timing set, which depends on a shared machine.

## 5. Corrections for the orchestrator (brief.md untouched)

1. Section 7 says the `.ez` case "was not tested". Add the result: `which` and `where_is_file` both work inside an archive; the prototype's owner-by-`.app`-listing (used by Option A's wrong-owner check and all of Option B) returns `unknown` for archives and for an ebin with two `.app` files, producing false errors. This strengthens the recommendation of C but is a defect the brief should list against A/B.
2. Section 5A "Evidence" says the ownership check "catches a wrong name the module-only check cannot". True, but also state it can raise false errors in the two cases above.
3. Section 4.1 timings: cold `where_is_file` 4.7 us and `which` 20.2 us are the fast end; six runs gave 5.7 to 6.9 and 20 to 24.5 us. The `.app` read of 278 us was 339.5 us in the re-run. Whole `file_to_dir` median 7.1 ms was 7.6 to 9.5 ms in five more runs. No conclusion changes; quote ranges.
4. Section 2a: the machine-3 `crashed: error:undef` has no module name, so the claim that the missing module is `elixir` is an inference. Say "inferred".
5. Header: repo rev. HEAD is now 6887dd0 (d8a3bd8 plus brief-only commits; `compiler/src` identical). Fine to keep d8a3bd8, but say compiler/src is identical to HEAD.
6. p2b's "interactive VM" section prints `mode=error`, `lib_dir(exdep)="exdep"` and `which="Elixir.ExDep.beam"` (relative strings), because it runs inside an escript. Only the embedded-mode section is meaningful. The brief uses only the embedded results, so no claim is wrong, but the .out is confusing to a reader.
7. m4's wall-clock rows cannot support any claim about the check's cost (ranges overlap fully); the brief already says so.
