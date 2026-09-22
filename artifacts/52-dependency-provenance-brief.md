# Ticket 52 — dependency provenance: decision brief

Research only. Does not resolve the ticket, does not touch
`wayfinder/issues/*.md`, does not change any `Status:` line, and no tracked
compiler source was edited — every compiler experiment below ran against a
scratch copy at `/tmp/ticket52-scratch/compiler`. Probes are under
`artifacts/_probes/52/`, referenced by filename throughout.

## 0. What the grammar actually looks like today (grounding, not invention)

`compiler/src/bs_parser.yrl:120-121` (tracked tree):

```
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.
```

**There is no `[external: ...]` attribute anywhere in the shipped grammar.**
Ticket 32's 2026-08-14 answer specified one — `[external: erlang, "ets"]
module Ets { ... }`, a separate name-binding block — but ticket 41 §1
(2026-08-15/16) generalised `using` to cover the foreign form and the native
cross-module form in one construct, told apart by the token class after
`using`, and dropped the attribute and the `module` binding in the
simplification. The construct ticket 52 is grilling is therefore exactly
what its own example writes: `using :'Elixir.Req' { ... }`, no attribute,
full stop (`compiler/src/bs_check.erl` never mentions `application`,
`ERL_LIBS`, `code:lib_dir` or `code:where_is_file` anywhere — grepped).
Full detail: `artifacts/_probes/52/02-grammar-as-shipped.txt`.

This matters for scoping the options below: candidate
`[external: elixir, app: req] using ...` is not "add a field," it is
"reintroduce attribute syntax to this construct for the first time since
ticket 41 removed it" — a real, if small, second cost.

## 1. Sub-decisions implied

### (a) Name-only, or name+version?

**Name-only is the only defensible answer**, and it follows directly from
ticket 51's own resolution, not from new reasoning here: 51 already decided
beam-sharp resolves no version, locks nothing, fetches nothing. A version
constraint in the `using` line is version *resolution* wearing a different
hat — the exact thing `scope.md` refuses and 51 confirmed the refusal holds.
Presence (*"is `req` on the code path at all"*) is a yes/no fact a BEAM
process can answer in microseconds (measured below); a version range needs
a resolver, which is the multi-year track. So (a) is close to pre-decided
by 51, and this ticket doesn't reopen it — it's recorded here because the
ticket file lists it as open.

### (b) Per `using` block, or once per module?

**Measured as unresolved by design, not by omission.** The grammar attaches
an attribute to the specific `foreign_decl` node it prefixes
(`artifacts/_probes/52/04a-bs_parser.yrl.diff`), so "per block" is what a
minimal implementation gets for free. But nothing stops two separate
`using` blocks in the same directory naming the *same* foreign atom for
different function subsets — ticket 51a's own `req.bs` already has three
independent `using` blocks (`Elixir.Req`, `Elixir.Application`, `maps`), and
nothing in principle stops splitting `Elixir.Req`'s functions across two.
Per-block duplicates `[app: req]` on both blocks (cheap to write, per the
standing constraint, but now two sites that can silently disagree); per-atom
would need the checker to unify every `using` block naming a given foreign
atom across the whole directory pass and either require the app tag on
exactly one, or refuse a conflict — real design work the prototype below
did **not** attempt (it took the cheapest reading: the tag is per-block,
and duplication is the writer's problem, unchecked). This sub-question is
genuinely open and this brief does not close it.

### (c) What does the compiler actually DO with it?

**Measured, working, end-to-end, in the scratch prototype**: exactly what
the ticket guesses — "is this application on the code path" is one call to
`code:where_is_file/1` and it is the whole feature. See §3.

## 2. Options for the overall mechanism

### Option A — `[external: elixir, app: req] using :'Elixir.Req' { ... }`, checked with `code:where_is_file/1`

**What it is.** Reintroduce a bracket attribute ahead of `using`, carrying
`app: <atom>` (and, per (a), nothing else). At the point in `bs_check.erl`
where `foreign_rets_decidable/2` already runs
(`compiler/src/bs_check.erl:150`), add a sibling pass that, for every
foreign decl carrying an `app` tag, asks whether `<app>.app` resolves on
the current code path, and refuses with a real diagnostic if not.

**Built and measured**, not sketched:

- Grammar: `artifacts/_probes/52/04a-bs_parser.yrl.diff` — one new
  attribute production, **no new shift/reduce conflicts** (5 before, 5
  after, both counted from a clean `rebar3 escriptize`).
- Checker: `artifacts/_probes/52/04b-bs_check.erl.diff` — a
  `foreign_apps_reachable/1` pass, four lines of actual logic.
- Diagnostic: `artifacts/_probes/52/04c-bs_diag.erl.diff` — one `built/2`
  clause, one `message/1` clause, following the exact shape
  `foreign_ret_beyond_one_guard` already uses.
- **End-to-end demonstration**
  (`artifacts/_probes/52/05a-prototype-source.bs`,
  `05b-prototype-demonstration.txt`): a real Elixir 1.19.5 install
  (precompiled for OTP 28, fetched directly from GitHub since hex.pm was
  403'd and apt's Elixir 1.14 doesn't load under OTP 28 — see §3 for both):

  ```
  === A. COMPILE, ERL_LIBS unset -- app declared, not on the code path ===
  Demo2/demo2.bs:4:1: error: :'Elixir.String' names application `elixir`, which is not on the code path
    bsc found no `elixir.app` -- point ERL_LIBS (or --lib) at wherever `elixir` was built
  exit: 1

  === B. COMPILE, ERL_LIBS points at the real Elixir install (app present) ===
  exit: 0
  ```

  This is the exact `error:undef`-at-the-call-site scenario the ticket
  describes, turned into a compile diagnostic that names the missing
  application and says what to do.

- **Compile-time cost, measured, not assumed**
  (`artifacts/_probes/52/06-cost-measurement.txt`): the check's only
  runtime cost is `code:where_is_file/1`, timed at **14.3–16.2 µs/call**
  over 10,000 calls in-process. A 20-compile wall-clock comparison
  (attributed vs. unattributed source) showed 12.07s vs. 12.09s — a
  difference smaller than run-to-run noise, consistent with the
  microsecond isolated figure: escript VM boot (~0.5s/invocation) dwarfs
  the check by four orders of magnitude.

**Strongest counterargument.** The check only ever refuses what an author's
*own* build environment already refuses — if `req` isn't on `ERL_LIBS` at
compile time on the author's machine, the author would already discover
that immediately (bsc would fail to find `elixir.app` on their own
box, not just on a stranger's). Where it earns its keep is exactly the
scenario ticket 52 names: a **second** machine, with a **different**
`ERL_LIBS`, days or months later — CI, a teammate, the clean-room fleet.
The check cannot detect that divergence at the point it's declared; it can
only make the failure mode identical (a compile refusal instead of a
runtime crash) everywhere the source travels, and make the dependency
*legible* in the file rather than implicit in an environment variable. If
what's wanted is "prevent drift between machines," this option does not
do that — it only makes drift loud instead of silent, on whichever machine
next compiles the file. That is real, but it is smaller than "solves the
problem," and the brief should not oversell it.

### Option B — do nothing; leave it to `ERL_LIBS`, as 51 already half-accepted

**What it is.** No attribute, no check. Ticket 51's own resolution already
states, unprompted, that provenance is "deliberately NOT closed" and reads
as an accepted gap rather than an oversight — the ticket's own words:
*"Nothing in a `.bs` file records which dependencies it needs... That is a
provenance question, not a packaging one, and it is the half of a build
tool that beam-sharp may genuinely owe."* Note the hedge — "may genuinely
owe," not "owes."

**Evidence for.** Zero implementation cost (measured: nothing to measure,
because there's nothing to build). No new grammar, no new diagnostic
surface for the release-gate and diagnostics-fidelity machinery to cover.
Consistent with the strict reading of 51's decision that `bsc` needed *no
flag and no change at all* to reach Req — this option is the direct
continuation of that finding rather than an addition to it.

**Evidence against, and it's the stronger side.** Ticket 51 gives the exact
argument this option fails to answer: *"a program whose dependencies exist
only in the environment that happened to build it **cannot be handed
over**"* — and the destination named throughout `CLAUDE.md` and both
tickets is a **clean-room handoff to a fleet that has never seen David's
machine.** Measured concretely in §3: the failure mode without any check
is a bare `crashed: error:undef` with **no file, no line, no application
name** — nothing in the crash even names `req` or `elixir` as the missing
piece; a fleet debugging that has to reverse-engineer which foreign call
in a large program was the culprit. Option A's diagnostic, by contrast,
names the file, the line, and the application, at compile time, before any
of the fleet's time is spent on it. Doing nothing is cheap today and
expensive exactly at the moment the project says it cares most —
handoff.

### Option C — piggyback Gleam's `@external` shape more literally

**Ruled out by the survey, not merely disfavoured.** The task asked
specifically whether Gleam's `@external(erlang, "module", "function")` is
closer prior art and whether it ever names the owning application.
Measured against real Gleam compiler source
(`artifacts/_probes/52/07-gleam-external-citation.txt`):

- `compiler-core/src/parse.rs:4816-4843`, `parse_external_attribute`:
  exactly three arguments parsed — target (`erlang`/`javascript`), a module
  string, a function string. No fourth slot.
- `compiler-core/src/ast.rs:887-889` and `:1160-1164`: the AST field itself
  is `Option<(EcoString, EcoString, SrcSpan)>` — a 2-tuple plus a span, at
  the type level, not merely the parser's choice.
- No cross-check anywhere in `compiler-core/src` links an `@external`
  module to a declared `gleam.toml` dependency (grepped for the obvious
  patterns; zero hits).

**Gleam's `@external` has the identical gap this ticket is about** — it is
not prior art *for solving it*, only for the bracket-attribute syntax,
which ticket 32 already borrowed and cited correctly. Gleam's actual answer
to dependency provenance lives entirely in `gleam.toml`'s separate
dependency list, which is the "manifest, no resolver" shape ticket 51
candidate 2 already priced and beam-sharp already declined. So Option C
collapses into either Option A (attribute on the declaration, which is
*not* what Gleam does) or the rejected manifest shape — there's no third
thing to borrow here. This closes the "or piggyback Gleam" branch the task
asked me to check, with real evidence rather than a guess.

## 3. Baseline measurement — the "costs nothing today" claim, verified

Real reproduction, `artifacts/_probes/52/03a-baseline-source.bs` /
`03b-baseline-reproduction.txt`, unmodified tracked-tree grammar, built
compiler:

```
--- COMPILE, unset ERL_LIBS (promises nothing, compiles clean) ---
exit: 0

--- RUN, unset ERL_LIBS (the machine described in the ticket) ---
crashed: error:undef
exit: 1

--- RUN, ERL_LIBS pointing at a real, present Elixir install (/opt/elixir-1.19.5) ---
"REQ"
exit: 0
```

This is the ticket's scenario, run for real: `bsc` compiles a `using
:'Elixir.String' { binary upcase(binary s) }` declaration with **zero**
awareness of whether `elixir` is installed anywhere, and the exact same
`.bs` source and exact same compiled artifact succeeds or fails purely on
an environment variable set outside the source. No file, no line number, no
application name accompanies the crash — `crashed: error:undef` is the
entire diagnostic surface today.

**Two environment findings worth carrying forward, both measured rather
than assumed:**

- **apt's Elixir does not run under the OTP this repo's tooling builds
  against.** `dpkg -l`: elixir 1.14.0, erlang-base 25.3. Run under our
  OTP-28-built `erl`: `beam_load.c(596): Error loading function
  'Elixir.Kernel':alias_defmodule/3: ... please re-compile this module with
  an Erlang/OTP 28 compiler` — a hard load failure, not a soft warning
  (`artifacts/_probes/52/03c-apt-elixir-otp28-incompatible.txt`). Elixir
  1.19.5 precompiled for OTP 28 was fetched directly from
  `github.com/elixir-lang/elixir/releases/download/v1.19.5/elixir-otp-28.zip`
  (HTTP 200) and used instead — a real, present install, not a fake one.
- **hex.pm is blocked.** `mix deps.get` for Req 0.7.3 403'd through the
  proxy on the first and only attempt, not retried per instructions
  (`artifacts/_probes/52/03d-hexpm-blocked.txt`). `api.github.com` is
  separately blocked with an explicit access-not-enabled message. Direct
  `github.com` release-asset downloads work, matching the environment note.
  The demonstration therefore substitutes Elixir's own stdlib application
  (a real, unfaked dependency) for Req — Req itself could not be reached
  in this session, and the brief says so rather than pretending otherwise.

## 4. Recommendation

**Option A, narrowly scoped to (a) name-only and (c) presence-only,
with (b) left genuinely open.** The reasoning:

1. Doing nothing (Option B) is not a neutral default here — it is a
   continuation of exactly the gap ticket 51 flagged and did not resolve,
   and the project's own stated criterion for what a session must move
   (an exemplar that didn't compile-and-run yesterday, or the audition, or
   the tooling) is directly served by turning an unnamed runtime crash into
   a diagnostic that names the file, line and missing application —
   measured above to cost single-digit microseconds at compile time.
2. Gleam is not a shortcut here (Option C) — it has the same gap, measured
   from its own source, not assumed from familiarity with the language.
3. The prototype is not speculative: it built cleanly against the current
   grammar with **zero new parser conflicts**, integrates at the same
   point in the checker pipeline `foreign_rets_decidable/2` already
   occupies, and follows the same diagnostic-building convention
   (`built/2` + `message/1`) the rest of `bs_diag.erl` uses — so nothing
   about the shape is foreign to the codebase's own idiom.
4. What should **not** ship without further design: (b), per-block vs.
   per-module attachment and what happens when two `using` blocks name the
   same foreign atom with different (or missing) `app` tags. The
   prototype's cheapest-possible reading (attribute is per-block,
   duplication unchecked, no cross-block consistency rule) is a
   placeholder, not a recommendation — resolving it needs the same
   "write a realistic program, show what it costs" treatment
   `CLAUDE.md`'s working rules require, and this brief has not done that
   work.
5. Scope discipline: keep (a) refused exactly as 51 refused it (no
   version, no resolution) — the moment a version constraint enters this
   attribute, the ticket has quietly reopened 51, which the ticket's own
   notes explicitly forbid.

## 5. Probes-run appendix

All under `artifacts/_probes/52/`:

| File | What it is |
|---|---|
| `00-README.txt` | Environment summary: OTP 28.5 build, bsc build recipe, Elixir substitution, hex.pm block |
| `01-tracked-tree-untouched.txt` | `git status --short compiler/` — empty, confirms no tracked-tree edits |
| `02-grammar-as-shipped.txt` | What `using`/`foreign_decl` actually parse to today (no attribute exists) |
| `03a-baseline-source.bs` / `03b-baseline-reproduction.txt` | The ticket's exact scenario, reproduced: compiles clean, `error:undef` at the call site, fixed by `ERL_LIBS` |
| `03c-apt-elixir-otp28-incompatible.txt` | apt Elixir 1.14 fails to load under OTP 28 — real crash output |
| `03d-hexpm-blocked.txt` | `mix deps.get` for Req, 403 through the proxy, not retried |
| `04a/b/c-*.diff` | The scratch prototype's grammar, checker and diagnostic changes, as diffs against the tracked tree |
| `05a-prototype-source.bs` / `05b-prototype-demonstration.txt` | The `[external: elixir, app: elixir]` prototype, compiled both with and without the app on `ERL_LIBS` |
| `06-cost-measurement.txt` | `code:where_is_file/1` timed at 14.3–16.2 µs/call (10,000 calls); 20-compile wall-clock comparison |
| `07-gleam-external-citation.txt` | Gleam `@external` parser + AST source, confirming module+function only, no application field, no cross-check |
| `08-elixir-application-citation.txt` | `Application.ensure_loaded/1` source — a runtime wrapper, not a compile-time check |
| `09-otp-appsrc-citation.txt` | OTP's own `.app.src` `applications` key (`ssh.app.src:57`, and this repo's own `bsc.app.src:5`) — the producer-side precedent for declaring dependency-by-application-name |
