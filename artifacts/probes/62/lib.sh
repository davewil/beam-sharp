#!/usr/bin/env bash
# Shared by the ticket-62 probes. Builds a SCRATCH copy of compiler/ patched to run under OTP 25
# (the repo pins OTP 28.5; plain `rebar3 escriptize` fails here). The repo is never modified.
# Optional: BS_PATCH_ALIAS=1 additionally applies the snake_case-alias emitter patch (probe 05).
PROBES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$PROBES/../../.." && pwd)"
SCRATCH="${SCRATCH:-/tmp/claude-0/ws62-run}"
build_bsc() {   # $1 = name of the build dir under $SCRATCH; echoes path of bsc
  local d="$SCRATCH/$1"
  if [ ! -x "$d/_build/default/bin/bsc" ]; then
    rm -rf "$d"; mkdir -p "$d"; cp -r "$REPO/compiler/." "$d/"; rm -rf "$d/_build"
    ( cd "$d"
      # PATCH 1 (OTP 25 leex has no error_location option and no TokenLoc): drop xrl_opts, drop warnings_as_errors,
      # make every token location {Line,1} (columns are lost; emission is unaffected) and stub adjust_col/3.
      sed -i 's/^{xrl_opts.*$/{xrl_opts, []}./; s/, warnings_as_errors//' rebar.config
      sed -i 's/TokenLoc/{TokenLine,1}/g' src/bs_lexer.xrl
      printf '\nadjust_col(_Chars, _Len, C) -> C.\n' >> src/bs_lexer.xrl
      if [ -n "${BS_PATCH_ALIAS:-}" ]; then bash "$PROBES/05-alias-cost/apply-alias-patch.sh" "$d"; fi
      rebar3 escriptize >"$d/build.log" 2>&1 ) || { echo "bsc build failed; see $d/build.log" >&2; return 1; }
  fi
  echo "$d/_build/default/bin/bsc"
}
# bsc writes dependency modules' .beam/.abstr next to --src-root regardless of -o, so never point it at the repo:
# examples are copied to $SCRATCH/examples once and compiled from there.
EX="$SCRATCH/examples"
[ -d "$EX" ] || { mkdir -p "$SCRATCH"; cp -r "$REPO/compiler/examples" "$EX"; }
# compile the Shop example (and Reports) with the given bsc into $2
compile_shop() { local bsc="$1" out="$2"; mkdir -p "$out"
  "$bsc" --src-root "$EX" -o "$out" "$EX/Shop" >/dev/null 2>&1
  "$bsc" --src-root "$EX" -o "$out" "$EX/Shop/Reports" >/dev/null 2>&1; }
