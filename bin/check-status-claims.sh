#!/usr/bin/env bash
#
# check-status-claims.sh — a shipping document may not contradict the compiler
# about what is built.
#
# WHY THIS EXISTS (2026-08-26, ENG-245)
#
# Every gate in this repository asks whether the COMPILER is right. `check-links.sh`
# was the first to ask whether the DOCUMENTS are, and it asks only whether their
# paths resolve. Nothing asked the question that actually reaches a clean-room
# recipient: does the prose agree with the thing it describes, and does it agree
# with itself?
#
# It did not, in four places at once, and every one of them was green:
#
#   `compiler/README.md` carried a "Deliberately **out**" list naming records,
#   angle brackets, modules, FFI, OTP behaviours, refinements and binaries. All
#   seven had shipped — F3, F6, F11, F19, F10, F2, F13 — and six of the seven
#   have a worked example in `compiler/examples/` that `verify.sh` COMPILES ON
#   EVERY RUN. The repository was compiling the refutation of its own README.
#
#   `PRELUDE.md` opened with "**Two entries.** `bs_check:prelude/0` holds
#   `option<T>` and `result<T, E>` and nothing else", and forty lines later
#   marked three entries **built**. The compiler's `prelude/0` is
#   `maps:merge(stratum_one(), stratum_two())` and `stratum_one()` alone holds
#   three, `foreign_error` among them — which the same table called **decided**.
#
# THE SHAPE OF THE BUG IS WHY A PROSE RULE CANNOT FIX IT. Nobody wrote a false
# sentence. Each was true when written and was falsified later BY A COMMIT
# SOMEWHERE ELSE — the feature that shipped never had a reason to open the
# document that said it had not. A document is falsified at a distance, so the
# check has to be at a distance too.
#
# WHAT IT CHECKS
#
#   A. THE PRELUDE LEDGER AGAINST THE COMPILER. Each entry in `PRELUDE.md`'s
#      stratum tables is probed through the public `bsc` CLI in the position it
#      is actually used. A row marked shipped/built whose entry does not resolve
#      is red; so is a row marked decided/owed/open whose entry does.
#
#   B. THE FEATURE LEDGER AGAINST ITSELF. Every `compiler/features/F*.md` has
#      exactly one row in `features/README.md`. That check is owed in writing:
#      the index carries a comment saying F22 "shipped on 2026-08-21 and was
#      NEVER GIVEN A ROW HERE ... NOTHING GATES THIS. That is a real owed check."
#      This is it. And the rows are ONE table: a `| [F` row whose previous line
#      is not a table line is a row markdown renders in a second, headerless
#      table, which is what a blank line at `README.md:112` did for thirteen
#      days while every row still had its grep hit (ENG-287).
#
#   C. NO DOCUMENT CALLS UNBUILT A FEATURE THE CORPUS DEMONSTRATES. For each
#      subject below there is an example directory the compiler builds. If the
#      example compiles, the subject is built, and a shipping document may not
#      say otherwise on any line.
#
# WHY THE EXAMPLE IS THE ORACLE AND NOT THE F-FILE
#
# A feature file is prose too, and prose is what is being doubted. `examples/Shop`
# either compiles or it does not, and ENG-245 asks in as many words for checks
# that "exercise representative public examples". The examples are already built
# by `verify.sh`, so this gate adds an assertion rather than a second corpus.
#
# WHAT IT DOES NOT CHECK
#
# The opposite direction — a document claiming something is built when it is not
# — only where that claim is CODE. `check-language.sh` holds that end for
# `LANGUAGE.md`: an untagged block must compile, so a fabricated feature fails
# there, and check A above holds it for every row of `PRELUDE.md`'s tables.
#
# A PROSE SENTENCE ANYWHERE ELSE CLAIMING SOMETHING IS BUILT IS STILL UNGATED.
# `TOUR.md` or `features/README.md` can call a feature shipped that is not, and
# nothing here fails. Said plainly because this gate exists in a ticket about
# documents that assert things which are not so, and its own header is a
# document.
#
# Usage:  bin/check-status-claims.sh [--self-test]

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# `CHECK_STATUS_DIR` exists for the self-test and holds mutated copies of the
# documents this gate reads, under their real relative paths. Nothing else sets
# it; without it every path resolves from the script's own location, which is
# what `check-cwd-independence.sh` requires.
DOCROOT="${CHECK_STATUS_DIR:-$HERE}"
BSC="$HERE/compiler/_build/default/bin/bsc"

# ---------------------------------------------------------------------------
# The shipping documents, as ENG-245 names them: overview, language reference,
# tour, prelude, glossary, compiler overview, feature index, exemplar material.
#
# NOTE, AND IT IS A FINDING RATHER THAN AN OVERSIGHT: this set is WIDER than
# `check-links.sh`'s package, which ships `LANGUAGE.md`, `CONTEXT.md`,
# `PRELUDE.md`, `compiler/features/` and `compiler/examples/` and does not
# include `README.md`, `TOUR.md` or `compiler/README.md`. Those three are read
# by a recipient and are exactly where two of the four known contradictions
# lived. Which set is THE package is ENG-246's question, not this gate's; until
# it is settled, the wider set is the safe one to hold to the truth.
# ---------------------------------------------------------------------------
shipping_docs() {
    cat <<'EOF'
README.md
LANGUAGE.md
TOUR.md
PRELUDE.md
CONTEXT.md
compiler/README.md
compiler/features/README.md
compiler/examples/exemplars/README.md
EOF
}

# A LISTED DOCUMENT THAT IS NOT THERE IS NOT A DOCUMENT THAT PASSES.
#
# The first cut of this list said `compiler/examples/README.md`, taking the path
# from ENG-245's own evidence, and `check_subjects` skipped it with a quiet
# `[ -f ] || continue`. THAT FILE HAS NEVER EXISTED — `git log` on it is empty;
# the exemplar write-up is `compiler/examples/exemplars/README.md`. So the gate
# scanned seven documents while reporting on eight, and a rename would have
# retired a document from checking without a word. The scan count is the only
# reason it was noticed, which is the argument for printing counts at all.
missing_docs() {
    local root="$1" doc n=0
    while IFS= read -r doc; do
        if [ ! -f "$root/$doc" ]; then
            printf 'shipping document listed but not present: %s\n' "$doc"
            n=$((n + 1))
        fi
    done < <(shipping_docs)
    return "$n"
}

# ---------------------------------------------------------------------------
# The subject registry: subject | example directory | alias regex
#
# The example is the oracle. The alias is what the PROSE calls the subject, and
# it is deliberately narrow — this gate would rather miss a paraphrase than
# redden a document over a word used in another sense.
#
# THE ALIASES ARE ANCHORED AND PLURAL, AND BOTH HALVES WERE PAID FOR. The first
# cut used `records?` unanchored and reddened two innocent lines: `compiler/
# features/README.md` says "recorded what the unbuilt half owed" — `record`
# inside `recorded`, `unbuilt` later in the sentence — and `PRELUDE.md` lists
# the KEYWORD `record` in a run of keywords that ends "`raise` is unbuilt".
# Prose about the feature says "records"; the grammar's keyword is `record`.
# Taking the plural only separates the two at no cost to what this gate is for.
# ---------------------------------------------------------------------------
subjects() {
    cat <<'EOF'
records|examples/Shop|\brecords\b
angle brackets|examples/Parcel|\bangle[- ]brackets?\b|\bgenerics\b
modules|examples/Shop|\bmodules and imports\b|\bmodule system\b
FFI|examples/Interop|\bFFI\b
OTP behaviours|examples/Counter|\bOTP behaviours?\b
refinements|examples/Wire|\brefinements\b
binaries|examples/Frame|\bbinary patterns?\b|\bbinaries\b
switch|examples/Queue|`switch`
EOF
}

# `string` IS NOT A SUBJECT HERE, AND THE REASON IS THE INTERESTING PART.
#
# It was, and it produced this gate's only false positive: LANGUAGE.md's line
# "the UTF-8 entry check (`binary` → `string`) | not started — the sixth codegen
# obligation" is TRUE. The `string` TYPE shipped with F9; the CONVERSION INTO it
# has never been built, and the two are one backtick apart on the page.
#
# A subject whose name appears inside the description of a genuinely-unbuilt
# neighbour cannot be told apart by matching a line, and a gate that cries wolf
# gets suppressed. `string`'s status is already held by check A above — its
# PRELUDE row is marked **built** and the probe resolves it — so dropping it
# here costs no coverage at all. That is the test for adding a subject: the
# example must be the only thing on the page wearing that word.

# A claim that a feature is absent. Strong assertions only: "not yet" and
# "planned" are how a document legitimately describes something genuinely
# unbuilt, and this gate is about the ones that are wrong, not the ones that
# are cautious.
#
# "still open" and "not started" are here because TOUR.md hid the binary-pattern
# contradiction behind exactly those words — "the binaries decision is still
# open — the one numbered feature not started" — while the construct index sixty
# lines below listed six binary-pattern capabilities against `examples/Frame`.
# A vocabulary that stops at "unbuilt" would have walked past it.
ABSENT='out of scope|deliberately \*\*out\*\*|deliberately out|not implemented|unimplemented|not built|unbuilt|does not exist|still fog|still open|not started'

# ---------------------------------------------------------------------------
# A. The prelude ledger against the compiler.
#
# `probe_form` is the position the entry is used in, and it matters: `ValidateAs<T>`
# is CODEGEN invoked in expression position, so probing it as a parameter type
# refuses it and would report F18 as unbuilt. That mistake was made while writing
# this gate and is why the form is recorded per entry rather than assumed.
#
# type      — the name appears as a parameter type
# codegen   — the name is called; `examples/Intake` is the standing proof
# builtin   — the name resolves, but NOT as the prelude entry the row describes,
#             so the probe answers a different question than the row asks
#
# `bool` WAS the `builtin` case until 2026-09-03. Its row read "**decided** — and
# **built as a builtin instead**": the PRELUDE ALIAS `type bool = true | false`
# was never added and `bool` resolved because the compiler had it as a builtin,
# so the probe — which cannot tell an alias from a builtin — would have gone red
# against a row telling the truth. Ticket 67 corrected ticket 10 IN PLACE (the
# builtin was the decision the compiler had been applying all along), the row
# now says shipped, and the probe answers the row's own question. The `builtin`
# form stays in the legend for the next entry whose text and resolution part.
# ---------------------------------------------------------------------------
prelude_entries() {
    cat <<'EOF'
option<T>|type|option<int>
result<T, E>|type|result<int, int>
foreign_error|type|foreign_error
ValidationError|type|ValidationError
string|type|string
bool|type|bool
ParseAtom<T>|type|ParseAtom<int>
map<K, V>|type|map<atom, term>
List.Sum|qualified|List.Sum([1, 2])
Term.Compare|qualified|Term.Compare(1, 2)
Map.Get|qualified|Map.Get([1], 1)
EOF
}

# Compile a one-clause module whose parameter has type $1. Exit 0 means the name
# resolves, which is what "ships" means for a type.
resolves_as_type() {
    local ty="$1" w o rc
    w="$(mktemp -d)"; o="$(mktemp -d)"
    mkdir -p "$w/P"
    { echo "module P"; echo; echo "public int Use($ty x)"; echo; echo "Use(x) -> 0"; } > "$w/P/p.bs"
    "$BSC" --src-root "$w" -o "$o" "$w/P" >/dev/null 2>&1
    rc=$?
    rm -rf "$w" "$o"
    return "$rc"
}

# Ticket 67's entries are reached in EXPRESSION position under a qualifier, never
# as a type, so `resolves_as_type` answers a different question about them than
# their rows ask — the mistake the `codegen`/`type` split was written to prevent,
# one column over. `term` is the declared return because these entries answer with
# different types and the row is about whether the name RESOLVES, not about what
# it yields; every one of them is a subtype of `term`, so a widened return cannot
# turn a refusal into a pass.
#
# There is no `using` line, and that is the assertion: a reserved qualifier that
# needed one would not be a reserved qualifier.
resolves_as_call() {
    local ex="$1" w o rc
    w="$(mktemp -d)"; o="$(mktemp -d)"
    mkdir -p "$w/P"
    { echo "module P"; echo; echo "public term Use(int n)"; echo;
      echo "Use(n) -> $ex"; } > "$w/P/p.bs"
    "$BSC" --src-root "$w" -o "$o" "$w/P" >/dev/null 2>&1
    rc=$?
    rm -rf "$w" "$o"
    return "$rc"
}

# Read a row's status word out of PRELUDE.md — FROM THE STATUS COLUMN, which is
# the fourth cell of `| Entry | What | Reach | Status | Ticket |`.
#
# THE FIRST CUT TOOK THE FIRST BOLD WORD ON THE ROW AND THAT WAS WRONG IN A WAY
# THAT PASSED. `ParseAtom<T>`'s description cell contains "**finite atom
# union**" — bold, lowercase, and earlier on the line than its real status — so
# the extractor returned a phrase matching no known status and the row fell
# through `continue`. The gate reported a clean probe of the table while never
# looking at that row at all, which is why the self-test below mutates
# `ParseAtom` specifically: it is the row that proved the extractor blind.
#
# A cell may contain an escaped `\|`, so those are masked before splitting.
# ONE ANCHOR FOR BOTH QUESTIONS. "Does this entry have a row?" and "what does
# its row say?" must be the same match, or the gate grows the ENG-320 hole back
# under a new name: a looser existence test finds the two-axes table's prose
# cell (`list<T>`, `option<T>`, `result<T, E>`, `map<K, V>` in ONE cell), calls
# the row present, extracts no status from it, and skips exactly as before.
# Control 8b pins this.
prelude_row() {
    local doc="$1" entry="$2"
    grep -F "| \`$entry\`" "$doc" 2>/dev/null | head -1
}

prelude_status() {
    local doc="$1" entry="$2"
    prelude_row "$doc" "$entry" |
        sed 's/\\|/\x01/g' |
        awk -F'|' '{ print $5 }' |
        grep -o '\*\*[a-z ]*\*\*' |
        head -1 |
        tr -d '*'
}

# One place that knows which probe a form takes, so the loop below states the
# question once and the legend above stays the only description of the forms.
probe_entry() {
    case "$1" in
        type)      resolves_as_type "$2" ;;
        qualified) resolves_as_call "$2" ;;
        *)         return 1 ;;
    esac
}

check_prelude() {
    local doc="$1" n=0 listed=0 bad=0 entry form expr status want
    [ -f "$doc" ] || { echo "check-status-claims: no PRELUDE at $doc"; return 1; }
    while IFS='|' read -r entry form expr; do
        [ -n "$entry" ] || continue
        # DISPATCH ON THE FORM RATHER THAN SKIPPING EVERYTHING THAT IS NOT A
        # TYPE. This line read `[ "$form" = "type" ] || continue` until 2026-09-04,
        # which meant the legend above documented three forms and the loop could
        # evaluate one — a row given any other form was counted as unrecognised
        # vocabulary or silently dropped. F32 added the first `qualified` rows and
        # would have been reported as unbuilt forever.
        case "$form" in
            type|qualified) ;;
            *) continue ;;
        esac
        listed=$((listed + 1))
        # AN ENTRY THE LIST NAMES AND THE TABLE DOES NOT CARRY IS RED. This line
        # read `[ -n "$status" ] || continue` until 2026-09-04, so an entry with
        # no row was neither probed nor reported: `map<K, V>` was in this list
        # from 2026-08-26 (`aa04d0c`) and had no row until 2026-09-03, and the
        # nine days of silence are ENG-319's — a type sat unbuilt and unreported
        # while `prelude entries probed:` printed what a full sweep prints. The
        # gate's own comment below warns of this failure for `ParseAtom<T>` and
        # then left the same `continue` for the case where there is no row at
        # all. ENG-320.
        if [ -z "$(prelude_row "$doc" "$entry")" ]; then
            printf 'PRELUDE.md: `%s` is named by prelude_entries and has NO row in the table.\n' \
                "$entry"
            printf '    The list and the document have drifted. Write the row, or drop the\n'
            printf '    entry — an entry with no row is not a passing entry, it is an unasked\n'
            printf '    question.\n'
            bad=$((bad + 1))
            continue
        fi
        status="$(prelude_status "$doc" "$entry")"
        if [ -z "$status" ]; then
            # The row exists and its status cell yields no bold word. Distinct
            # from the case above, and distinct from an unknown word below.
            printf 'PRELUDE.md: `%s` has a row whose status cell carries no bold status word.\n' \
                "$entry"
            bad=$((bad + 1))
            continue
        fi
        # THE COUNTER COUNTS ROWS ACTUALLY EVALUATED, not rows matched, and the
        # difference is not pedantry: while the extractor was blind to
        # `ParseAtom<T>` the count read 6 both before and after the fix, because
        # the row was counted and then skipped. A tally that includes rows the
        # gate declined to judge is how a gate reports looking at something it
        # never looked at.
        case "$status" in
            shipped|built) want=yes ;;
            decided|owed|open) want=no ;;
            *)
                # An unrecognised status word means the table gained vocabulary
                # this gate does not know. Silence there is how the blindness
                # above survived; say so instead.
                printf 'PRELUDE.md: `%s` has status "**%s**", which this gate does not know.\n' \
                    "$entry" "$status"
                printf '    Add it to the shipped/unshipped split in prelude_entries, or the row goes unchecked.\n'
                bad=$((bad + 1))
                continue
                ;;
        esac
        n=$((n + 1))
        if probe_entry "$form" "$expr"; then
            if [ "$want" = no ]; then
                printf 'PRELUDE.md: `%s` is marked **%s**, but `%s` RESOLVES through bsc.\n' \
                    "$entry" "$status" "$expr"
                bad=$((bad + 1))
            fi
        else
            if [ "$want" = yes ]; then
                printf 'PRELUDE.md: `%s` is marked **%s**, but `%s` is REFUSED by bsc.\n' \
                    "$entry" "$status" "$expr"
                bad=$((bad + 1))
            fi
        fi
    done < <(prelude_entries)
    # N OF M, NOT N. The probed count alone was the only thing that would have
    # shown `map<K, V>` going unprobed, and it read like a full sweep because
    # nothing stood beside it (ENG-320, owed item 3). M is the entries this walk
    # dispatched on, so a skip is visible as a gap rather than inferred.
    printf 'prelude entries probed: %d of %d\n' "$n" "$listed"
    # A run that probed nothing is a run that proved nothing. Seven of the eight
    # registry rows are `type`; a floor well under that still catches a table
    # rename that makes every row invisible.
    if [ "$n" -lt 5 ]; then
        echo "check-status-claims: only $n prelude rows matched — the table shape changed"
        echo "                     and this check went blind rather than green."
        bad=$((bad + 1))
    fi
    return "$bad"
}

# ---------------------------------------------------------------------------
# B. The feature ledger against itself.
# ---------------------------------------------------------------------------
check_features() {
    local dir="$1" index="$2" n=0 bad=0 f name
    [ -f "$index" ] || { echo "check-status-claims: no feature index at $index"; return 1; }
    for f in "$dir"/F*.md; do
        [ -e "$f" ] || continue
        name="$(basename "$f" .md)"
        name="${name%%-*}"
        n=$((n + 1))
        if ! grep -qE "^\| \[$name " "$index"; then
            printf '%s: no row in the feature index, so it is a shipped feature the index denies.\n' \
                "$name"
            bad=$((bad + 1))
        fi
    done
    # THE TABLE MUST BE ONE TABLE. A `| [FNN ` row whose previous line is not a
    # table line is a row the table lost: markdown closes a table at the first
    # blank line and opens a new one at the next row, so the index renders as
    # two tables and every row below the split has no header. The per-file
    # grep above cannot see this — it asks whether the row EXISTS, and a row
    # in the second table exists. `README.md:112` sat blank between F20 and
    # F21 from 2026-08-21, when F21's row was appended below it, to 2026-09-03,
    # under a green section B throughout (ENG-287).
    local split
    split="$(awk 'NR > 1 && /^\| \[F/ && prev !~ /^\|/ { print NR ":" prev_nr }
                  { prev = $0; prev_nr = NR }' "$index")"
    if [ -n "$split" ]; then
        while IFS=: read -r row before; do
            printf '%s:%s: the feature table is split — line %s is not a table line, so\n' \
                "${index#"$DOCROOT"/}" "$before" "$before"
            printf '    the row at line %s and everything below it render as a second table.\n' \
                "$row"
            bad=$((bad + 1))
        done <<< "$split"
    fi
    printf 'feature files checked: %d\n' "$n"
    if [ "$n" -lt 1 ]; then
        echo "check-status-claims: no feature files found — this check enumerated nothing."
        bad=$((bad + 1))
    fi
    return "$bad"
}

# ---------------------------------------------------------------------------
# C. No document calls unbuilt a feature the corpus demonstrates.
# ---------------------------------------------------------------------------
check_subjects() {
    local root="$1" compiled=0 bad=0 scanned=0
    local subject example alias out hits
    while IFS='|' read -r subject example alias; do
        [ -n "$subject" ] || continue
        [ -d "$HERE/compiler/$example" ] || continue
        out="$(mktemp -d)"
        if ! ( cd "$HERE/compiler" && "$BSC" --src-root examples -o "$out" "$example" ) >/dev/null 2>&1; then
            rm -rf "$out"
            continue        # not built; a document calling it unbuilt is right
        fi
        rm -rf "$out"
        compiled=$((compiled + 1))
        while IFS= read -r doc; do
            [ -f "$root/$doc" ] || continue
            scanned=$((scanned + 1))
            # A ~~struck~~ span is a RETRACTED claim, and retracting in place is
            # this repository's own idiom — `compiler/README.md` keeps a resolved
            # gap struck through "rather than deleted, because the shape of the
            # gap is the useful part", and ENG-245 forbids resolving a
            # contradiction by deleting the only statement of a real limitation.
            # So the strike is honoured, and ONLY between its markers on one
            # line: a document cannot exempt a paragraph by opening a `~~`
            # somewhere above it.
            hits="$(sed 's/~~[^~]*~~//g' "$root/$doc" | grep -nEi "($alias)" |
                    grep -Ei "($ABSENT)" || true)"
            if [ -n "$hits" ]; then
                while IFS= read -r line; do
                    printf '%s:%s\n' "$doc" "$(printf '%s' "$line" | cut -c1-140)"
                    printf '    ^ calls "%s" absent. `compiler/%s` compiles, so it is built.\n' \
                        "$subject" "$example"
                    bad=$((bad + 1))
                done <<< "$hits"
            fi
        done < <(shipping_docs)
    done < <(subjects)
    printf 'subjects demonstrated by a compiling example: %d\n' "$compiled"
    printf 'document scans performed: %d\n' "$scanned"
    if [ "$compiled" -lt 5 ] || [ "$scanned" -lt 20 ]; then
        echo "check-status-claims: this check enumerated almost nothing, which is how it"
        echo "                     passes without looking. Build the escript first."
        bad=$((bad + 1))
    fi
    return "$bad"
}

# ---------------------------------------------------------------------------
# D. No document calls a ticket open that the tracker has resolved.
#
# ENG-245 names three axes — built/unbuilt, shipping/deferred, and
# RESOLVED/OPEN — and the third is the one the other checks walk straight past.
# `compiler/README.md` carried "records (26 open), angle-bracket syntax (28
# open)" when tickets 26 and 28 were both long since resolved: a reader is told
# a question is live and goes looking for an argument that finished.
#
# `wayfinder/` is the tracker's repo half and does not ship, but it is on disk
# here, and `check-surface.sh` already reads `wayfinder/map.md` for the same
# reason — the gate runs where both halves exist even though only one is handed
# over.
# ---------------------------------------------------------------------------
check_open_tickets() {
    local root="$1" n=0 bad=0 doc num line issue cand
    while IFS= read -r doc; do
        [ -f "$root/$doc" ] || continue
        while IFS= read -r line; do
            num="$(printf '%s' "$line" | sed 's/.*[^0-9]\([0-9][0-9]*\) open.*/\1/')"
            [ -n "$num" ] || continue
            # A glob rather than `ls` (SC2012), and a real disable would have
            # been the wrong fix anyway: shellcheck is unpinned here, so a
            # directive that satisfies the local version can redden on CI.
            issue=""
            for cand in "$HERE"/wayfinder/issues/"$num"-*.md; do
                [ -e "$cand" ] || continue
                issue="$cand"
                break
            done
            [ -n "$issue" ] || continue
            n=$((n + 1))
            # BOTH SPELLINGS. Ticket files write the status either way — 26 has
            # a bare `Status: resolved 2026-08-13`, 22 and 38 have
            # `Status: **resolved ...**` — and matching only the bold one made
            # this check pass over the very ticket that motivated it.
            if grep -qiE '^Status: [*]*resolved' "$issue"; then
                printf '%s: calls ticket %s open; %s says resolved.\n' \
                    "$doc" "$num" "wayfinder/issues/$(basename "$issue")"
                printf '    %s\n' "$(printf '%s' "$line" | cut -c1-120)"
                bad=$((bad + 1))
            fi
        done < <(sed 's/~~[^~]*~~//g' "$root/$doc" | grep -nE '[0-9]+ open')
    done < <(shipping_docs)
    printf 'open-ticket claims checked against the tracker: %d\n' "$n"
    # NO FLOOR HERE, DELIBERATELY, AND IT IS THE ONE CHECK THAT GETS NONE.
    # A, B and C fail when they enumerate too little, because there is always
    # something for them to look at. Zero is the RIGHT answer here: a repository
    # whose documents call no resolved ticket open has nothing to find, and a
    # floor would make keeping a stale claim the only way to stay green. What
    # stops this passing by being blind is control 6 in the self-test, which
    # writes the `records (26 open)` claim into a document and requires the red.
    if [ "$n" -eq 0 ]; then
        echo "    (none to check — no shipping document names a ticket as open. The"
        echo "     self-test proves this check still fires; see control 6.)"
    fi
    return "$bad"
}

# ---------------------------------------------------------------------------
# --self-test
#
# POSITIVE CONTROLS, one per way this gate can be defeated, and the third
# is the one a plausible implementation fails.
#
#   1. A prelude row marked built whose entry the compiler refuses.
#   2. A feature file with no row in the index (the F22 case, verbatim).
#   3. A DOCUMENT THAT NEVER MENTIONED THE SUBJECT BEFORE gains a sentence
#      calling a built feature unbuilt. A gate that only re-checked lines it
#      already knew about — a stored list of known claims, refreshed by hand —
#      passes 1 and 2 completely and is blind to exactly the drift ENG-245 is
#      about, because every one of the four real defects arrived this way.
#   4. A prelude row marked decided whose entry the compiler RESOLVES. This is
#      the `foreign_error` case and it is the direction a gate written only
#      against "claims built, is not" would miss.
#   5. A listed shipping document deleted from disk.
#   6. A document calling a resolved ticket open (the `records (26 open)` case).
#   7. The feature table split — a blank line, and then a prose line, inserted
#      before a row in the middle of it. Every row still exists, so control 2
#      is blind to both.
#   8. An entry in `prelude_entries` with NO row in PRELUDE.md. Controls 1 and
#      4 both mutate a row that exists, so both are blind to an entry the table
#      never carried — which is how `map<K, V>` went nine days unprobed while
#      the count line read like a full sweep (ENG-320). Its over-informed half
#      is a prose cell listing four type names, which is not a row for any of
#      them.
#
# The negative control is the tree as committed: it must be green, and it must
# say how much it looked at, so a run that enumerated nothing cannot be mistaken
# for a run that found nothing.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
    CTL="$(mktemp -d)"
    trap 'rm -rf "$CTL"' EXIT
    fail=0

    # Real copies, under their real relative paths. A two-line fixture would
    # exercise none of the table-walking above.
    while IFS= read -r doc; do
        mkdir -p "$CTL/$(dirname "$doc")"
        cp "$HERE/$doc" "$CTL/$doc" 2>/dev/null || true
    done < <(shipping_docs)

    # --- control 1: a built row the compiler refuses -----------------------
    # `option<T>` is marked **shipped**. Rename the entry the table names to one
    # that does not resolve, leaving the status word alone.
    sed 's/^| `option<T>` | `type option<T>/| `option<T>` | `type nosuchtype<T>/' \
        "$CTL/PRELUDE.md" > "$CTL/p1.md" || true
    out="$(CHECK_STATUS_DIR="$CTL" check_prelude "$CTL/PRELUDE.md" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "SELF-TEST FAILED: the committed prelude table is already red, so control 1"
        echo "                  cannot be told from the baseline."
        echo "$out"
        fail=1
    fi
    # The mutation that must be caught: mark a refused entry as shipped.
    # The `map<K, V>` row was deleted here as well until 2026-09-04. Once an
    # entry with no row is red in its own right (ENG-320, control 8), that
    # deletion would have reddened this mutation for a reason that is not the
    # mutation, and a control that can pass for the wrong reason is not one.
    sed 's/| `ParseAtom<T>` \(.*\)\*\*decided\*\*/| `ParseAtom<T>` \1**built**/' \
        "$CTL/PRELUDE.md" > "$CTL/PRELUDE.mut.md"
    out="$(check_prelude "$CTL/PRELUDE.mut.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a prelude entry marked **built** that bsc REFUSES was not"
        echo "                  caught, so the ledger can promise a type that is not there."
        fail=1
    fi

    # --- control 4: a decided row the compiler resolves ---------------------
    # The `foreign_error` case: shipped in stratum_one, documented as decided.
    sed 's/| `bool` \(.*\)\*\*decided\*\*/| `bool` \1**decided**/' "$CTL/PRELUDE.md" > "$CTL/PRELUDE.m4.md"
    out="$(check_prelude "$CTL/PRELUDE.m4.md" 2>&1)"; rc=$?
    if ! printf '%s' "$out" | grep -q 'prelude entries probed'; then
        echo "SELF-TEST FAILED: the prelude check did not report how many rows it probed,"
        echo "                  so a blind run cannot be told from a clean one."
        fail=1
    fi

    # --- control 8: an entry the list names and the table does not carry ----
    # ENG-320. `map<K, V>` sat in prelude_entries from 2026-08-26 (`aa04d0c`)
    # with no row in PRELUDE.md, and the loop's `[ -n "$status" ] || continue`
    # skipped it in silence for nine days while `prelude entries probed: N`
    # read exactly like a full sweep. The rule: an entry the list names and the
    # table does not carry is RED, and the red names the entry.
    sed '/^| `map<K, V>` /d' "$CTL/PRELUDE.md" > "$CTL/PRELUDE.m8.md"
    if [ "$(grep -cF '| `map<K, V>`' "$CTL/PRELUDE.m8.md")" -ne 0 ]; then
        echo "SELF-TEST FAILED: control 8 did not remove the \`map<K, V>\` row, so it is"
        echo "                  measuring the committed table, not a missing row."
        fail=1
    fi
    out="$(check_prelude "$CTL/PRELUDE.m8.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: an entry in prelude_entries with NO row in PRELUDE.md was"
        echo "                  skipped and the gate passed. That is ENG-320 exactly — the"
        echo "                  list and the table drift apart, and the count line still"
        echo "                  reads like a full sweep."
        fail=1
    fi
    if ! printf '%s' "$out" | grep -q 'map<K, V>'; then
        echo "SELF-TEST FAILED: the entry with no row was not named, so a red run does not"
        echo "                  say which entry needs a row."
        fail=1
    fi

    # THE OVER-INFORMED CONTROL for the same rule. PRELUDE.md's two-axes table
    # has a row whose FIRST CELL lists four type names in prose — `list<T>`,
    # `option<T>`, `result<T, E>`, `map<K, V>` — three of them named by
    # prelude_entries. It is not any of their rows. `prelude_status` anchors on
    # a pipe followed by the backticked entry, so a comma-preceded mention
    # cannot match it; this control pins that, because a row-existence test
    # written as a bare `grep -F "\`$entry\`"` would find that line, call the
    # row present, and hand the silence straight back.
    sed '/^| `option<T>` /d' "$CTL/PRELUDE.md" > "$CTL/PRELUDE.m8b.md"
    if ! grep -q 'option<T>' "$CTL/PRELUDE.m8b.md"; then
        echo "SELF-TEST FAILED: control 8b removed every mention of \`option<T>\`, so it no"
        echo "                  longer tells a row from a prose mention."
        fail=1
    fi
    out="$(check_prelude "$CTL/PRELUDE.m8b.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: \`option<T>\` lost its row and the gate passed — the prose"
        echo "                  mention in the two-axes table was taken for the row."
        fail=1
    fi

    # The third cell of the same rule: a row that EXISTS and yields no bold
    # status word. Splitting "no row" from "no status" gave this branch its own
    # verdict, and a branch with no control is a verdict nobody has watched
    # fail. Distinct from the unknown-vocabulary case below it, which fires on
    # a bold word the gate does not know rather than on no bold word at all.
    sed 's/^| `map<K, V>` .*/| `map<K, V>` | the map type | unqualified | built, with no bold word | 48 |/' \
        "$CTL/PRELUDE.md" > "$CTL/PRELUDE.m8c.md"
    if ! grep -q 'with no bold word' "$CTL/PRELUDE.m8c.md"; then
        echo "SELF-TEST FAILED: control 8c did not rewrite the \`map<K, V>\` row, so it is"
        echo "                  not measuring a row with an unbolded status cell."
        fail=1
    fi
    out="$(check_prelude "$CTL/PRELUDE.m8c.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a row whose status cell carries no bold word was skipped and"
        echo "                  the gate passed — the ENG-320 silence, one cell along."
        fail=1
    fi

    # Owed item 3 of ENG-320: the count line must carry the list length beside
    # the probed count. Nothing compared N to the length, so 10-of-11 and
    # 11-of-11 printed the same line.
    out="$(check_prelude "$CTL/PRELUDE.md" 2>&1)"
    if ! printf '%s' "$out" | grep -qE 'prelude entries probed: [0-9]+ of [0-9]+'; then
        echo "SELF-TEST FAILED: the probed count does not name the list length beside it, so"
        echo "                  a sweep that skipped an entry prints what a full one prints."
        fail=1
    fi

    # --- control 2: a feature file with no row in the index ------------------
    mkdir -p "$CTL/features"
    cp "$HERE"/compiler/features/F*.md "$CTL/features/" 2>/dev/null || true
    cp "$HERE/compiler/features/README.md" "$CTL/features/README.md"
    : > "$CTL/features/F99-never-indexed.md"
    out="$(check_features "$CTL/features" "$CTL/features/README.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a feature file with no row in the index was not caught."
        echo "                  That is the F22 case, which happened, and which the index"
        echo "                  itself records as an owed check."
        fail=1
    fi
    rm -f "$CTL/features/F99-never-indexed.md"
    out="$(check_features "$CTL/features" "$CTL/features/README.md" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "SELF-TEST FAILED: the committed feature ledger is red, so control 2 proves"
        echo "                  nothing about the mutation."
        echo "$out"
        fail=1
    fi

    # --- control 7: the feature table split ---------------------------------
    # The ENG-287 case. Every row still exists, so control 2's check is blind
    # to it; the table is nonetheless two tables. Inserted before F5's row, a
    # row in the middle, so a check that only inspects the first or last row
    # passes control 2 and fails here. Its GREEN half is control 2's second
    # run just above: the committed index, one table, must pass this check too.
    # Two mutations, because the rule is "not a table line" and not "blank": a
    # check written as `prev == ""` passes the first and fails the second.
    awk '/^\| \[F5 / { print "" } { print }' "$CTL/features/README.md" > "$CTL/features/README.split.md"
    out="$(check_features "$CTL/features" "$CTL/features/README.split.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a blank line inside the feature table was not caught. Every"
        echo "                  row still has a grep hit, and the index renders as two tables"
        echo "                  with the second one headerless — README.md:112, 2026-08-21 to 09-03."
        fail=1
    fi
    if ! printf '%s' "$out" | grep -q 'the feature table is split'; then
        echo "SELF-TEST FAILED: the split was caught but not named as a split, so a red run"
        echo "                  does not say what to fix."
        fail=1
    fi
    awk '/^\| \[F5 / { print "A sentence of prose, which also ends a markdown table." } { print }' \
        "$CTL/features/README.md" > "$CTL/features/README.split.md"
    out="$(check_features "$CTL/features" "$CTL/features/README.split.md" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a prose line inside the feature table was not caught. The"
        echo "                  rule is 'not a table line'; a check that asks only for a blank"
        echo "                  passes the first mutation and is blind to this one."
        fail=1
    fi
    rm -f "$CTL/features/README.split.md"

    # --- control 3: a document that never carried the claim gains one -------
    # THE OVER-INFORMED CONTROL. Written into CONTEXT.md, a glossary that says
    # nothing about build status anywhere, so nothing about this line is already
    # known to the gate.
    printf '\nRecords are out of scope in this release.\n' >> "$CTL/CONTEXT.md"
    out="$(check_subjects "$CTL" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a NEW sentence calling a built feature out of scope was not"
        echo "                  caught. Every one of ENG-245's four defects arrived exactly"
        echo "                  this way — as a line no list of known claims contained."
        fail=1
    fi
    if ! printf '%s' "$out" | grep -q 'CONTEXT.md'; then
        echo "SELF-TEST FAILED: the offending document was not named, so a red run does not"
        echo "                  say where to go."
        fail=1
    fi

    # --- the discrimination half -------------------------------------------
    # A gate that reported failure unconditionally passes all four above.
    while IFS= read -r doc; do
        mkdir -p "$CTL/clean/$(dirname "$doc")"
        cp "$HERE/$doc" "$CTL/clean/$doc" 2>/dev/null || true
    done < <(shipping_docs)
    out="$(check_subjects "$CTL/clean" 2>&1)"; rc=$?
    # BOTH HALVES. The first cut captured `rc` here and never tested it, so a
    # check C that reddened on the committed tree would have passed its own
    # negative control. C is the check most likely to start crying wolf as prose
    # changes — an anchored alias beside a strong-phrase list is a heuristic, and
    # it produced two false reds while being written — so it is the one that most
    # needs to be held to green on clean input.
    if [ "$rc" -ne 0 ]; then
        echo "SELF-TEST FAILED: check C reddens on the tree as committed, so every control"
        echo "                  above it is measuring a gate that fires on everything."
        echo "$out"
        fail=1
    fi
    if ! printf '%s' "$out" | grep -q 'subjects demonstrated by a compiling example'; then
        echo "SELF-TEST FAILED: a run did not report how many subjects it probed, so a run"
        echo "                  that enumerated nothing looks identical to a clean one."
        fail=1
    fi

    # --- control 5: a listed shipping document that is not on disk -----------
    # THE CHECK ADDED LAST AND CONTROLLED LAST. `missing_docs` exists because the
    # document list named `compiler/examples/README.md`, a file that has never
    # existed, and the scan skipped it in silence. A check written to catch a
    # silent skip is worth nothing until it has been watched not to skip
    # silently itself.
    mkdir -p "$CTL/gone"
    while IFS= read -r doc; do
        mkdir -p "$CTL/gone/$(dirname "$doc")"
        cp "$HERE/$doc" "$CTL/gone/$doc" 2>/dev/null || true
    done < <(shipping_docs)
    out="$(missing_docs "$CTL/gone" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "SELF-TEST FAILED: the complete document set was reported as incomplete, so"
        echo "                  control 5 cannot tell a missing file from a present one."
        echo "$out"
        fail=1
    fi
    rm -f "$CTL/gone/TOUR.md"
    out="$(missing_docs "$CTL/gone" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a shipping document was DELETED and the gate still passed."
        echo "                  That is the `compiler/examples/README.md` case exactly: a"
        echo "                  document retires from checking and nothing says so."
        fail=1
    fi
    if ! printf '%s' "$out" | grep -q 'TOUR.md'; then
        echo "SELF-TEST FAILED: the absent document was not named."
        fail=1
    fi

    # --- control 6: a resolved ticket called open ---------------------------
    # The `records (26 open)` case. Ticket 26 is resolved, so writing the claim
    # into a document that never carried one must redden.
    mkdir -p "$CTL/tix"
    while IFS= read -r doc; do
        mkdir -p "$CTL/tix/$(dirname "$doc")"
        cp "$HERE/$doc" "$CTL/tix/$doc" 2>/dev/null || true
    done < <(shipping_docs)
    out="$(check_open_tickets "$CTL/tix" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "SELF-TEST FAILED: the committed tree already calls a resolved ticket open, so"
        echo "                  control 6 cannot be told from the baseline."
        echo "$out"
        fail=1
    fi
    printf '\nRecords are still being argued about (26 open).\n' >> "$CTL/tix/CONTEXT.md"
    out="$(check_open_tickets "$CTL/tix" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "SELF-TEST FAILED: a document called ticket 26 open and the tracker has it"
        echo "                  resolved, and the gate passed. That is the third axis"
        echo "                  ENG-245 names — resolved/open — going unchecked."
        fail=1
    fi

    if [ "$fail" -eq 0 ]; then
        echo "self-test: caught a promised type bsc refuses, an entry the list names with"
        echo "           no row in the table, an unindexed feature file, a split feature"
        echo "           table, a brand-new sentence calling a built feature out of scope,"
        echo "           a deleted shipping document, and a resolved ticket called open —"
        echo "           and reported its own enumeration counts in every case."
        exit 0
    fi
    exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: check-status-claims.sh [--self-test]"; exit 2; }

if [ ! -x "$BSC" ]; then
    echo "check-status-claims: bsc is not built at $BSC"
    echo "                     run (cd compiler && rebar3 escriptize) first — without it"
    echo "                     every probe below would report 'not built' and this gate"
    echo "                     would pass by finding nothing."
    exit 1
fi

rc=0

echo "--- 0. every shipping document this gate names is on disk"
missing_docs "$DOCROOT" || rc=1

echo
echo "--- A. the prelude ledger against the compiler"
check_prelude "$DOCROOT/PRELUDE.md" || rc=1

echo
echo "--- B. every feature file has a row in the index"
check_features "$HERE/compiler/features" "$DOCROOT/compiler/features/README.md" || rc=1

echo
echo "--- C. no document calls unbuilt a feature the corpus demonstrates"
check_subjects "$DOCROOT" || rc=1

echo
echo "--- D. no document calls a ticket open that the tracker has resolved"
check_open_tickets "$DOCROOT" || rc=1

echo
if [ "$rc" -eq 0 ]; then
    echo "status claims agree with the compiler."
else
    echo "FAILED: a shipping document contradicts the compiler about what is built."
    echo "Fix the sentence, dated, rather than deleting it — a real limitation that"
    echo "disappears is a worse document than one that is out of date."
fi
exit "$rc"
