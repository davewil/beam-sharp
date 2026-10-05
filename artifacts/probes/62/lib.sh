# shared setup: sources env, defines paths. BSC = repo's built compiler (unmodified).
# BSC_ALIAS = the EXPERIMENTAL compiler copy built from compiler-alias.patch (scratch, never the repo's).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. /tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/env.sh
REPO=/home/user/beam-sharp
BSC="${BSC:-$REPO/compiler/_build/default/bin/bsc}"
SCRATCH=/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/w62
BSC_ALIAS="$SCRATCH/compiler-alias/_build/default/bin/bsc"
mkdir -p "$SCRATCH"
# build the experimental compiler from scratch: copy repo compiler sources, apply patch, escriptize
build_alias_compiler() {
  [ -x "$BSC_ALIAS" ] && return 0
  rm -rf "$SCRATCH/compiler-alias"; mkdir -p "$SCRATCH/compiler-alias"
  cp -r "$REPO/compiler/src" "$REPO/compiler/rebar.config" "$REPO/compiler/rebar.lock" "$SCRATCH/compiler-alias/" 2>/dev/null
  (cd "$SCRATCH/compiler-alias" && patch -p1 < "$HERE/compiler-alias.patch" >/dev/null && rebar3 escriptize >/dev/null 2>&1)
  [ -x "$BSC_ALIAS" ]
}
