#!/usr/bin/env bash
# Builds four bsc variants from a COPY of compiler/src (never edits it):
#   v0 baseline   v1 tag test exported-only   v2 kind test on all   v3 = v1 + v2
#   v4 both tests on exported OR escaping (name taken as a value) functions
# Needs the OTP-25 shim for the lexer (TokenLoc / adjust_col), see README in this dir.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
for v in ${VARIANTS:-v0 v1 v2 v3 v4}; do
  d=$SCRATCH/var/$v; rm -rf "$d"; mkdir -p "$d/gen" "$d/ebin"
  cp "$REPO"/compiler/src/* "$d/gen/"
  case $v in v1|v3) patch -s -d "$d/gen" -p0 < "$HERE/patches/tag_exported_only.patch";; esac
  case $v in v4) patch -s -d "$d/gen" -p0 < "$HERE/patches/reachable.patch";; esac
  case $v in v2|v3) patch -s -d "$d/gen" -p0 < "$HERE/patches/kind_all.patch";; esac
  ( cd "$d/gen"
    sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
    sed -i '/^Erlang code\./a adjust_col(_Chars, Len, C) -> C + Len.' bs_lexer.xrl
    erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), yecc:file("bs_parser.yrl"), halt().' >/dev/null 2>&1
    erlc +debug_info -o "$d/ebin" *.erl >/dev/null 2>&1 || true )
  cat > "$d/bsc" <<W
#!/bin/sh
exec erl -noshell -pa $d/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra "\$@"
W
  chmod +x "$d/bsc"; echo "$v: $(ls "$d/ebin"/*.beam | wc -l) beams"
done
