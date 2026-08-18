#!/usr/bin/env bash
#
# The clean-room handoff package must not point at things the reader will not have.
#
# WHY THIS EXISTS
# The package that ships is `LANGUAGE.md`, `CONTEXT.md`, `PRELUDE.md`,
# `compiler/features/` and `compiler/examples/`. `wayfinder/` — 4.1M of tickets,
# research and prototypes — does NOT ship. Measured 2026-08-18, that package
# carried 341 references out of itself and, worse, **26 citations of
# `examples/<name>.bs` paths that had not existed since F15** made a module a
# DIRECTORY. Nothing caught it, because every gate in this repo checks that the
# compiler is right and none checks that the documents are.
#
# A dead path is the sharpest kind of rot: it is not a matter of taste or of
# emphasis, it is a lie the package tells a reader who cannot ask a question. The
# whole point of the handoff is that there is nobody to ask.
#
# WHAT IT CHECKS
#   1. Every relative markdown link in a shipping document resolves to a file
#      that exists. Links INTO `wayfinder/` are reported separately and do not
#      fail — the feature files legitimately cite the tickets they implement, and
#      deciding what to do about that is a bigger question than this gate.
#   2. Every `examples/...` path named in prose resolves. These are the ones that
#      rot silently, because they are not links and no renderer ever tries them.
#   3. `LANGUAGE.md` obeys its own stated rule. Its opening calls it
#      "load-bearing rather than tidy": the prose carries no ticket numbers,
#      because the handoff gives an implementer that document and no access to
#      `wayfinder/`. Traceability lives in HTML comments the reader never sees,
#      so those are exempt — as are fenced code blocks.
#
# WHAT IT DOES NOT CHECK
# Whether a link points at the RIGHT thing. A path that resolves to the wrong
# file passes here, exactly as `check-tokens.sh` proves a keyword is present and
# never that its rule is correct.
#
# Usage:  bin/check-links.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# The shipping package. `compiler/README.md` and the exemplars README are in it
# too: they are the first files a reader opens, being the index of the features
# and of the target corpus respectively.
DOCS=(
    LANGUAGE.md
    TOUR.md
    CONTEXT.md
    PRELUDE.md
    compiler/README.md
    compiler/examples/exemplars/README.md
)
while IFS= read -r f; do DOCS+=("$f"); done < <(find compiler/features -name '*.md' | sort)
# The corpus itself. Every example opens with the command that runs it, and a
# command naming a path that moved is the same rot in a place a reader is even
# more likely to type. `Totals.bs` was still advertising `examples/collections/`
# two module-system features after that directory stopped existing.
while IFS= read -r f; do DOCS+=("$f"); done < <(find compiler/examples -name '*.bs' | sort)

fail=0
wayfinder_links=0

# --- 1 + 2: paths ------------------------------------------------------------
# `examples/...` resolves against `compiler/`, which is where the corpus lives —
# the same base every command in these documents is written from.
resolve() {
    local base_dir="$1" path="$2"
    case "$path" in
        examples/*|exemplars/*) printf '%s\n' "compiler/$path" ;;
        /*)                     printf '%s\n' ".${path}" ;;
        *)                      printf '%s\n' "$base_dir/$path" ;;
    esac
}

echo
echo "paths named by the shipping package"
echo

for doc in "${DOCS[@]}"; do
    [ -f "$doc" ] || { echo "  MISSING   $doc"; fail=1; continue; }
    dir="$(dirname "$doc")"
    bad=0

    # Markdown links, minus URLs and bare anchors. The trailing `#anchor` and any
    # `"title"` are stripped before resolving.
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        case "$link" in http://*|https://*|mailto:*|'#'*) continue ;; esac
        clean="${link%%#*}"; clean="${clean%% *}"
        [ -n "$clean" ] || continue
        case "$clean" in wayfinder/*|*/wayfinder/*)
            wayfinder_links=$((wayfinder_links + 1)); continue ;;
        esac
        target="$(resolve "$dir" "$clean")"
        if [ ! -e "$target" ]; then
            echo "  DEAD LINK $doc -> $clean"
            bad=1; fail=1
        fi
    done < <(grep -oE '\]\([^)]+\)' "$doc" | sed -E 's/^\]\(//; s/\)$//')

    # Bare `examples/...bs` paths in prose. Not links, so nothing else ever tries
    # them — which is exactly why 26 of them rotted through an entire refactor.
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        target="$(resolve "$dir" "$p")"
        if [ ! -e "$target" ]; then
            echo "  DEAD PATH $doc -> $p"
            bad=1; fail=1
        fi
    # NOT excluding backticks: `examples/shop.bs` in code style is still a claim
    # about a path, and it is how nearly every one of these is written. An earlier
    # draft of this line excluded a preceding backtick and therefore reported 6
    # dead paths where there were 10 — a gate quietly checking almost nothing,
    # which is the failure this repo has now hit three times.
    done < <(grep -oE 'examples/[A-Za-z0-9_/.-]+\.bs' "$doc" | sort -u)

    [ "$bad" -eq 0 ] && printf '  %-9s %s\n' "ok" "$doc"
done

# --- 3: LANGUAGE.md's own rule ----------------------------------------------
# HTML comments are stripped first (that IS the traceability convention), then
# fenced blocks, then what is left is what a reader actually sees.
echo
echo "LANGUAGE.md's own rule: no ticket numbers in visible prose"
echo

# One pass, carrying the TRUE line number. An earlier draft stripped comments
# with perl first and numbered the result, which shifts every line after a
# multi-line comment — and then ran `grep -n` over a stream that was already
# numbered, so each report carried two numbers and neither was right. A
# diagnostic that misreports its own location is the defect ticket 40 §2 named.
VISIBLE="$(awk '
  {
    line = $0
    # A comment may open and close on one line, or span many.
    while (1) {
      if (incomment) {
        i = index(line, "-->")
        if (i == 0) { line = ""; break }
        line = substr(line, i + 3); incomment = 0
      } else {
        i = index(line, "<!--")
        if (i == 0) break
        head = substr(line, 1, i - 1); rest = substr(line, i + 4)
        incomment = 1
        j = index(rest, "-->")
        if (j == 0) { line = head; break }
        line = head substr(rest, j + 3); incomment = 0
      }
    }
    if ($0 ~ /^```/) { infence = !infence; next }
    if (infence) next
    if (line != "") print NR": "line
  }' LANGUAGE.md)"

# `Ticket NN` and the bare `NN §M` shorthand. `§` is rare enough elsewhere that
# the second pattern does not need guarding. No `-n` — the stream is numbered.
OFFENDERS="$(printf '%s\n' "$VISIBLE" \
             | grep -E '[Tt]ickets? [0-9]+|(^|[^0-9])[0-9]{1,2} §' || true)"

if [ -z "$OFFENDERS" ]; then
    echo "  ok        no ticket citation in visible prose"
else
    printf '%s\n' "$OFFENDERS" | sed 's/^/  CITES    /'
    n="$(printf '%s\n' "$OFFENDERS" | grep -c '' || true)"
    echo
    echo "  $n line(s) name a ticket the clean-room reader has no access to."
    echo "  Move the citation into an HTML comment, or say the thing instead."
    fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "the package points only at things it ships ($wayfinder_links wayfinder links, allowed)"
else
    echo "the package points at something the reader will not have."
    exit 1
fi
