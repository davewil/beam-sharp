#!/usr/bin/env bash
# Build bsc from a SCRATCH COPY of compiler/src. Never touches the repo.
#   build_proto.sh <outdir> [--patch]
# Without --patch: pristine copy (the "without" arm). With --patch: adds the prototype
# `visible_to` declaration + check at add_module_import (the "with" arm). With --patch-caller:
# the caller-side `forbids` variant (proto_patch_caller.py).
# Output: <outdir>/ebin (use with: erl -pa <outdir>/ebin -eval 'bsc:main(...)').
set -euo pipefail
OUT="$1"; PATCH="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
rm -rf "$OUT"; mkdir -p "$OUT/src" "$OUT/ebin"
cp "$REPO"/compiler/src/*.erl "$REPO"/compiler/src/*.xrl "$REPO"/compiler/src/*.yrl "$REPO"/compiler/src/*.app.src "$OUT/src/"
cd "$OUT/src"
if [ "$PATCH" = "--patch" ]; then python3 "$HERE/proto_patch.py" "$OUT/src"; fi
if [ "$PATCH" = "--patch-path" ]; then python3 "$HERE/proto_patch_path.py" "$OUT/src"; fi
if [ "$PATCH" = "--patch-caller" ]; then python3 "$HERE/proto_patch_caller.py" "$OUT/src"; fi
erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl",[{verbose,false}]), halt().' >/dev/null 2>&1
erlc -o ../ebin -I . +debug_info *.erl 2>&1 | grep -v -i warning | head -5 || true
cp bsc.app.src ../ebin/bsc.app
ls ../ebin | wc -l
