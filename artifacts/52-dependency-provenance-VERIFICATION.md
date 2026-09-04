# Verification — ticket 52 dependency-provenance decision brief

Auditor pass over `artifacts/52-dependency-provenance-decision-brief.md` and everything under
`artifacts/52-dependency-provenance/probes/`. Every probe below was independently re-run from
scratch (not by re-executing the original's saved script output) unless noted. Nothing in
`wayfinder/`, git, or `compiler/src/` was modified.

## Claim-by-claim

### Grammar (`bs_parser.yrl`)

| Claim | Result |
|---|---|
| `grep -n "'\['" compiler/src/bs_parser.yrl` → lines 28, 541, 542, 748, 749 | **CONFIRMED** — ran it myself, identical line numbers and content. |
| Line 134-135: `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' : {foreign, line('$1'), value('$2'), '$4'}.` | **CONFIRMED** verbatim. |
| Line 127: `behaviour_decl -> 'behaviour' uident : {behaviour, line('$1'), value('$2')}.` | **CONFIRMED** verbatim. |
| Lines 541-542, 748-749: `pattern`/`expr` list-literal productions | **CONFIRMED** verbatim. |

### `bs_check.erl`

| Claim | Result |
|---|---|
| `callees/3` at lines 594-602, code shown | **CONFIRMED** verbatim, including the `admissible_foreign_ret(L, Mod, N, R, Env)` call inside the list comprehension. |
| `admissible_foreign_ret/5` at lines 619-623, code shown | **CONFIRMED** verbatim. |
| "The only `code:ensure_loaded/1`/`code:which/1`-adjacent calls... are `bsc.erl:700`, `bs_run.erl:26`, `bs_repl.erl:70`, `bs_batch.erl:249`" | **CONFIRMED**, and exhaustive — I ran `grep -rn "code:which\|code:ensure_loaded" compiler/src/` myself: exactly those four sites, all `ensure_loaded`, zero occurrences of `code:which` anywhere in `src/`. None touch a foreign `using`-declared atom; all operate on the compiler's own emitted module. |

### `rebar.config` / `rebar.lock` / `rebar3 tree`

| Claim | Result |
|---|---|
| `compiler/rebar.config:2` is `{deps, [].}` | **FLAGGED (minor)** — actual line 2 is `{deps, []}.`, not `{deps, [].}`. The brief's transcription has the brace and period transposed. The *substance* (empty deps list) is correct; this is a typo, not a factual error. |
| `compiler/rebar.lock` is `[].` | **CONFIRMED** — file content is exactly `[].`. |
| `rebar3 tree` → `└─ bsc─0.1.0 (project app)`, nothing else | **CONFIRMED** — ran it myself in `compiler/`, identical output. |

### `code:which/1` / `application:get_application/1` probe

Re-ran the entire probe fresh, with my own `fauxmod2.erl`/`fauxapp2` (not the original's saved
files), independently:

| Claim | Result |
|---|---|
| `code:which(fauxmod)`, `ERL_LIBS` unset → `non_existing` | **CONFIRMED** (reproduced with fauxmod2). |
| `code:which(fauxmod)`, `ERL_LIBS` at app root → real `.beam` path | **CONFIRMED**. |
| `application:get_application(lists)` → `{ok,stdlib}` | **CONFIRMED**. |
| `application:get_application(fauxmod)` after `ensure_loaded`, no `.app` → `undefined` | **CONFIRMED**. |
| Against real `Elixir.Enum`: `code:which` finds it; `get_application` → `undefined` before `application:load(elixir)`, → `{ok,elixir}` after | **CONFIRMED**, including the real-Elixir case, which is the sharpest of the four claims. |

Not circular: this is genuine BEAM code-server behavior, reproducible on any Erlang/Elixir
install, not something rigged to the sandbox.

### rebar3-with-a-real-dependency probe

Independently ran `rebar3 new app` into a fresh scaffold (own directory, not the original's),
confirmed the scaffold itself writes `{deps, []}.` (matching the brief's claim that this is
rebar3's own convention, not special to this repo), added `{deps, [{req, "0.5.6"}]}.`, ran
`rebar3 compile`:

```
===> Verifying dependencies...
===> Failed to update package req from repo hexpm
===> Package not found in any repo: req 0.5.6
```

**CONFIRMED** — byte-for-byte the same failure text as the brief's captured log. Not fabricated.

**On the "not inert data" mechanism claim (brief lines 75-80, 240-247):** the log itself
distinguishes this from a bare network-down error — rebar3 explicitly enters a
`Verifying dependencies...` / `Failed to update package req from repo hexpm` sequence, meaning it
attempted registry resolution before failing on the network block. Had the version string been
inert metadata, rebar3 would have compiled cleanly and ignored it. The brief is careful to say the
*specific* failure (`Package not found in any repo`) is a network-block artifact while the
*mechanism* (writing a version triggers resolution) is what's demonstrated — that distinction
holds up. **Not circular or overclaimed.**

### mix probe

Independently ran `mix new`, inspected the generated `deps/0`:

```elixir
defp deps do
  [
    # {:dep_from_hexpm, "~> 0.3.0"},
    # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  ]
end
```

**CONFIRMED** — identical to the brief's quoted content. Added `{:req, "~> 0.5"}`, ran
`mix deps.get` (piped `n` to the interactive Hex-install prompt to force it non-interactive):

```
Could not find Hex, which is needed to build dependency :req
Shall I install Hex? (if running non-interactively, use "mix local.hex --force") [Yn] ** (Mix) Could not find an SCM for dependency :req from ProbeApp3.MixProject
```

**CONFIRMED** — same error text and mechanism as the brief's log (module name differs only
because I used a different scratch project name, as expected).

### elm probe

Independently ran `elm init` (answering `Y`) in a fresh empty directory with a fresh
`~/.elm/0.19.1/packages`:

```
-- PROBLEM LOADING PACKAGE LIST ------------------------------------------------
...
ProxyConnectException "package.elm-lang.org" 443 (Status {statusCode = 403, statusMessage = "Forbidden"})
```

No `elm.json` written; `~/.elm/0.19.1/packages` held only an empty `lock` file. **CONFIRMED**
exactly as the brief describes. The brief's explicit "not fabricating `elm.json`'s content, but
marked `doc` not measured" framing for the exact-vs-range application/package split is honest and
correctly hedged — I did not independently verify that public-documentation claim (out of scope;
no way to fetch it here either), but the brief does not claim to have measured it.

### Network reachability

Independently tested:

| Host | Brief's claim | My result |
|---|---|---|
| `hex.pm` | HTTP 200 | **CONFIRMED** — HTTP 200. |
| `repo.hex.pm` | CONNECT tunnel 403 (org policy) | **CONFIRMED** — `curl: (56) CONNECT tunnel failed, response 403`. |
| `package.elm-lang.org` | CONNECT tunnel 403 (org policy) | **CONFIRMED** — same. |

**FLAGGED (gap, not a fabrication):** the brief's Gleam section states "cannot be installed here
(no apt package, GitHub API blocked)" but — unlike the hex.pm/elm-lang.org claims — this is *not*
backed by an entry in `network_reachability.log`; there is no captured probe for `github.com` or
`api.github.com` anywhere in the probes directory. I tested both myself: `apt-cache search gleam`
returns nothing and `apt-get install -s gleam` fails with "Unable to locate package gleam"
(confirms "no apt package"). For GitHub, the CONNECT tunnel to both `github.com` and
`api.github.com` actually **succeeds** (HTTP 200 "Connection Established" from the proxy — a
different outcome than the CONNECT-level 403 used for `repo.hex.pm`/`package.elm-lang.org`), but
an actual API request (`api.github.com/repos/...`) then gets an HTTP-layer 403 with a JSON body
("GitHub access to this repository is not enabled for this session..."). So the practical
conclusion — Gleam cannot be fetched from GitHub here — still holds, but the brief's implicit
lumping of "GitHub API blocked" in with the same "organization policy" CONNECT-403 mechanism it
demonstrated for hex/elm is not quite right, and it's the one part of the network story presented
without its own captured log. Low-severity, but real: it's the one claim in this section that
reads as measured-alongside-the-others but wasn't.

### Cross-document citations

| Claim | Result |
|---|---|
| Ticket 22 (`wayfinder/issues/22-how-opinionated.md:94-95`): "zero lines beginning with `[` in all 99 `.bs` files in the repo" | **CONFIRMED** — opened the file, lines 94-95 read exactly "...appear nowhere outside `wayfinder/` — **zero lines beginning with `[` in / all 99 `.bs` files in the repo.**", split across those two lines as cited. |
| "`[` and `]` reach the grammar only in list syntax" (cited `ibid.`) | **CONFIRMED** — this phrase is on line 93 of the same file (adjacent to the cited 94-95 span; the brief cites it loosely as `ibid.` rather than a specific line, which is accurate enough). |
| Ticket 22 table: `[Erlang("ets","lookup")]` → `using :ets {…}`; `[module: GenServer]` → `behaviour GenServer` | Consistent with the ticket-22 source table and independently confirmed against the live grammar (see above). **CONFIRMED**. |
| Ticket 41 §4 (`decisions.md:1350-1353`): "index.bs is unambiguously the declaration file" | **CONFIRMED** — exact phrase present in `wayfinder/decisions.md` at that location. |
| `wayfinder/prototypes/51a-code-path/Req/req.bs`: three `using` blocks, needing `req`, `elixir`, and nothing (`:maps`) respectively | **CONFIRMED** — read the file directly: `using :'Elixir.Req'` (app `req`), `using :'Elixir.Application'` (app `elixir`, per the file's own comment "`Start()` reports `:elixir` among the applications it brought up"), `using :maps` (stdlib, no app). |
| Ticket 32: "A foreign function is declared, and the declaration carries both spellings." | **CONFIRMED** — exact phrase at `wayfinder/issues/32-ffi-surface.md:138`. |
| `grep -n "using :'Elixir" LANGUAGE.md TOUR.md` → no matches | **CONFIRMED** — ran it myself, empty output, exit 1. |
| `gleam.toml` content (`wayfinder/prototypes/22a_incomplete_marker_probe/gleam_todo/gleam.toml`) | **CONFIRMED** verbatim (`name`, `version`, `target`, three lines, nothing else). |

### Two problems found in the brief's own quotation/dating

1. **FLAGGED — misquote of ticket 52.** The brief writes (twice, once in Options and once by
   implication): *"a version constraint edges into resolution, which is out of scope"* and
   presents it in italicized quote marks as "the sub-question 1 risk **the ticket itself names**."
   Ticket 52's actual text (`wayfinder/issues/52-dependency-provenance.md:56`) is: *"a version
   constraint is resolution, which is the boundary's territory and should stay refused."* These
   are different sentences — not a trivial rewording (different verb: "edges into" vs. "is";
   different object: "out of scope" vs. "the boundary's territory and should stay refused"). The
   underlying idea the brief attributes to the ticket is directionally right (ticket 52 does treat
   version constraints as resolution-adjacent and risky), but presenting invented wording as a
   direct quotation from the ticket is a real citation-accuracy fault, not a paraphrase marked as
   such.

2. **FLAGGED — backwards chronology claim.** In the Recommendation section (line 261), the brief
   states: "Ticket 22's measured finding — ... — **predates ticket 52 by two days**." Ticket 52 was
   raised 2026-08-21 (per its own header). Ticket 22 was resolved 2026-08-23 (per its own status
   line: "Status: **resolved 2026-08-23**"). Ticket 22's finding is therefore dated **two days
   after** ticket 52 was raised, not before it — the claim has the direction backwards. Notably,
   the brief's own section header earlier in the document ("A load-bearing fact ticket 52's own
   candidate predates," line 19) gets the relationship right — the *candidate syntax* (written
   2026-08-21, as part of ticket 52) predates the *fact that refutes it* (established 2026-08-23,
   by ticket 22) — but the Recommendation section later inverts this into "ticket 22... predates
   ticket 52," which the dates on the tickets themselves contradict. This doesn't undermine the
   underlying argument (ticket 22's finding, whenever dated, is real and available now to inform
   ticket 52, which is still open), but it is a checkable factual error in the brief's own
   chronology framing, sitting right next to the sentence's main persuasive claim.

## Circularity verdict

**No rigged or circular probe found.** Every re-runnable probe (codepath, rebar3-with-dep, mix,
elm, grammar greps, network reachability) reproduced independently from scratch, using freshly
created scaffolding rather than the original's saved artifacts, with matching results. The
rebar3 "version constraint triggers live resolution" claim — the brief's own candidate for
"sharpest evidence" and the one most worth stress-testing for overreach — holds up: the captured
log shows an actual `Verifying dependencies...` / registry-lookup attempt distinct from a generic
network failure, and the brief is explicit that the *specific* failure text is a network-block
artifact while the *mechanism* (that writing a version is live input to a resolver) is what's
demonstrated. That's an honest, non-circular distinction, not measurement dressed up from
inference.

The two problems found (misquote of ticket 52; backwards chronology in the Recommendation
section) are citation/accuracy faults, not measurement fabrication — nothing labeled "measured" in
this brief turned out to be merely inferred when checked against a live re-run.

## Overall confidence: HIGH, with two named caveats

Every grammar citation, every `bs_check.erl` code excerpt, every cross-document quote except one,
every re-run probe (codepath, rebar3, mix, elm, network reachability), `rebar.lock`, and
`rebar3 tree` output all checked out exactly against independent re-verification — a high hit
rate across roughly twenty checkable factual claims. The two things that most temper the rating to
"high, not highest":

1. The ticket-52 quotation on the sub-question-1 risk ("edges into resolution, which is out of
   scope") does not appear anywhere in ticket 52's actual text — it's presented as a direct quote
   from "the ticket itself" but is invented wording, even though it's directionally faithful to
   the ticket's real content.
2. The Recommendation section's "predates ticket 52 by two days" has the dates backwards by the
   tickets' own timestamps — a small, checkable chronology error placed at the persuasive center
   of the brief's argument for spelling the extension as a keyword rather than bracket syntax.

Neither error changes the survey's substantive conclusions (rebar3/mix both demonstrate version
strings triggering live resolution; `code:which/1` is real and free; the bracket-syntax precedent
from ticket 22 is real and does predate ticket 52's raising, just not in the direction the
Recommendation section states it). The recommendation itself (option a, name-only,
per-`using`-block) is reasonably supported by what I could independently confirm: option (b) is
cleanly counter-exemplified by the real `req.bs` prototype (two apps across three `using` blocks,
can't collapse to one module-level line), and option (c) is cleanly counter-exemplified by the
rebar3 live-resolution probe. Option (a)'s case is built more by elimination of (b)/(c) than by
direct positive evidence for (a) itself, which is a reasonable brief structure but worth naming as
such.
