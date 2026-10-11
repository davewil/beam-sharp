#!/usr/bin/env bash
# Builds a PROTOTYPE bsc (not part of the repo) into $OUT/ebin from a COPY of compiler/src plus deps.patch.
# NEVER touches compiler/src. Usage: ./build.sh [OUT]   (default: ../probes/fixtures/_proto)
set -e
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
H="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$H/../probes/fixtures/_proto}"
rm -rf "$OUT"; mkdir -p "$OUT/src" "$OUT/ebin"
cp /home/user/beam-sharp/compiler/src/* "$OUT/src/"
( cd "$OUT/src" && patch -p1 -s < "$H/deps.patch" ) && cp "$H/bs_deps_proto.erl" "$OUT/src/"
cd "$OUT/src"
erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), {ok,_}=yecc:file("bs_parser.yrl"), halt().' 2>&1 | grep -v '^$' | tail -2
erlc +debug_info -o ../ebin *.erl 2>&1 | grep -E "^[^ ]+\.erl:[0-9]+:[0-9]+: (error|Error)" || true
cp bsc.app.src ../ebin/bsc.app
echo "prototype built: $OUT/ebin ($(ls ../ebin | wc -l) files)"
