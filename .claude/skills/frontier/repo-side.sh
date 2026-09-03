#!/usr/bin/env bash
#
# The repo's half of the frontier: the facts a session needs before asking Linear
# which issue to take. Linear owns state; this prints what only the tree knows.
#
#     .claude/skills/frontier/repo-side.sh        # from the repo root, or anywhere
#
# Read-only. Prints, in order: HEAD and its distance from origin/master, whether
# master's CI is green (needs `gh`), whether the tree is dirty, every map ticket
# whose repo Status is not resolved, and every feature file whose Status line is
# not done or shipped. A red master or a dirty tree is the first piece of work.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

echo "== tree"
git fetch -q origin 2>/dev/null || echo "  (fetch failed; distances below are against a stale origin/master)"
head=$(git rev-parse --short HEAD)
branch=$(git rev-parse --abbrev-ref HEAD)
behind=$(git rev-list --count "HEAD..origin/master" 2>/dev/null || echo "?")
ahead=$(git rev-list --count "origin/master..HEAD" 2>/dev/null || echo "?")
echo "  HEAD $head on $branch  (ahead of origin/master: $ahead, behind: $behind)"
if [ -n "$(git status --porcelain)" ]; then
  echo "  DIRTY:"
  git status --short | sed 's/^/    /'
else
  echo "  clean"
fi

echo "== master CI"
if command -v gh >/dev/null 2>&1; then
  gh run list --branch master --limit 3 --json status,conclusion,headSha,createdAt \
    --template '{{range .}}  {{if .conclusion}}{{.conclusion}}{{else}}{{.status}}{{end}} {{slice .headSha 0 7}} {{.createdAt}}{{"\n"}}{{end}}' \
    2>/dev/null || echo "  (gh run list failed; check CI by hand before trusting local green)"
else
  echo "  (gh not installed; check CI by hand before trusting local green)"
fi

echo "== map tickets not resolved in the repo (Status: line)"
found=0
for f in wayfinder/issues/*.md; do
  status=$(grep -m1 '^Status:' "$f" || true)
  case "$status" in
    *resolved*|*Resolved*|*RESOLVED*) ;;
    "") echo "  $(basename "$f"): (no Status: line)"; found=1 ;;
    *) echo "  $(basename "$f"): ${status#Status: }"; found=1 ;;
  esac
done
[ "$found" -eq 1 ] || echo "  none"

echo "== feature files whose Status is not done or shipped"
found=0
for f in compiler/features/F*.md; do
  line=$(grep -m1 '^\*\*Status\*\*' "$f" || true)
  case "$line" in
    *done*|*shipped*) ;;
    "") echo "  $(basename "$f"): (no Status line)"; found=1 ;;
    *) echo "  $(basename "$f"): $(printf '%s' "$line" | sed 's/^\*\*Status\*\* *//' | cut -c1-100)"; found=1 ;;
  esac
done
[ "$found" -eq 1 ] || echo "  none -- read the 'decided, unbuilt' table in compiler/features/README.md"

echo "== decided, unbuilt (features README)"
grep -n -i 'decided, unbuilt\|decided-unbuilt' compiler/features/README.md | head -5 | sed 's/^/  /' || true
