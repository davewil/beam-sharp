# Shared helpers. Sourced by every probe; never run directly.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
SCRATCH_DEFAULT=/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad
W60_ENV="${W60_ENV:-$SCRATCH_DEFAULT/env.sh}"
# shellcheck disable=SC1090
[ -f "$W60_ENV" ] && . "$W60_ENV"
WORK="${W60_WORK:-$SCRATCH_DEFAULT/w60run}"
mkdir -p "$WORK"

# build_variant NAME [PATCH]: fresh copy of the repo's compiler/{src,rebar.*},
# generated lexer/parser removed so they are regenerated from the (patched)
# .xrl/.yrl, patch applied, escript built. Always from scratch.
build_variant() {
    local name="$1" patch="${2:-}" d="$WORK/$1"
    [ -n "$WORK" ] && [ -n "$name" ] || return 2
    rm -rf "${d:?}"
    mkdir -p "$d"
    cp -r "$REPO/compiler/src" "$REPO/compiler/rebar.config" "$d/"
    [ -f "$REPO/compiler/rebar.lock" ] && cp "$REPO/compiler/rebar.lock" "$d/"
    rm -f "$d/src/bs_lexer.erl" "$d/src/bs_parser.erl"
    if [ -n "$patch" ]; then
        (cd "$d" && patch -p1 --quiet < "$HERE/patches/$patch") || { echo "PATCH FAILED $patch"; return 1; }
    fi
    (cd "$d" && rebar3 escriptize > build.log 2>&1) || { echo "BUILD FAILED $name"; tail -20 "$d/build.log"; return 1; }
    echo "built $name -> $d/_build/default/bin/bsc"
}
bsc_of() { echo "$WORK/$1/_build/default/bin/bsc"; }
# verdict CLAIM STATUS  (STATUS is the shell exit of a test the caller ran)
verdict() { if [ "$2" -eq 0 ]; then echo "VERDICT[$1]: CONFIRMED"; else echo "VERDICT[$1]: REFUTED"; fi; }
