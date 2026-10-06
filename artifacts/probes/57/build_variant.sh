#!/usr/bin/env bash
# build_variant.sh SRC_DIR OUT_EBIN : compile a (copy of) compiler/src into OUT_EBIN. Used by 57c-57e.
set -eu
src=$1; out=$2; mkdir -p "$out" "$out/gen"
erl -noshell -eval "
  {ok,_}=leex:file(\"$src/bs_lexer.xrl\",[{scannerfile,\"$out/gen/bs_lexer.erl\"},{error_location,column}]),
  {ok,_}=yecc:file(\"$src/bs_parser.yrl\",[{parserfile,\"$out/gen/bs_parser.erl\"},{verbose,false}]),
  halt()." >/dev/null 2>&1
erlc -o "$out" -I "$src" "$out"/gen/*.erl "$src"/*.erl 2>&1 | grep -v "^$" | grep -iv warning | head -5 || true
cp "$src/bsc.app.src" "$out/bsc.app" 2>/dev/null || true
