# End-session overlay — beam-sharp

Answers the generic `/end-session` skill would otherwise guess at. Commands, not intentions.

## Gates

Every step CI runs, in CI's order. The first two need no compiler and fail fast.

```sh
./bin/check-map.sh                              # map.md is an index, not a store
./bin/check-surface.sh                          # syntax decisions are cited in LANGUAGE.md
cd compiler && rebar3 escriptize                # BEFORE eunit — several tests drive bsc
cd compiler && rebar3 eunit
cd compiler && ./bin/check-language.sh          # blocks compile, `not-yet` blocks must NOT
cd compiler && find examples -path examples/exemplars -prune -o -name '*.bs' -print0 |
    while IFS= read -r -d '' f; do ./_build/default/bin/bsc -o "$(mktemp -d)" "$f" || exit 1; done
cd compiler && ./bin/spec-check.sh              # Dialyzer, plus two negative controls
./editor/bin/check-tokens.sh                    # every lexer keyword is in both editor grammars
./editor/bin/check-corpus.sh                    # the tree-sitter grammar parses every example
cd compiler && ./bin/extract-exemplars.sh --check
```

**TEN gates, not eight — corrected 2026-08-17.** The two `editor/` gates were in neither CI
nor this list, and the cost was five features of drift: the tree-sitter grammar was missing
strings (F9), `and`/`or` while still carrying the **removed** `&&`/`||` (ticket 44), `var`
(F8), `== name` (45) and `where` (F2). Both are CI steps now.

**`check-corpus.sh` exits 0 when the tree-sitter CLI is absent**, so confirm it actually ran
rather than skipped — `npm i -g tree-sitter-cli` if it reports skipping. A gate that silently
skips is worse than one that is honestly missing.

**The example loop RECURSES and prunes `exemplars/`.** Both halves matter: F11's example is a
pair of files in a subdirectory, which a top-level glob walks straight past; and ticket 25's
three exemplars do not parse yet, so recursing *without* the prune turns the must-run surface
into a must-fail one. The old glob excluded them by accident rather than by design.

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
