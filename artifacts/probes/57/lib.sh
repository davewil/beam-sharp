# lib.sh -- shared helpers for the ticket-57 probes. Sourced, never run.
# Every probe prints "MATCH" when the observed value equals the stated
# expectation and "REFUTED" when it does not; REFUTED is a finding, not a
# failure of the script. Nothing here edits the repo: variants are built from a
# COPY of compiler/ under $WORK.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
SCR=/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad
ENVSH=${ENVSH:-$SCR/env.sh}
# shellcheck disable=SC1090
. "$ENVSH"
OUT=$HERE/out
WORK=${WORK57:-$SCR/w57run}
REPO_BSC=$REPO/compiler/_build/default/bin/bsc
mkdir -p "$OUT" "$WORK"

# variant NAME -> its bsc. `repo` is the escript already built in the repo.
bsc_of () { if [ "$1" = repo ]; then echo "$REPO_BSC"; else echo "$WORK/$1/compiler/_build/default/bin/bsc"; fi; }
ebin_of () { if [ "$1" = repo ]; then echo "$REPO/compiler/_build/default/lib/bsc/ebin"; else echo "$WORK/$1/compiler/_build/default/lib/bsc/ebin"; fi; }

# build_variant NAME [PATCH]: copy compiler/ (no _build, no generated parser or
# lexer, no stray beams), apply the patch if any, escriptize.
build_variant () {
    local name=$1 patch=${2:-} d=$WORK/$1
    rm -rf "$d"; mkdir -p "$d"
    (cd "$REPO" && tar cf - --exclude=_build --exclude='*.beam' \
        --exclude=compiler/src/bs_parser.erl --exclude=compiler/src/bs_lexer.erl compiler aoc) | tar xf - -C "$d"
    if [ -n "$patch" ]; then (cd "$d" && patch -p1 -s < "$patch") || { echo "PATCH FAILED $name"; return 1; }; fi
    (cd "$d/compiler" && rebar3 escriptize) > "$OUT/build-$name.log" 2>&1 || { echo "BUILD FAILED $name"; return 1; }
}

# probe VARIANT NAME SRC -> writes out/cases/VARIANT/NAME.{bs,out}, sets
# $verdict (accepted|refused) from the EXIT STATUS and $output.
probe () {
    local v=$1 name=$2 src=$3 d
    d=$OUT/cases/$v; mkdir -p "$d/m/$name"
    printf 'module %s\n%s\n' "$name" "$src" > "$d/m/$name/a.bs"
    output=$("$(bsc_of "$v")" -o "$d/m/$name" "$d/m/$name/a.bs" 2>&1); rc=$?
    printf '%s\n[exit %s]\n' "$output" "$rc" > "$d/$name.out"
    if [ $rc -eq 0 ]; then verdict=accepted; else verdict=refused; fi
}

# expect LABEL EXPECTED OBSERVED
expect () {
    if [ "$2" = "$3" ]; then printf 'MATCH    %-44s %s\n' "$1" "$3"
    else printf 'REFUTED  %-44s claim=%s observed=%s\n' "$1" "$2" "$3"; fi
}
