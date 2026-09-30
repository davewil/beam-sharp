#!/usr/bin/env bash
# Source me. Builds (once) the reference compiler from compiler/src with erlc,
# because rebar3 is not installed and the pinned OTP 28.5 is not either (this
# box has OTP 25). See brief.md "Toolchain caveats" for what that changes.
set -u
REPO=/home/user/beam-sharp
PROBES=$REPO/artifacts/59/probes
BUILD=${BS_BUILD:-/tmp/bs59-build}
build_compiler() {          # build_compiler <ebin-dir> [bs_emit.erl override]
  local ebin=$1 emit=${2:-$REPO/compiler/src/bs_emit.erl}
  mkdir -p "$ebin" "$BUILD/gen"
  if [ ! -f "$BUILD/gen/bs_parser.erl" ]; then
    cp "$REPO"/compiler/src/bs_lexer.xrl "$REPO"/compiler/src/bs_parser.yrl "$BUILD/gen/"
    # OTP 25's leex has no TokenLoc (OTP 26+): give every token {Line,1}.
    sed -i 's/TokenLoc/{TokenLine,1}/g' "$BUILD/gen/bs_lexer.xrl"
    printf '\nadjust_col(_Chars, _Len, C) -> C.\n' >> "$BUILD/gen/bs_lexer.xrl"
    (cd "$BUILD/gen" && erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), yecc:file("bs_parser.yrl"), halt().' >/dev/null 2>&1)
  fi
  for f in "$REPO"/compiler/src/*.erl; do
    b=$(basename "$f"); [ "$b" = bs_emit.erl ] && continue
    erlc -o "$ebin" "$f" 2>/dev/null
  done
  erlc -o "$ebin" "$emit" 2>/dev/null
  erlc -o "$ebin" "$BUILD"/gen/bs_lexer.erl "$BUILD"/gen/bs_parser.erl 2>/dev/null
  cp "$REPO"/compiler/src/bsc.app.src "$ebin/bsc.app"
}
# bsc_in <ebin> <cwd> args...   run the CLI with cwd as given
bsc_in() { local ebin=$1 cwd=$2; shift 2
  (cd "$cwd" && erl -noshell -pa "$ebin" -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "$@"); }
