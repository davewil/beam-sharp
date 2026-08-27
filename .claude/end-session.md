# End-session overlay — beam-sharp

Answers the generic `/end-session` skill would otherwise guess at. Commands, not intentions.

## Gates

**There is one command now, and it is not this list.**

```sh
./bin/verify.sh          # every stage below, in CI's order, fail-fast, from any directory
```

`bin/verify.sh` landed 2026-08-26 with ENG-247. It exists because this file was the most
complete recipe in the repository and this file is an *agent overlay* — a clean-room recipient
had no entry point at all. It also sets a fresh `SPEC_CHECK_DIR` per invocation, so "passes
twice from clean" is two measurements rather than one warm tree measured twice; that used to be
a sentence a caller had to remember.

Prefer it. The itemised list below is for running **one** stage after a red, and
`check-gates-wired.sh` now holds `verify.sh` to naming every gate on disk, so the two cannot
drift apart silently.

```sh
# --- the toolchain: before anything compiles ------------------------------
./bin/check-toolchain.sh                        # .tool-versions and ci.yml pin the same versions
./bin/check-toolchain.sh --env                  # this machine runs those versions
./bin/verify.sh --self-test                     # the entry point still refuses a failed stage

# --- repo hygiene: no compiler needed, fails fast -------------------------
./bin/check-gates-wired.sh                      # every gate on disk is named by the workflow
./bin/check-cwd-independence.sh                 # a gate works from any directory
./bin/check-shell.sh                            # the gates are shellcheck-clean
./bin/check-map.sh                              # map.md is an index, not a store
./bin/check-surface.sh                          # syntax decisions are cited in LANGUAGE.md
./bin/check-links.sh                            # the package points only at things it ships

# --- build: escriptize BEFORE eunit, several tests drive bsc --------------
cd compiler && rebar3 escriptize
cd compiler && rebar3 eunit

# --- the handoff package (needs bsc: its last check compiles the artifact) -
./bin/build-handoff.sh --self-test              # the assembly transform discriminates
./bin/check-handoff-package.sh --self-test      # missing file, dead reference, truncated manifest
./bin/check-handoff-package.sh                  # the package a recipient gets stands alone

# --- the compiler ---------------------------------------------------------
./bin/check-status-claims.sh                    # no document calls unbuilt what the corpus compiles
cd compiler && ./bin/check-language.sh          # blocks compile, `not-yet` blocks must NOT
cd compiler && ./bin/check-switch-diagnostics.sh # every switch diagnostic has an example in §5
cd compiler && ./bin/check-residual-pasteable.sh # the synthesised head round-trips to its recorded verdict
cd compiler && ./bin/check-list-length.sh       # the checker sees a list's length, both ways
cd compiler && ./bin/check-division.sh          # `/` lowers to div; only a provable zero is refused
cd compiler && ./bin/check-negation.sh          # no `not`, no `!`, both taught; `not` is still a name
cd compiler && ./bin/check-field-values.sh      # a field assignment is checked, at both spellings
cd compiler && ./bin/check-record-pattern.sh    # a type prefix subtracts what the Kind spelling does
cd compiler && ./bin/check-boundary-kind.sh     # an int parameter is an integer at the boundary
cd compiler && ./bin/check-corrected-signature.sh # a return mismatch hands over the line to paste
cd compiler && ./bin/check-diagnostics.sh       # every tag has a message, and vice versa
cd compiler && ./bin/check-no-silent-skip.sh    # no test reports ok for work it did not do
cd compiler && ./bin/check-tour.sh              # TOUR replays, and the page is not stale
cd compiler && ./bin/check-exemplar-frontier.sh # the exemplar frontier has not moved silently
cd compiler && ./bin/check-helper-agrees.sh
cd compiler && find examples -path examples/exemplars -prune -o -name '*.bs' -print0 |
    while IFS= read -r -d '' f; do dirname "$f"; done | sort -u |
    while IFS= read -r d; do
        ./_build/default/bin/bsc --src-root examples -o "$(mktemp -d)" "$d" || exit 1; done
cd compiler && ./bin/spec-check.sh              # Dialyzer, plus two negative controls
cd compiler && ./bin/extract-exemplars.sh --check

# --- the editors ----------------------------------------------------------
./editor/bin/check-tokens.sh                    # every lexer keyword is in both editor grammars
./editor/bin/check-corpus.sh                    # the tree-sitter grammar parses every example
```

**Every gate also takes `--self-test`, and CI runs those first.** A gate is not believed until
it has been seen to go red, so the self-test pass is not optional decoration — it is the half
that proves the green means something.

**A STRAY `C.beam` IN `compiler/` MAKES `check-helper-agrees.sh` LIE.** It shadows stdlib's `c`,
so bare `erl` dies during boot with `{undef,[{c,erlangrc,...}]}`. The gate used to discard stderr,
so this read as *"the helper reports [none]"* and accused the helper of not walking the compiler's
path — a false red that cost twenty minutes on 2026-08-26 before anyone looked at stderr. CI never
sees it, because a fresh checkout has no `C.beam`. The gate now prints the boot failure and reports
`__erl_failed__`, but **the detritus is still worth deleting**: `rm -f compiler/C.beam` before a
sweep, and note that `.gitignore` hides it so `git status` stays clean.

**TWENTY-SIX `check-*` gate scripts — `check-residual-pasteable.sh` added 2026-08-27 by
ENG-263, and `check-switch-diagnostics.sh` added 2026-08-27 by ENG-248. This line read
TWENTY-FOUR until 2026-08-27 and was wrong by one for most of that day: ENG-248 added its
gate to `ci.yml`, `verify.sh` and the list above but not to this count, which is the
four-edit rule failing on its fourth edit rather than its third. `check-gates-wired.sh`
does not read this number — it checks that every gate is NAMED on each surface, and a
name was present, so the miscount was invisible to it. Previously `check-handoff-package.sh` added 2026-08-26 by
ENG-246, alongside `bin/build-handoff.sh`, which is a builder rather than a gate and so is
outside the `check-` pattern exactly as `verify.sh` is. `check-gates-wired.sh` caught the
new pair missing from *this list* having already been added to the script, `ci.yml` and
`verify.sh` — three of four again, the same failure and the same gate catching it, one day
after the previous one.** Previously TWENTY-THREE: `check-negation.sh` added 2026-08-26 by
F27, missing from this list in precisely the same way. Previously: `check-toolchain.sh` added 2026-08-26 by ENG-247,
which also added `bin/verify.sh` (an entry point rather than a gate, so the `check-`
count above does not see it — run the pattern, then remember it is deliberately narrow).
The four-edit rule below is now literally four: `check-gates-wired.sh` gained a fourth
question, and it caught both new files missing from this list within a minute of being
written, which is the third-edit rule working as designed for the second time.** Previously:
`check-division.sh` added 2026-08-25 by F26, and
`check-corrected-signature.sh` added 2026-08-23 by F25, hours after
`check-boundary-kind.sh` made it nineteen the same day. It was `check-gates-wired.sh` that caught
the omission rather than a reader, which is the third-edit rule working as designed.** Previously:
`check-boundary-kind.sh` added 2026-08-23 by F24, one day after
`check-record-pattern.sh` made it eighteen and two after `check-field-values.sh` made it
seventeen.** The count has now been wrong at three consecutive
readings, which is the point of writing it as a number: a stale one is visible, and a missing
line is not. And
the drift the entry below records **repeated one commit later**: `cf32e50` fixed this list, F21
added a gate on the same day, and the list was one short again before anything read it. That is
the entry below's own lesson arriving faster than it could be learned, and it is structural rather
than careless — **`check-gates-wired.sh` verifies disk → workflow, not workflow → this file**, so
nothing can see this drift. Until something does, adding a gate means editing three places: the
script, `ci.yml`, and here. **Run the count below rather than trusting any number written above
it**, this sentence included.

**SIXTEEN gate scripts, and this list was six of them until 2026-08-21.** It claimed to be
*"every step CI runs, in CI's order"* and had drifted to naming `check-map`, `check-surface`,
`check-links`, `check-language`, `check-tokens` and `check-corpus` only — so a session following
it ran six gates and believed it had run all of them. Nine were missing, including
`check-list-length.sh`, added the same day by F20. **Count them against the workflow rather than
trusting the prose**, which is what caught this:

```sh
grep -oE '\./(bin|compiler/bin|editor/bin)/check-[a-z-]+\.sh' .github/workflows/ci.yml | sort -u | wc -l
```

The lesson is the one below, turned on this file: *a surface nothing gates is a surface that
rots*, and the list of gates was itself ungated.

**ELEVEN gates, not ten — `check-links.sh` added 2026-08-18.** It is the first gate that checks the
DOCUMENTS rather than the compiler, and it went in because the clean-room package was measured
carrying **25 citations of `examples/<name>.bs` paths that had not existed since F15** made a module
a directory — including the header comment of `Totals.bs`, which told a reader how to run it with a
path that was gone. It also holds `LANGUAGE.md` to its own opening rule (no ticket numbers in
visible prose, since the handoff ships that file and not `wayfinder/`), which had 12 violations. The
same lesson as the two editor gates below, one level out: **a surface nothing gates is a surface
that rots**, and the documents were the last ungated one.

**TEN gates, not eight — corrected 2026-08-17.** The two `editor/` gates were in neither CI
nor this list, and the cost was five features of drift: the tree-sitter grammar was missing
strings (F9), `and`/`or` while still carrying the **removed** `&&`/`||` (ticket 44), `var`
(F8), `== name` (45) and `where` (F2). Both are CI steps now.

**`check-corpus.sh` exits 0 when the tree-sitter CLI is absent**, so confirm it actually ran
rather than skipped — `npm i -g tree-sitter-cli` if it reports skipping. A gate that silently
skips is worse than one that is honestly missing.

**The example loop RECURSES, runs PER DIRECTORY, and prunes `exemplars/`.** All three matter.
F11's example is a pair of files in a subdirectory, which a top-level glob walks straight past.
F15 made the directory the module, so a per-*file* invocation emits a `.beam` missing the rest of
its module — wrong rather than merely outdated — and `--src-root examples` is needed because the
corpus holds dotted modules, which are nested directories. And ticket 25's three exemplars do not
parse yet, so recursing *without* the prune turns the must-run surface into a must-fail one; the
old top-level glob excluded them by accident rather than by design.

**A glob that matches nothing does not disappear — bash passes it through unexpanded.** After
F15's corpus rewrite there are no `.bs` files at the top level of `examples/`, and three gate
scripts pointed at `examples/*.bs` therefore ran against a literal filename with a `*` in it.
`editor/bin/check-corpus.sh` looped exactly once, reporting one ERROR for a file that does not
exist while checking none of the ones that do. **Prefer `find` over a glob in a gate**, and when a
gate goes quiet after a layout change, suspect this first.

**`escriptize` before `eunit` is load-bearing** — tests that drive `bsc` as a subprocess
resolve it at `_build/default/bin/bsc`, and with `eunit` first they fail on a fresh
checkout or, worse, skip silently.

**Nothing is excluded from CI.** If a gate has to come out, it goes in the block at the
bottom of `.github/workflows/ci.yml` with its reason, and the reason gets re-checked
rather than inherited.

## Landing

Trunk-based on `master`. **No PRs, no long-lived branches** — including for background
and autonomous sessions, which land on trunk too. A fast-forward onto `master` after a
green gate is the expected ending; the branch and worktree are deleted after.

Never force-push. Never rewrite published history. This is a design repo with no deploy,
so landing on trunk ships nothing — but ask before cutting a release tag anyway.

If the local `master` ref will not fast-forward because it is checked out in the main
working copy, push to `origin` and say the main copy needs `git pull`. That is expected,
not a failure.

## Tracker

**Linear owns state; this repo owns content.** Map is
[ENG-165](https://linear.app/davewil/issue/ENG-165); tickets are its children.

**The ticket-number arithmetic is dead.** It has produced four different offsets
(`+166`, `+167`, `+170`, `+172`). **Query Linear for the id every time**, and check the
issue *exists* before assuming any state is tracked.

Resolving a ticket means updating **both**: the answer in `wayfinder/issues/NN-*.md`, and
the issue's state plus a gist in its description.

## Drift checks

Mechanical, and each one exists because it already bit:

```sh
# repo status lines — compare against Linear issue states
grep -H -m1 '^Status:' wayfinder/issues/*.md

# every ticket has an issue: count files against the project's child issues
ls wayfinder/issues/*.md | wc -l

# feature headers against the README table — the table is the queue, so it is right
grep -H -m1 '^\*\*Status\*\*' compiler/features/F*.md
```

**A feature file naming a decision it needs *is* raising a ticket**, and it does not count
as raised until the repo file and the Linear issue both exist. A blocker recorded only in
prose is invisible to the frontier — that is how F2 sat takeable-looking for a day, and
F8 came within one session of repeating it.

## Durable memory lives at

`~/.claude/projects/-Volumes-Personal-Users-davidwilliams-dev-misc-beam-sharp/memory/`,
with a one-line pointer in its `MEMORY.md`.

Belongs there: how David wants design questions put, standing preferences, hard-won
gotchas. **Does not** belong there: decisions (they go in `wayfinder/`), anything
`CLAUDE.md` already says, or the shape of the code.
