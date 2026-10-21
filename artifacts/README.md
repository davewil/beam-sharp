# artifacts/ — decision briefs for the five oldest open decision tickets

Produced by a scheduled run on 2026-10-21. **No ticket was resolved, claimed or moved**; every decision is left
open for David. Each brief has the same shape: what is true today (run, not read), the options as programs with the
compiler delta, the strongest counterargument to each, a recommendation, and what could not be measured.

| ticket | Linear | brief | one line |
|---|---|---|---|
| 59 | [ENG-241](https://linear.app/davewil/issue/ENG-241) | [briefs/59-boundary-guard-scope.md](briefs/59-boundary-guard-scope.md) | the private tag test is the only net for a nested forged record; the int test has no net at all |
| 60 | [ENG-242](https://linear.app/davewil/issue/ENG-242) | [briefs/60-who-may-name-a-module.md](briefs/60-who-may-name-a-module.md) | every BEAM neighbour's "internal" is advisory; B# can refuse, but only for B# callers |
| 62 | [ENG-252](https://linear.app/davewil/issue/ENG-252) | [briefs/62-the-outbound-abi.md](briefs/62-the-outbound-abi.md) | Elixir *can* call `:Shop."New"(1)`; Gleam is not a precedent for function aliases |
| 64 | [ENG-254](https://linear.app/davewil/issue/ENG-254) | [briefs/64-option-and-result-at-term.md](briefs/64-option-and-result-at-term.md) | only `T = term` collapses; ticket 108's `Map.?Get` now needs the answer |
| 65 | [ENG-255](https://linear.app/davewil/issue/ENG-255) | [briefs/65-reserved-names-policy.md](briefs/65-reserved-names-policy.md) | mostly answered by 67/96/F32; `module Elixir.Enum` compiles and kills an Elixir VM |

**How the five were chosen.** `list_issues` for the Linear project `beam-sharp design map`, oldest `createdAt` first,
excluding completed/canceled/duplicate, keeping only map tickets (titles `NN — <question>`). The five oldest are
ENG-241, 242, 252, 254, 255, all `Backlog`, none `In Progress` or `In Review`. Older open items that are not map
tickets (ENG-244 *Improvement*, ENG-248 *Bug*, ENG-250 a defect report) were skipped as not decision tickets.

## Probes

`probes/` holds every probe the briefs cite; `probes/results/` is the author's run of `probes/run_all.sh`;
`verification/` is an independent re-run and circularity audit by a separate agent (see its report).

### Toolchains actually used — and where they differ from the tickets

| tool | version used | how obtained | tickets measured with |
|---|---|---|---|
| Erlang/OTP | **28.0** | built from the `erlang/otp` release tarball | 28 (62a), 29 (87) |
| Elixir | **1.18.4** (on OTP 28) | built from a `git clone --branch v1.18.4` | not stated |
| Gleam | **1.12.0** | release binary | 1.18.1 (62a) — **older than the tickets'**; constructor casing and the lowercase-function rule are old features, but I did not run the newer release |
| Elm | 0.19.1 | release binary | — |
| bsc | this branch's HEAD, built with rebar3 3.24.0 under OTP 28 | — | — |

- The package manager's Erlang 25 / Elixir 1.14 were installed first and **cannot run `bsc`** (the lexer needs
  `TokenLoc`, OTP ≥ 26) and cannot load OTP 28 beams; every probe reported was re-run on the OTP 28 / Elixir 1.18.4
  stack above. (`62-p1` also gave identical output on Elixir 1.14.)
- **Elm could not be exercised.** `elm make` needs `package.elm-lang.org`, which the session's network policy
  blocks (403). The briefs make no Elm claim beyond one source citation (`elm/core` `Dict.elm:94`, `Maybe.elm:39`).
- Library sources cited by file and line are `git clone`s at tags, not "installed" copies: `elixir` v1.18.4,
  `gleam` v1.12.0, `gleam-lang/stdlib` v0.62.0, `elm/core` 1.0.5, and the OTP 28.0 tarball.
- `rebar3 escriptize` was run once for the compiler; `git status` shows the repository itself untouched except
  `artifacts/`.

### Limits that apply to every brief

- Result files record `exit=` of the last pipeline stage only, so `exit=0` does not mean every step passed; read the output. (Verifier finding.)
- Corpus probes (`59-p3`, `62-p3`, `62-p4`) skip 7 fragment directories under `compiler/examples/exemplars/` that are not buildable alone; the count is printed, individual names are partly hidden by `tail`.
- Timings are wall clock on a shared 4-core container (the OTP build had finished): treat nanosecond figures as ±0.3.
- A "what-if" is only used to price a cost (guards, aliases) by compiling the *same forms* with and without the extra
  code through one `compile:forms` call; no probe patches the compiler to manufacture a behaviour, and the forged-record
  results in brief 59 are `bsc`'s own output on unmodified source.

### Verification (separate agent, `verification/verifier-report.md`)

All 19 probes re-ran and reproduce; five falsification attempts (quoted Elixir call, forged nested records, collapse
matrix, `Elixir.*` roots, Gleam duplicate module) confirmed the claims. It found problems that this commit fixes:
guard/alias byte figures omitted `debug_info` (roughly halved; now corrected in briefs 59 and 62), the int-guard ns
figure and the tagged-success ns figure were too high (64's first draft measured `put/2`; replaced), a tautological
Erlang block in `64-p1` (now labelled as a restatement; `64-p4` is the evidence), and stale saved results (re-run).
Not fixed, noted: result files record only the last stage's exit status; `65-p1` rows C1/C3 are parse errors, not
reservations (brief 65 says so); `62-p3`'s regex finds 101 of 107 names (zero collisions either way).
