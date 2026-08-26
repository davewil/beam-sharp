#!/usr/bin/env bash
#
# THE PACKAGE THAT SHIPS MUST STAND ALONE, AND UNTIL NOW NOTHING BUILT ONE.
#
# WHY THIS EXISTS
# `check-links.sh` guards the shipping documents where they sit in the source
# tree. That is a different question from the one a clean-room recipient asks,
# and the gap between them is not small:
#
#   1. THE PACKAGE WAS DEFINED BY EXCLUSION, INSIDE A GATE. The list of what
#      ships lived in `check-links.sh`'s `DOCS` array, so the only thing that
#      knew the package's boundary was the script checking it. Nothing else
#      could read it, and nothing assembled it.
#
#   2. REFERENCES OUT OF THE PACKAGE WERE COUNTED AND ALLOWED. That gate's
#      `wayfinder_links` counter reports them and passes — deliberately, with a
#      comment saying the question is bigger than that gate. It is: measured
#      2026-08-26, the package carried **115 references into `wayfinder/`**, 98
#      of them across 27 of the 28 feature files. Every one is a live link in
#      the source tree and a dead pointer in a recipient's hands.
#
#   3. NOTHING VERIFIED THE ASSEMBLED THING. Every existing gate runs against
#      the repository. A recipient does not have the repository — that is the
#      entire premise of a clean-room handoff — so a gate that never leaves the
#      source tree cannot see the defect class that matters here.
#
# WHAT IT CHECKS, and each one is a criterion nothing else covers:
#
#   1. THE MANIFEST COVERS THE SOURCE TREE. Every `.md` under `compiler/features`
#      and every `.bs` under `compiler/examples` that exists on disk is named by
#      the manifest. This is the check that a manifest-versus-artifact
#      comparison cannot make: truncate both together and they agree perfectly
#      while half the specification goes missing. See control 3 below.
#
#   2. THE ARTIFACT CONTAINS EVERYTHING THE MANIFEST NAMES.
#
#   3. THE ARTIFACT REFERS ONLY TO ITSELF. Every relative markdown link resolves
#      inside the artifact, and no path into excluded material appears anywhere
#      in it — as prose or as a link. Strict on purpose: a sentence pointing at
#      `wayfinder/` is not a broken link, it is an instruction the reader cannot
#      follow, which is the same defect wearing a different shape.
#
#   4. PROVENANCE IS RECORDED AND TRUE. Source revision, the pinned toolchain,
#      and a checksum per file that matches the bytes actually shipped.
#
#   5. THE BUILD IS DETERMINISTIC. Two builds, to two DIFFERENT output paths,
#      produce identical manifests and identical checksums. The differing path
#      is the point: a builder that embeds its own absolute path passes a
#      same-path comparison and ships a package pinned to the machine that made
#      it. Build time is excluded from the lock rather than compared, because
#      comparing two constants measured in the same second proves nothing.
#
#   6. THE ARTIFACT AGREES WITH THE COMPILER. The examples inside the artifact
#      are compiled by the reference compiler. This is the specification/compiler
#      boundary: it catches an artifact that is stale, truncated, or mangled by
#      the assembly transform in check 3.
#
#      THE REFERENCE COMPILER IS NOT IN THE ARTIFACT, AND THAT IS BY DESIGN.
#      A clean-room recipient implements the compiler FROM this package; the
#      package does not carry one. The gate reaches back into the source tree
#      for `bsc` deliberately, acting as the oracle a recipient does not have.
#
#      `exemplars/` is PRUNED, exactly as `ci.yml` prunes it: ticket 25's
#      exemplars are the compiler's target and none of them parses yet, so
#      recursing without the prune turns a must-run surface into a must-fail one.
#
# WHAT IT DOES NOT CHECK
# Whether the specification is CORRECT, or complete enough to implement from.
# That is the clean-room audition's job, and it is a separate issue. This gate
# proves the package is whole and self-contained, never that it is sufficient.
#
# Usage:  bin/check-handoff-package.sh [--self-test]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/handoff/MANIFEST"
BUILDER="$ROOT/bin/build-handoff.sh"

# A REFERENCE INTO EXCLUDED MATERIAL IS `wayfinder/` PLUS A PATH SEGMENT.
# BARE `wayfinder/` IS PROSE AND MUST SURVIVE.
#
# This distinction is the gate's, not a convenience. The first draft banned the
# string outright and was wrong in a way worth recording: the package's own
# explanation of its boundary is written with it. `LANGUAGE.md` tells its reader
# "we give an implementer this document and **no access to `wayfinder/`**";
# `README.md` says the design record is "deliberately **not** part of the
# shipping package". Those sentences are what stop a recipient hunting for
# material that was never meant to be theirs. Deleting them to satisfy a gate
# would remove the package's answer to the exact question the gate is about.
#
# So: naming the excluded directory is honest, and naming a FILE INSIDE IT is
# the defect — a pointer the reader cannot follow.
EXCLUDED_RE='wayfinder/[A-Za-z0-9_]'

# ---------------------------------------------------------------------------
# Helpers, written as functions so --self-test drives the identical code over a
# damaged artifact rather than over a copy of its logic. A control that
# exercises a second implementation of the check proves only that the copy works.
# ---------------------------------------------------------------------------

# Expand the manifest into a list of repo-relative paths.
#   file <path>              a single file
#   tree <dir> <pattern>     every match of `find <dir> -name <pattern>`
manifest_paths() {
    local mf="$1" root="$2" kind a b
    while read -r kind a b; do
        case "$kind" in
            ''|'#'*) continue ;;
            file)    printf '%s\n' "$a" ;;
            tree)    ( cd "$root" && find "$a" -name "$b" -type f ) ;;
            *)       printf 'MANIFEST: unknown entry kind %s\n' "$kind" >&2; return 1 ;;
        esac
    done < "$mf" | LC_ALL=C sort -u
}

# Check 1: everything on disk in the specification trees is named by the
# manifest. Returns the paths the manifest missed.
# EVERY file in these trees, not `*.md` and `*.bs`. The narrower version was
# written first and could not have caught the defect that motivated the check:
# `compiler/examples/exemplars/FRONTIER` has no extension, is linked twice from
# the exemplars README, and was missing from the first manifest. A check that
# enumerates by file type shares the manifest's blind spot instead of covering
# it, which makes it agreement rather than verification.
manifest_gaps() {
    local root="$1" listed="$2" f
    {
        ( cd "$root" && find compiler/features -type f )
        ( cd "$root" && find compiler/examples -type f )
    } | LC_ALL=C sort -u | while IFS= read -r f; do
        grep -qxF "$f" "$listed" || printf '%s\n' "$f"
    done
}

# Check 2: paths the manifest names that the artifact does not contain.
# A FUNCTION SO THE SELF-TEST DRIVES THIS CODE AND NOT A COPY OF IT. Written
# inline in both places, the controls below would prove that the control's own
# loop can spot a missing file — which nobody doubted — while saying nothing
# about the loop the gate actually runs.
artifact_gaps() {
    local art="$1" listed="$2" p
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ -e "$art/$p" ] || printf '%s\n' "$p"
    done < "$listed"
}

# Check 3: relative markdown links in an artifact that do not resolve inside it.
# `examples/...` resolves against `compiler/`, the base every command in these
# documents is written from — the same rule `check-links.sh` uses.
dangling_refs() {
    local art="$1" doc dir link clean target
    while IFS= read -r doc; do
        dir="$(dirname "$doc")"
        while IFS= read -r link; do
            [ -n "$link" ] || continue
            case "$link" in http://*|https://*|mailto:*|'#'*) continue ;; esac
            clean="${link%%#*}"; clean="${clean%% *}"
            [ -n "$clean" ] || continue
            case "$clean" in
                examples/*|exemplars/*) target="$art/compiler/$clean" ;;
                /*)                     target="$art/${clean#/}" ;;
                *)                      target="$dir/$clean" ;;
            esac
            [ -e "$target" ] || printf '%s -> %s\n' "${doc#"$art"/}" "$clean"
        done < <(grep -o ']([^)]*)' "$doc" 2>/dev/null | sed 's/^](//; s/)$//')
    done < <(find "$art" -name '*.md' -type f | LC_ALL=C sort)
}

# Check 5b: files naming the directory the artifact was built at. A function so
# the control below drives this code rather than a copy of the grep.
path_leaks() {
    local dir="$1" marker="$2"
    grep -rl "$marker" "$dir" 2>/dev/null | sed "s|^$dir/||" || true
}

# Check 3, second half: any mention at all of excluded material.
excluded_mentions() {
    local art="$1"
    grep -rIl "$EXCLUDED_RE" "$art" 2>/dev/null | sed "s|^$art/||" || true
}

# ---------------------------------------------------------------------------
# --self-test
#
# THREE CONTROLS, and the third is the one that earns the gate.
#
#   1. A FILE THE MANIFEST NAMES IS DELETED from the artifact. Check 2 must see
#      it. This is the obvious control and the weakest.
#
#   2. A DOCUMENT REFERS OUT OF THE ARTIFACT — a link into `wayfinder/`, which
#      is the exact defect measured 115 times in the real package. Check 3 must
#      see it.
#
#   3. THE MANIFEST AND THE ARTIFACT ARE TRUNCATED TOGETHER, so they agree.
#      Nothing is missing relative to the manifest and nothing dangles; a gate
#      that only cross-checks the two goes green while shipping a package with
#      half its specification removed. Only check 1 — the manifest against the
#      source tree — can see this, and without this control there is no evidence
#      check 1 does anything at all.
#
# A POSITIVE CONTROL STANDS BESIDE ALL THREE: the undamaged artifact must pass.
# A gate that fires on everything satisfies the red half and is worthless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT
    fails=0

    say_fail() { echo "SELF-TEST FAILED: $1"; fails=1; }

    # The positive control: a real build, undamaged.
    if ! "$BUILDER" --out "$CTL/good" >/dev/null 2>&1; then
        echo "SELF-TEST FAILED: the builder could not produce an artifact at all,"
        echo "                  so none of the controls below mean anything."
        exit 1
    fi
    cp "$MANIFEST" "$CTL/manifest-good"

    manifest_paths "$CTL/manifest-good" "$ROOT" > "$CTL/listed-good"

    # --- control 1: a file the manifest names is missing from the artifact ---
    cp -R "$CTL/good" "$CTL/c1"
    victim="$(grep -m1 'compiler/features/.*\.md' "$CTL/listed-good")"
    rm -f "$CTL/c1/$victim"
    missing="$(artifact_gaps "$CTL/c1" "$CTL/listed-good" | wc -l | tr -d ' ')"
    [ "$missing" -gt 0 ] || say_fail "control 1 — a file named by the manifest was deleted from the
                  artifact and check 2 did not notice. The gate cannot tell a
                  complete package from a truncated one."

    # --- control 2: a document refers out of the artifact -------------------
    cp -R "$CTL/good" "$CTL/c2"
    printf '\nSee [ticket 99](../../wayfinder/issues/99-nope.md) for the rationale.\n' \
        >> "$CTL/c2/LANGUAGE.md"
    d2="$(dangling_refs "$CTL/c2" | wc -l | tr -d ' ')"
    e2="$(excluded_mentions "$CTL/c2" | wc -l | tr -d ' ')"
    [ "$d2" -gt 0 ] || say_fail "control 2 — a link into wayfinder/ was added to LANGUAGE.md and
                  check 3 resolved it anyway. This is the 115-reference defect
                  the gate exists for."
    [ "$e2" -gt 0 ] || say_fail "control 2 — a mention of excluded material went unreported."

    # --- control 3: manifest and artifact truncated TOGETHER ----------------
    # The over-informed stub. Both agree; only the source tree disagrees.
    cp -R "$CTL/good" "$CTL/c3"
    grep -v '^tree compiler/features' "$CTL/manifest-good" > "$CTL/manifest-c3"
    rm -rf "$CTL/c3/compiler/features"
    manifest_paths "$CTL/manifest-c3" "$ROOT" > "$CTL/listed-c3"
    # Cross-checking manifest against artifact is CLEAN here, which is the point.
    agree="$(artifact_gaps "$CTL/c3" "$CTL/listed-c3" | wc -l | tr -d ' ')"
    if [ "$agree" -ne 0 ]; then
        say_fail "control 3 is not testing what it claims — the truncated pair did not
                  actually agree, so a green here would not prove check 1 ran."
    fi
    g3="$(manifest_gaps "$ROOT" "$CTL/listed-c3" | wc -l | tr -d ' ')"
    [ "$g3" -gt 0 ] || say_fail "control 3 — the manifest was truncated to match a truncated artifact
                  and check 1 did not notice. The two agreed with each other
                  while 28 feature files went missing, which is precisely the
                  package a manifest-versus-artifact gate ships happily."

    # --- control 4: the artifact names the path it was built at -------------
    # Check 5a cannot see this — two builds to different directories produce
    # byte-identical locks whether or not the documents embed a build path, so
    # without this control there is no evidence check 5b does anything.
    cp -R "$CTL/good" "$CTL/c4"
    printf '\nBuilt at /var/folders/xx/a-marker-path-nobody-would-write.\n' \
        >> "$CTL/c4/LANGUAGE.md"
    l4="$(path_leaks "$CTL/c4" 'a-marker-path-nobody-would-write' | wc -l | tr -d ' ')"
    [ "$l4" -gt 0 ] || say_fail "control 4 — a build path was embedded in a shipped document and check
                  5b did not notice, so the package could be pinned to one
                  machine's temp directory while the determinism check reports
                  two identical builds."

    # --- the positive control: undamaged must pass all four -----------------
    gg="$(manifest_gaps "$ROOT" "$CTL/listed-good" | wc -l | tr -d ' ')"
    dg="$(dangling_refs "$CTL/good" | wc -l | tr -d ' ')"
    eg="$(excluded_mentions "$CTL/good" | wc -l | tr -d ' ')"
    mg="$(artifact_gaps "$CTL/good" "$CTL/listed-good" | wc -l | tr -d ' ')"
    if [ "$gg" -ne 0 ] || [ "$dg" -ne 0 ] || [ "$eg" -ne 0 ] || [ "$mg" -ne 0 ]; then
        say_fail "the POSITIVE control failed — an undamaged artifact was rejected
                  (manifest gaps $gg, dangling $dg, excluded $eg, missing $mg).
                  A gate that fires on everything discriminates nothing."
    fi

    if [ "$fails" -eq 0 ]; then
        echo "self-test: caught the missing file, the reference out of the package, the"
        echo "           manifest truncated to agree with a truncated artifact, and an"
        echo "           embedded build path; accepted the undamaged build — the gate"
        echo "           discriminates"
        exit 0
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# The gate proper.
# ---------------------------------------------------------------------------
[ -f "$MANIFEST" ] || { echo "no handoff/MANIFEST — the package has no definition"; exit 1; }
[ -x "$BUILDER" ]  || { echo "no executable bin/build-handoff.sh — nothing assembles the package"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

echo
echo "the handoff package stands alone"
echo

# Built OUTSIDE the source tree, and verified from there. `mktemp -d` is not
# under $ROOT, so nothing below can reach the repository by accident.
"$BUILDER" --out "$WORK/artifact" >"$WORK/build.log" 2>&1 || {
    echo "  FAILED to assemble the artifact:"
    sed 's/^/    /' "$WORK/build.log"
    exit 1
}
ART="$WORK/artifact"

manifest_paths "$MANIFEST" "$ROOT" > "$WORK/listed"
listed_n="$(wc -l < "$WORK/listed" | tr -d ' ')"

# --- 1: the manifest covers the source tree ---------------------------------
gaps="$(manifest_gaps "$ROOT" "$WORK/listed")"
if [ -n "$gaps" ]; then
    printf '%s\n' "$gaps" | while IFS= read -r g; do echo "  UNSHIPPED  $g"; done
    fail=1
fi

# --- 2: the artifact contains everything the manifest names -----------------
miss="$(artifact_gaps "$ART" "$WORK/listed")"
if [ -n "$miss" ]; then
    printf '%s\n' "$miss" | while IFS= read -r m; do echo "  MISSING    $m"; done
    fail=1
fi

# --- 3: the artifact refers only to itself ----------------------------------
dang="$(dangling_refs "$ART")"
if [ -n "$dang" ]; then
    printf '%s\n' "$dang" | while IFS= read -r d; do echo "  DANGLING   $d"; done
    fail=1
fi
exc="$(excluded_mentions "$ART")"
if [ -n "$exc" ]; then
    printf '%s\n' "$exc" | while IFS= read -r e; do echo "  EXCLUDED   $e mentions excluded material"; done
    fail=1
fi

# --- 4: provenance is recorded and true -------------------------------------
LOCK="$ART/MANIFEST.lock"
if [ ! -f "$LOCK" ]; then
    echo "  NO LOCK    the artifact records no manifest of what it contains"
    fail=1
else
    for field in revision erlang rebar node tree-sitter; do
        grep -q "^# $field:" "$LOCK" || { echo "  NO PROV    $field is not recorded"; fail=1; }
    done
    # Every checksum in the lock must match the bytes actually shipped.
    bad=0
    while read -r sum path; do
        case "$sum" in '#'*|'') continue ;; esac
        [ -f "$ART/$path" ] || { bad=$((bad + 1)); continue; }
        actual="$(shasum -a 256 "$ART/$path" | awk '{print $1}')"
        [ "$actual" = "$sum" ] || { echo "  CHECKSUM   $path does not match the lock"; bad=$((bad + 1)); }
    done < "$LOCK"
    [ "$bad" -eq 0 ] || fail=1
fi

# --- 5: the build is deterministic ------------------------------------------
SECOND="$WORK/second-build-at-a-quite-different-path"
"$BUILDER" --out "$SECOND" >/dev/null 2>&1

# 5a: two builds agree.
if ! diff -q "$ART/MANIFEST.lock" "$SECOND/MANIFEST.lock" >/dev/null 2>&1; then
    echo "  NONDETERM  two builds to different paths disagree:"
    diff "$ART/MANIFEST.lock" "$SECOND/MANIFEST.lock" | head -10 | sed 's/^/    /'
    fail=1
fi

# 5b: THE ARTIFACT DOES NOT NAME THE PATH IT WAS BUILT AT.
#
# This is a SEPARATE check because 5a cannot make it. The lock records
# artifact-relative paths and a revision derived from the tree, so two builds
# to different directories produce byte-identical locks whether or not the
# builder embedded its output path in the files. 5a would compare equal and
# report determinism while every document carried one machine's temp directory.
#
# The second build's directory has a deliberately unmistakable name so this
# grep cannot match by coincidence.
leak="$(path_leaks "$SECOND" 'second-build-at-a-quite-different-path')"
if [ -n "$leak" ]; then
    echo "  PATHLEAK   the artifact names the directory it was built at:"
    printf '%s\n' "$leak" | sed 's/^/    /'
    fail=1
fi

# --- 6: the artifact agrees with the compiler -------------------------------
# The reference compiler is deliberately outside the artifact: a clean-room
# recipient BUILDS one from this package. Here it is the oracle.
BSC="$ROOT/compiler/_build/default/bin/bsc"
if [ ! -x "$BSC" ]; then
    echo "  NO BSC     the reference compiler is not built; run rebar3 escriptize in compiler/"
    fail=1
else
    # Run from INSIDE the artifact, exactly as `ci.yml` runs from `compiler/`:
    # `--src-root examples`, with the module named as `examples/<Name>`. Ticket
    # 41 §3 makes naming the root the caller's job, and the corpus holds dotted
    # modules — `Shop.Reports` lives at `Shop/Reports` — so the two must agree.
    #
    # Holding it wrong fails in the direction that lies. Passing a path with the
    # root already stripped makes `bsc` print its usage and exit non-zero, which
    # this loop would report as sixteen modules failing to compile when the
    # artifact is perfect and the gate is the thing that is broken.
    # A FRESH OUTPUT DIRECTORY PER MODULE, as `ci.yml` does with its own
    # `mktemp -d`. Sharing one directory lets a second module's beam overwrite a
    # first module's under the same name, with both compilations exiting 0 — the
    # count would still read 16 and one module's output would never have existed.
    compiled=0
    while IFS= read -r d; do
        out="$(mktemp -d "$WORK/out.XXXXXX")"
        if ! ( cd "$ART/compiler" && "$BSC" --src-root examples -o "$out" "$d" ) \
                >"$WORK/bsc.log" 2>&1; then
            echo "  NOCOMPILE  $d"
            sed 's/^/    /' "$WORK/bsc.log" | head -5
            fail=1
        else
            compiled=$((compiled + 1))
        fi
    done < <(
        cd "$ART/compiler" &&
        find examples -path examples/exemplars -prune -o -name '*.bs' -print |
        while IFS= read -r f; do dirname "$f"; done |
        LC_ALL=C sort -u
    )
    echo "  ok         $compiled example modules in the artifact compile"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "the package stands alone ($listed_n files, self-contained, reproducible)"
    exit 0
fi
echo "the package does NOT stand alone"
exit 1
