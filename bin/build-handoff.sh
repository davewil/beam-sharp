#!/usr/bin/env bash
#
# ASSEMBLE THE CLEAN-ROOM HANDOFF PACKAGE.
#
# Usage:  bin/build-handoff.sh --out <dir> [--self-test]
#
# WHAT THIS PRODUCES
# A directory that stands on its own: the specification, the compiler's feature
# record, the example corpus, and a `MANIFEST.lock` naming the source revision,
# the pinned toolchain, and a SHA-256 for every file shipped. `handoff/MANIFEST`
# is the only definition of what goes in; this script never names a path itself.
#
# THE ONE TRANSFORM, AND WHY IT IS NOT A CHEAT
# Markdown links into `wayfinder/` are FLATTENED — the visible text survives,
# the link target is dropped. `[ticket 35](../../wayfinder/issues/35-x.md)`
# ships as `ticket 35`.
#
# Measured 2026-08-26: the package carried 115 references into `wayfinder/`, 98
# of them across 27 of the 28 feature files, every one a visible link. In the
# source tree those citations are correct and valuable — a feature file naming
# the ticket it implements is the seam between the decision record and the
# build. In a recipient's hands the same link is a dead pointer into 4.1M of
# material they were deliberately not given.
#
# Flattening keeps the provenance and drops the pointer: a reader still learns
# that F3 implements ticket 33. Deleting the sentence would have lost that, and
# shipping the link would have failed the one criterion this package exists to
# meet — that every internal reference can be followed.
#
# BARE `wayfinder/` IS LEFT ALONE. `LANGUAGE.md` telling its reader they have
# "no access to `wayfinder/`" is the package explaining its own boundary, and
# that sentence is why a recipient does not go hunting. Only a path INTO the
# directory is a pointer; the directory's name is prose.
#
# DETERMINISM
# Nothing here depends on where the artifact is written, when it was written, or
# what order the filesystem hands back. Paths in the lock are artifact-relative,
# the file list is `LC_ALL=C sort`ed, and the build time is deliberately NOT
# recorded: a timestamp would make two identical packages compare unequal and
# turn `check-handoff-package.sh` check 5 into a test of the clock.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/handoff/MANIFEST"

OUT=""
SELFTEST=0
while [ $# -gt 0 ]; do
    case "$1" in
        --out)       OUT="${2:?--out needs a directory}"; shift 2 ;;
        --self-test) SELFTEST=1; shift ;;
        *)           echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

# --- the transform ----------------------------------------------------------
# Two rules, and the first is deliberately NOT a list of excluded directories.
#
#   1. FLATTEN ANY MARKDOWN LINK WHOSE TARGET IS NOT IN THE PACKAGE. Membership
#      is computed from the manifest, so the rule needs no denylist and cannot
#      go stale. The first draft flattened links into `wayfinder/` by name and
#      the gate immediately found four more classes it could not see —
#      `bin/check-toolchain.sh`, `bin/check-links.sh`, `../../bin/check-surface.sh`
#      and `../../reports/2026-08-15-aoc-and-state.md`. A denylist would have
#      needed all of them, and the next one too.
#
#   2. TRUNCATE A PATH INTO EXCLUDED MATERIAL TO ITS DIRECTORY. Rule 1 handles
#      links; this handles prose, which no link syntax marks. It is lossy by one
#      step — `wayfinder/prototypes/25b-x.md` ships as `wayfinder/` — and that is
#      the intended trade: the sentence keeps saying the thing came from the
#      design record, and stops naming a file the reader has not got.
#
# Bare `wayfinder/` is untouched by both, because the package explains its own
# boundary with it.
#
# WHY FLATTENING CANNOT HIDE ROT, WHICH IS THE OBVIOUS OBJECTION.
# Rule 1 removes any link that does not resolve in the package — including one
# that fails to resolve because it is a TYPO for a file that does ship. Left
# alone, that would make this script a laundry for broken links.
#
# It is not, because `check-links.sh` holds the source tree to a stricter rule
# and runs first: a dead relative link in a shipping document is a DEAD LINK
# there and the build goes red before assembly is ever reached. Verified rather
# than assumed — a deliberately misspelled `examples/exemplars/READMEE.md` in
# `compiler/README.md` is reported by that gate and exits 1, while this one
# flattens it and stays green. The division is the point: `check-links.sh` asks
# whether the documents are right, this asks whether the package is whole.

# Resolve `a/b/../c` textually. Not `realpath`: these paths name files in a
# package that is still being assembled, so nothing is on disk yet to resolve
# against, and a path that climbs out of the package must stay visible as `..`
# rather than being silently rebased onto something that happens to exist.
#
# SEGMENT-WISE IN SHELL, NOT `sed`, AND THAT IS THE SECOND PORTABILITY TRAP IN
# THIS FILE. The first draft collapsed `..` with
# `sed 's#\(^\|/\)\([^/]\{1,\}\)/\.\./#\1#'`. GNU sed takes `\|` as alternation
# in a basic regex; BSD sed — which is what macOS has — takes it as a literal
# pipe, so the expression matched nothing, every path stayed unresolved, and
# every in-package link looked like it pointed outside. Silent, and in the
# expensive direction: the transform would have flattened the specification's
# own cross-references on the author's machine and behaved correctly in CI.
#
# A greedy `[^/]+` is wrong here too, for a reason worth stating: on `../../x`
# it eats the leading `..` as an ordinary segment and yields `x`, quietly
# turning a path that escapes the package into one that does not.
normalise() {
    local p="$1" seg out="" escaped=0 oldifs="$IFS"
    IFS='/'
    # Word-splitting on `/` is the point, so the expansion is deliberately bare.
    # shellcheck disable=SC2086
    set -- $p
    IFS="$oldifs"
    for seg in "$@"; do
        case "$seg" in
            ''|.) continue ;;
            ..)
                case "$out" in
                    '')   escaped=1 ;;
                    */*)  out="${out%/*}" ;;
                    *)    out="" ;;
                esac ;;
            *) out="${out:+$out/}$seg" ;;
        esac
    done
    if [ "$escaped" -eq 1 ]; then printf '..'; else printf '%s' "$out"; fi
}

# Is a link target part of the package? Files match exactly; a directory matches
# when the package holds anything beneath it.
in_package() {
    local dir="$1" link="$2" clean target
    case "$link" in http://*|https://*|mailto:*|'#'*|'') return 0 ;; esac
    clean="${link%%#*}"; clean="${clean%% *}"
    [ -n "$clean" ] || return 0
    case "$clean" in
        examples/*|exemplars/*) target="compiler/$clean" ;;
        /*)                     target="${clean#/}" ;;
        *)                      target="$dir/$clean" ;;
    esac
    target="$(normalise "$target")"
    case "$target" in *..*) return 1 ;; esac
    grep -qxF "$target" "$PKG_LIST" && return 0
    grep -q "^$(printf '%s' "$target" | sed 's#[][\.*^$/&]#\\&#g')/" "$PKG_LIST"
}

# Escape a string for use as a sed BRE, with `#` as the delimiter.
sed_escape() { printf '%s' "$1" | sed 's#[][\.*^$/&#]#\\&#g'; }

# Rule 2, on its own, so the self-test can drive it directly.
truncate_excluded() {
    sed -E 's#wayfinder/[A-Za-z0-9_.{}*/-]+#wayfinder/#g'
}

# Both rules over one file. `rel` is the file's repo-relative path, which is what
# a relative link resolves against.
transform() {
    local src="$1" out="$2" rel="$3"
    local dir t tmp
    dir="$(dirname "$rel")"
    tmp="$out.tmp"
    cp "$src" "$tmp"

    # Rule 1 — links, .md only. A `.bs` file has no markdown links.
    case "$rel" in
        *.md)
            while IFS= read -r t; do
                [ -n "$t" ] || continue
                in_package "$dir" "$t" && continue
                sed -E "s#\\[([^][]*)\\]\\($(sed_escape "$t")\\)#\\1#g" "$tmp" > "$tmp.2"
                mv "$tmp.2" "$tmp"
            done < <(grep -o ']([^)]*)' "$tmp" | sed 's/^](//; s/)$//' | LC_ALL=C sort -u)
            ;;
    esac

    # Rule 2 — prose paths, every text file.
    truncate_excluded < "$tmp" > "$out"
    rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR CONTROLS. The transform is the only thing here that can be silently
# wrong — a file copy is either right or obviously broken — so it is what gets
# tested, and each control names a way the transform could be wrong while
# looking correct.
#
#   1. A LINK OUT OF THE PACKAGE LOSES ITS TARGET AND KEEPS ITS TEXT. Both
#      halves are asserted. A transform that deleted the whole citation would
#      satisfy "no dead link remains" while destroying the provenance that
#      flattening exists to preserve — a feature file that no longer says which
#      ticket it implements has lost the thing it is FOR.
#
#   2. A LINK INSIDE THE PACKAGE IS UNTOUCHED. Without this, a transform that
#      stripped every link would pass control 1 and quietly flatten the
#      specification's own cross-references. This is the control that makes
#      control 1 mean something.
#
#   3. A PROSE PATH INTO EXCLUDED MATERIAL IS TRUNCATED. No link syntax marks
#      these, so rule 1 cannot see them.
#
#   4. BARE `wayfinder/` SURVIVES. The package explains its own boundary with
#      that word; a transform that ate it would delete the sentences telling a
#      recipient they are not missing anything. This control exists because the
#      gate's first draft got exactly this wrong.
# ---------------------------------------------------------------------------
if [ "$SELFTEST" -eq 1 ]; then
    fails=0
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT

    # A package containing one file, so `in_package` has something to say yes to.
    PKG_LIST="$CTL/pkg"
    printf '%s\n' 'compiler/examples/README.md' > "$PKG_LIST"

    check() {  # check <label> <haystack> <needle> <want present|absent>
        case "$2" in
            *"$3"*) [ "$4" = present ] || { echo "SELF-TEST FAILED: $1"; fails=1; } ;;
            *)      [ "$4" = absent  ] || { echo "SELF-TEST FAILED: $1"; fails=1; } ;;
        esac
    }

    printf '%s\n' 'See [ticket 35](../../wayfinder/issues/35-names.md) for this.' > "$CTL/in1"
    transform "$CTL/in1" "$CTL/out1" "compiler/features/F3.md"
    got="$(cat "$CTL/out1")"
    check "control 1 — the link target survived, so the artifact ships the dead
                  pointer this exists to remove" "$got" "issues/35-names" absent
    check "control 1 — the link TEXT did not survive. Flattening must keep the
                  provenance; deleting the citation loses what a feature file is for" \
          "$got" "ticket 35" present

    printf '%s\n' 'See [the corpus](../examples/README.md) for this.' > "$CTL/in2"
    transform "$CTL/in2" "$CTL/out2" "compiler/features/F3.md"
    got2="$(cat "$CTL/out2")"
    check "control 2 — a link INSIDE the package was flattened. The transform is
                  stripping the specification's own cross-references, which makes
                  control 1 meaningless" "$got2" "](../examples/README.md)" present

    printf '%s\n' '// Source: wayfinder/prototypes/25b-x.md, section 1' > "$CTL/in3"
    transform "$CTL/in3" "$CTL/out3" "compiler/examples/exemplars/25b/a.bs"
    got3="$(cat "$CTL/out3")"
    check "control 3 — a prose path into excluded material was left naming a file
                  the reader has not got" "$got3" "prototypes/25b-x.md" absent

    printf '%s\n' 'You get this document and no access to `wayfinder/`.' > "$CTL/in4"
    transform "$CTL/in4" "$CTL/out4" "LANGUAGE.md"
    got4="$(cat "$CTL/out4")"
    check "control 4 — bare \`wayfinder/\` was eaten. That word is how the package
                  explains its own boundary, and removing it deletes the sentence
                  telling a recipient they are not missing anything" \
          "$got4" 'no access to `wayfinder/`' present

    if [ "$fails" -eq 0 ]; then
        echo "self-test: flattened the link out of the package keeping its text, left an"
        echo "           in-package link alone, truncated a prose path, and kept bare"
        echo "           wayfinder/ — the transform discriminates"
        exit 0
    fi
    exit 1
fi

[ -n "$OUT" ] || { echo "bin/build-handoff.sh --out <dir> is required" >&2; exit 2; }
[ -f "$MANIFEST" ] || { echo "no handoff/MANIFEST — the package has no definition" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT"

# Expand the manifest. Deliberately a SECOND implementation of the gate's
# `manifest_paths`: the gate must be able to disagree with the builder, or it is
# only checking the builder's opinion of itself.
#
# THIS IS A FUNCTION BECAUSE macOS SHIPS BASH 3.2, AND THAT IS NOT A STYLE
# CHOICE. Written inline as `paths="$( while read ... case ... '#'* ... )"` it
# parses correctly under bash 5 and is MIS-PARSED under 3.2.57: inside `$( )`
# that shell treats the quoted `'#'` as starting a comment and swallows the rest
# of the `case`, so the loop runs a truncated body and dies on an unbound
# variable three lines further down. A function defined at top level is outside
# the command substitution and parses the same under both.
#
# Worth stating plainly, because the failure mode is the dangerous direction:
# CI runs `ubuntu-latest` with bash 5, where the inline form WORKS. The bug was
# green in CI and red on the author's machine.
expand_manifest() {
    while read -r kind a b; do
        case "$kind" in
            ''|[#]*) continue ;;
            file)    printf '%s\n' "$a" ;;
            tree)    ( cd "$ROOT" && find "$a" -name "$b" -type f ) ;;
            *)       echo "MANIFEST: unknown entry kind $kind" >&2; return 1 ;;
        esac
    done < "$MANIFEST" | LC_ALL=C sort -u
}

paths="$(expand_manifest)"

# The package's contents, decided BEFORE a single file is written. `transform`
# asks this list whether a link target ships, so it has to be complete first —
# a transform that consulted a half-built output directory would flatten every
# link to a file that merely had not been copied yet, and the result would
# depend on the order `find` happened to return.
PKG_LIST="$(mktemp)"
trap 'rm -f "$PKG_LIST"' EXIT
printf '%s\n' "$paths" > "$PKG_LIST"

n=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ ! -f "$ROOT/$p" ]; then
        echo "MANIFEST names a file that does not exist: $p" >&2
        exit 1
    fi
    mkdir -p "$OUT/$(dirname "$p")"
    # Text files are transformed; anything else is copied byte-for-byte. The
    # test is on content, not extension: `FRONTIER` carries no suffix and is
    # plain text that names paths like any other document.
    if LC_ALL=C grep -qI . "$ROOT/$p" 2>/dev/null || [ ! -s "$ROOT/$p" ]; then
        transform "$ROOT/$p" "$OUT/$p" "$p"
    else
        cp "$ROOT/$p" "$OUT/$p"
    fi
    n=$((n + 1))
done <<< "$paths"

# --- provenance -------------------------------------------------------------
# The revision is what a recipient quotes when they report a defect. `-dirty` is
# recorded rather than refused: a package built from uncommitted work is a real
# thing to do, and silently calling it the parent commit is the lie.
rev="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo unknown)"
if [ -n "$(cd "$ROOT" && git status --porcelain 2>/dev/null)" ]; then
    rev="$rev-dirty"
fi

tool() { grep -E "^$1 " "$ROOT/.tool-versions" | awk '{print $2}'; }

LOCK="$OUT/MANIFEST.lock"
{
    echo "# The contents of this package, and where it came from."
    echo "#"
    echo "# Rebuild with: ./bin/build-handoff.sh --out <dir>  at the revision below."
    echo "# Every line after the header is: <sha256>  <path relative to this file>."
    echo "#"
    echo "# NO BUILD TIME IS RECORDED. Two builds of one revision are the same package,"
    echo "# and a timestamp would make them compare unequal — which would turn the"
    echo "# determinism check into a test of the clock."
    echo "#"
    echo "# revision: $rev"
    echo "# erlang: $(tool erlang)"
    echo "# rebar: $(tool rebar)"
    echo "# node: $(tool node)"
    echo "# tree-sitter: $(tool tree-sitter)"
    echo "# files: $n"
    echo "#"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf '%s  %s\n' "$(shasum -a 256 "$OUT/$p" | awk '{print $1}')" "$p"
    done <<< "$paths"
} > "$LOCK"

echo "handoff package assembled: $n files at $OUT"
echo "  revision $rev"
