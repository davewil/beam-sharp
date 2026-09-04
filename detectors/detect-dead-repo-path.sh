#!/usr/bin/env bash
#
# A DOCUMENT POINTING AT A FILE THIS REPOSITORY DOES NOT HAVE.
#
# `check-links.sh` exists for exactly this and is scoped to the shipping package.
# Its own header records what it found there: "the shipping package carried 25
# citations of `examples/<name>.bs` paths that had not existed since F15 made a
# module a DIRECTORY". The design record was left out on purpose and has never
# been covered — `5abb590`: "nothing under `wayfinder/` is gated, so nothing
# noticed"; `caa3c52`: "wayfinder/ is outside check-links and check-shell, so
# both were run by hand on the new files — two guessed ticket filenames were
# caught and fixed"; and `ENG-304` records that nothing under `handoff/` is
# link-gated either.
#
# By hand, when somebody remembers, is the state `check-map.sh` was in for the
# six days before it was wired.
#
# ---------------------------------------------------------------------------
# THE ANCHOR RULE, AND WHY IT IS NOT A LIST OF DIRECTORIES.
#
# `wayfinder/research/` is a citation index of OTHER projects: Elixir's
# `lib/elixir/pages/references/typespecs.md`, the C# LDM's
# `meetings/2026/LDM-2026-02-09.md`, Elm's `book/interop/ports.md`. Those paths
# are not here and must not be. A detector that checks every path-shaped code
# span reports 40 findings and no defects.
#
# So a citation is judged only when its FIRST SEGMENT names a directory that
# actually exists — at the repo root, or at any ancestor of the citing file.
# `stdlib-7.3/` and `meetings/` name nothing here, so those citations are
# somebody else's tree and are skipped. `compiler/`, `bin/`, `prototypes/` and
# `examples/` do, so a citation into one of them is a claim about THIS repository
# and is checked.
#
# Measured: the rule takes the same corpus from 40 findings to 3, and all three
# are real — a `bin/spec-check.sh` that lives in `compiler/bin/`, an
# `examples/math.bs` from before F15 made a module a directory, and a
# `Shop/Collections/List/List.bs` renamed to `Ints` two days ago by `728f439`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The design record and the shipping package: what `check-links.sh` does not read.
SCAN_GLOBS=('wayfinder/issues/*.md' 'wayfinder/decisions.md' 'wayfinder/map.md'
            'wayfinder/fog.md' 'wayfinder/scope.md' 'handoff/*.md' 'handoff/**/*.md'
            'compiler/features/*.md' 'reports/*.md')

PATH_RE='`[A-Za-z0-9_][A-Za-z0-9_./-]*\.(bs|erl|xrl|yrl|sh|py|md|json|yml|beam|abstr)`'

dead_paths_in() {
  local f="$1" base="${2:-$ROOT}" p seg d anchored ok line ln
  grep -noE "$PATH_RE" "$f" 2>/dev/null | while IFS= read -r line; do
    ln="${line%%:*}"
    p="$(printf '%s' "$line" | sed -E 's/^[0-9]+://; s/`//g')"
    # A bare filename claims nothing about where it lives.
    case "$p" in */*) ;; *) continue ;; esac
    seg="${p%%/*}"
    d="$(dirname "${f#"$base"/}")"
    anchored=""; ok=""
    while :; do
      if [ "$d" = "." ]; then
        if [ -d "$base/$seg" ]; then anchored=1; fi
        if [ -e "$base/$p" ]; then ok=1; fi
        break
      fi
      if [ -d "$base/$d/$seg" ]; then anchored=1; fi
      if [ -e "$base/$d/$p" ]; then ok=1; fi
      d="$(dirname "$d")"
    done
    if [ -z "$anchored" ]; then
      continue
    fi
    if [ -n "$ok" ]; then
      continue
    fi
    printf '%s:%s: `%s` — the `%s/` directory is here and that path is not\n' \
           "${f#"$base"/}" "$ln" "$p" "$seg"
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/compiler/examples" "$CTL/docs" "$CTL/prototypes"
  : > "$CTL/compiler/examples/real.bs"
  : > "$CTL/prototypes/p1.erl"

  printf 'see `compiler/examples/gone.bs` for it\n'      > "$CTL/docs/dead.md"
  printf 'see `compiler/examples/real.bs` for it\n'      > "$CTL/docs/live.md"
  printf 'see `stdlib-7.3/src/gen_server.erl` upstream\n' > "$CTL/docs/external.md"
  printf 'see `prototypes/p1.erl` beside this\n'          > "$CTL/docs/sibling.md"
  printf 'the function `to_pattern/1` and file `README.md`\n' > "$CTL/docs/bare.md"

  fail=0
  red() { [ -z "$(dead_paths_in "$CTL/docs/$1" "$CTL")" ] && { echo "SELF-TEST FAILED: $1 — $2"; fail=1; }; return 0; }
  green() {
    local out; out="$(dead_paths_in "$CTL/docs/$1" "$CTL")"
    [ -n "$out" ] && { echo "SELF-TEST FAILED: $1 — $2"; printf '  reported: %s\n' "$out"; fail=1; }
    return 0
  }

  red dead.md 'a path into a directory that IS here, naming a file that is not, was not
                  reported. That is the 25 stale examples/<name>.bs citations F15 left' 
  green live.md     "a path that resolves was reported"
  green external.md "a citation of another project's tree was reported. wayfinder/research
                  is full of them and reporting them is 40 findings and no defects"
  green sibling.md  'a path resolving against an ANCESTOR of the citing file was reported -
                  wayfinder/issues/*.md cite prototypes/... meaning wayfinder/prototypes' 
  green bare.md     'a bare filename was reported. to_pattern/1 is an arity span and
                  README.md names no directory, so neither is a claim about a location' 

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the dead repo-internal path; accepted a live one, an"
    echo "           external tree, an ancestor-relative one and a bare name"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-dead-repo-path.sh [--self-test]"; exit 2; }

cd "$ROOT"
scanned=0
findings=""
while IFS= read -r f; do
  [ -f "$ROOT/$f" ] || continue
  scanned=$((scanned + 1))
  out="$(dead_paths_in "$ROOT/$f")"
  [ -n "$out" ] && findings+="$out"$'\n'
done < <("${GIT:-git}" ls-files -- "${SCAN_GLOBS[@]}" | sort -u)

if [ "$scanned" -eq 0 ]; then
  echo "no documents scanned — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "check-links.sh reads the shipping package and stops there. These are the design"
  echo "record and the handoff, which nothing has ever read — and a path that rots there"
  echo "is found by somebody walking into it, which is how two guessed ticket filenames"
  echo "reached a commit."
  exit 1
fi

echo "$scanned documents outside check-links.sh cite only paths this repository has"
