# Verification of brief 60 (which modules may name this one)

Verifier: independent re-run. The brief and probes were not edited. Re-run date 2026-10-02.
Repo HEAD during the run was `012d866`. The brief cites `0dddf8b`. `git diff --stat 0dddf8b HEAD -- compiler` is empty, so every compiler line number is unchanged.

## 1. Re-run of every probe

`bash artifacts/probes/60/run.sh` exited 0 in 64 s. Output was compared row by row with the evidence table.

| Row | Brief says | My re-run | Verdict |
|---|---|---|---|
| E1 | `{42,{secret,1},7}`, erlc silent | identical. Also `erlc +warnings_as_errors` on both files gives rc 0 | AGREE |
| E2 | `[outsider]` flagged, needs `+debug_info`, else `unknown_constant` | identical. Without debug_info, `add_directory` returns `{ok,[]}` and `analyze` returns `{error,xref_compiler,{unknown_constant,"priv_mod"}}` | AGREE |
| E3 | `use.beam` built, erlc silent, xref `[{{use,g,0},{dep,f,0}}]` | identical | AGREE |
| E4 | `Anywhere.g(): :reachable` | identical | AGREE |
| E5 | tracer refuses `Shop.Reports`, allows Orders and Orders.Apply, control compiles | identical message `lib_bad/b.ex:2: Shop.Reports may not name Shop.Orders.Internal.Helper.recompute/1 (internal to Shop.Orders)`. `lib_ok` compiles, no-tracer control prints `r(2)=4` | AGREE |
| E6 | dynamic `apply` compiles under the tracer | identical (`COMPILED OK: 2 file(s)`) | AGREE |
| E7 | 30,000 events, 3 runs each, difference inside noise | plain 9127/9127/8872 ms, traced 9003/9115/9259 ms. The numbers differ from the brief's 8282-9153 but the conclusion holds. I counted events with a separate counting tracer on a regenerated corpus: `events=30000` exactly | AGREE |
| E8 | Gleam builds, rc 0 | `Compiled in 0.33s`, rc=0 | AGREE |
| E9 | `@internal` fn call builds, rc 0 | rc=0 | AGREE |
| E10 | interface lists `['lib','lib/other']`, functions `['total']` | identical | AGREE |
| E11 | `lib@internal@secret:recompute(21)` returns 42 | `42` | AGREE |
| Elm | not run | `NOT RUN: package fetch refused` (proxy 403). `run.sh` exits 0 anyway, so the top-level exit 0 does not mean the Elm claim passed | AGREE (the brief says this) |

## 2. Circularity hunt

**E5 and E6 (Elixir tracer) — CONFIRMED, not circular.** `lib_bad/a.ex` is byte-identical to `lib_ok/a.ex`, so the controls differ only in `b.ex`. I ran my own falsification attempts in a scratch copy:
- Rename the caller to `Shop.Orders.Reports` and keep everything else. It compiles. The tested variable alone flips the result.
- Rename the caller to `Shop.OrdersX` (a string-prefix trap). It is refused, so the check compares whole segments and not string prefixes.
- Mutate the tracer so the prefix test is always true. `lib_bad` then compiles, so the probe goes red under that mutation.
- Mutate the tracer's allowed parent to `Shop.Billing`. `lib_ok` is then refused (`Shop.Orders may not name ... internal to Billing`). The allow-list drives the outcome.
- `alias Helper` followed by `Helper.recompute` is refused. `import ...Helper` followed by `recompute(x)` is refused. Both forms are caught, which makes E6's "only dynamic calls escape" more believable.

**E7 — CONFIRMED.** The event count was not asserted by the probe. I verified it independently: exactly 30,000 `remote_function` events for `Internal.H.f/1`. The traced run therefore does real work on every event. Caveat: the tracer is a trivial string split, and the claim is about Elixir 1.14's tracer only.

**Gleam E8-E11 — CONFIRMED, not a setup flaw.**
- *Path dep in the same project.* I rebuilt with `lib` and `app` in two separate sibling directories (`sep1/lib`, `sep2/app`, dependency `../../sep1/lib`). `gleam build` gave rc 0. `gleam check` gave rc 0. `gleam run -m app_bad` gave rc 0 and ran.
- *Wrong key or silent failure.* I set `internal_modules = 5` in `lib/gleam.toml` and `gleam build` failed with a config parse error. The key is therefore read and validated. Build output contains no warnings and no errors.
- *Does the import really happen?* `app_bad.beam` is in `app/ebin`, and `lib@internal@secret.beam` is in `lib/ebin`. Running `app_bad:main()` returns 6 (`recompute(3)`).
- *Default configuration.* I deleted `internal_modules` entirely so the default `<pkg>/internal` applies. It still builds, rc 0. This is a stricter-looking configuration that still shows no refusal. The brief's section 7 says the default was not tested. My run partly closes that gap, because the module `lib/internal/secret` sits under the default `lib/internal` path too. This is my own check, not the probe's.
- *Not tested, UNVERIFIABLE here:* a hex-published or git dependency instead of a path dependency. There is no network. A path dependency could in principle be treated as same-workspace. I found no evidence it is, but I cannot rule it out. The brief's wording "cross-package" is accurate for a path dependency and is not shown for a registry package.
- The probe asserts the measured result (`rc -eq 0`), which is honest. It fails loudly if Gleam starts refusing.

**Erlang E1-E3 — CONFIRMED.**
- xref control: I added a `shop_orders` module that calls `priv_mod:helper()`. xref returned `[outsider,shop_orders]`, so xref reports every caller. Flagging `outsider` is the allow-list's doing and is not hard-wired. The probe's allow-list contains a non-existent `shop_orders`, which is harmless.
- Opaque forging: `outsider.erl` builds a literal `{secret,1}` and reads `element(2, priv_mod:mk())`. erlc stays silent even with `+warnings_as_errors`. Dialyzer is not installed, so what Dialyzer would say is not measured, and the brief does not claim it was.

## 3. Citations (all opened)

- `bs_check.erl:490-526` (`add_import/7`, `add_module_import/3`, `add_namespace_import/3`): CORRECT.
- `bs_check.erl:504-517`: CORRECT.
- `bs_check.erl:497` (the `unknown_module` error): CORRECT.
- `bs_check.erl:318, 363, 376, 1540` (`import_env` callers): CORRECT, all four pass `Self`.
- `bs_check.erl:459` (`reachable/2`): CORRECT.
- `bs_check.erl:582-584` (`children/2`): CORRECT.
- `bs_check.erl:3646-3649`, `4188-4192` (`private_function`): CORRECT.
- `bs_check.erl:4332-4360`, `qualified_module` and `require_imported`: CORRECT. The quoted comment "Qualified calls still require a `using` entry" is verbatim.
- `bs_diag.erl:358-360`: CORRECT. `bsc.erl:227` and `:293` (World entries): CORRECT, checked at 0dddf8b.
- Ticket 60 and ticket 22 line `bs_check.erl:407-425` at `0b761f6`: confirmed present in both tickets. At HEAD, lines 407-425 are `qualify_refs`, so the brief's correction is right.
- Ticket 22 "MEASUREMENT PASS", item 3, "record tag from the **qualified** module path (built as F3)": CORRECT, line 120.
- Ticket 40 §1 decisions entry, "tag mints from the qualified name": CORRECT, at lines 460 and 530.
- Ticket 18 "a BEAM function has one entry label": CORRECT, in its Decisions entry (line 975, entry starts at 937).
- Ticket 24 §2 `RecomputeTotal/1` unclassified, "every function in an aggregate is exported today": CORRECT. Ticket 24 is resolved 2026-08-13.
- F12 (done 2026-08-17, private default) and F15 (`Shop/Orders` emits one `'Shop.Orders'.beam`, line 38): CORRECT. F15 bolds "one" and the brief drops the markup, which is cosmetic.
- `grep unclassified` hits only tickets 22, 24, 60 and F47: CONFIRMED. F47 uses it as a diagnostic tag.

I found no wrong citation.

## 4. "Cited, not re-run" labelling

E12-E15 and E18 are labelled "cited, not re-run". E16 and E17 are labelled "cited". Section 4 labels the 15-line delta as an estimate. Section 7 repeats these limits. Nothing in this class is presented as measured.

Nits, none of which break a claim:
- Section 3 says of Gleam "the name is the same word C# uses and the meaning is different: ... assembly access control". C# was not probed. The same section's C# bullet says the ticket's statement is taken as the ticket's. The Gleam bullet states the C# half as fact. It should read "as the ticket records it".
- The B# programs in section 5 were never compiled, because `bsc` cannot be built here. They are illustrations of the compiler delta and are not presented as run.
- "20 lines" counts 20 non-blank lines of `tracer.exs`, including 2 comment lines.
- E15 and the "narrowing of ticket 24's consumer" argument rests on F12 plus reading code. I checked the F12 text and the `private_function` emit sites. I did not run `bsc`.

## Verdicts

| Claim | Verdict |
|---|---|
| E1 Erlang export global, opaque forgeable | CONFIRMED |
| E2 xref post-hoc, needs `+debug_info` | CONFIRMED |
| E3 `-deprecated` advisory | CONFIRMED |
| E4 `@moduledoc false` docs only | CONFIRMED |
| E5 Elixir tracer refusal | CONFIRMED (five falsification attempts, none flipped it) |
| E6 tracer blind to dynamic apply | CONFIRMED |
| E7 tracer cost | CONFIRMED (the 30,000-event count independently verified) |
| E8 Gleam internal import builds | CONFIRMED for a path dependency, including two separate directories, `check` and `build` both rc 0, and the default config. UNVERIFIABLE for a registry or git dependency (no network) |
| E9 `@internal` fn call builds | CONFIRMED (same limit as E8) |
| E10 internal hidden from interface | CONFIRMED |
| E11 internal module a plain BEAM export | CONFIRMED |
| E12-E15 `bsc` citations | CONFIRMED by reading, all line numbers correct |
| E16-E18 ticket and feature citations | CONFIRMED by reading |
| Elm, C#, Dialyzer, Boundary claims | UNVERIFIABLE here, and labelled so by the brief |
| 15-line `bsc` delta | UNVERIFIABLE (estimate, labelled as one) |
| CIRCULAR-SUSPECT | none |

**Overall verdict: the brief's measured claims reproduce, and its citations are accurate.** I found no circularity. The one residual risk is Gleam against a registry dependency, which I could not test offline. The brief's reading that Gleam's `internal` is not access control stands for path dependencies.
