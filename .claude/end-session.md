# End-session overlay — beam-sharp

Answers the generic `/end-session` skill would otherwise guess at. Commands, not intentions.

## Gates

Every step CI runs, in CI's order. The first three need no compiler and fail fast.

```sh
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

# --- the compiler ---------------------------------------------------------
cd compiler && ./bin/check-language.sh          # blocks compile, `not-yet` blocks must NOT
cd compiler && ./bin/check-list-length.sh       # the checker sees a list's length, both ways
cd compiler && ./bin/check-field-values.sh      # a field assignment is checked, at both spellings
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

**SEVENTEEN gate scripts, not sixteen — `check-field-values.sh` added 2026-08-21 by F21.** And
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
