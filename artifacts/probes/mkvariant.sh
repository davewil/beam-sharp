#!/usr/bin/env bash
# mkvariant.sh NAME [PATCH...]  -> $PROBE_HOME/variants/NAME/ebin : compiler/src + patches, built with OTP 28.
# Patches are `diff -u` against compiler/src (paths a/<file>), kept beside the briefs.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
name=$1; shift
v=$PROBE_HOME/variants/$name; rm -rf "$v"; mkdir -p "$v/src" "$v/ebin"
cp "$BSC_SRC"/* "$v/src/"
for p in "$@"; do (cd "$v/src" && patch -p1 -s < "$root/artifacts/probes/patches/$p") || { echo "patch $p failed" >&2; exit 1; }; done
cd "$v/src"
erl -noshell -eval 'leex:file("bs_lexer.xrl",[{error_location,column}]), yecc:file("bs_parser.yrl",[{report,false}]), halt().'
erlc -o ../ebin *.erl 2>&1 | grep -v '^%' | grep -v '^$' | head
echo "$v/ebin"
