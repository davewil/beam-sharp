#!/usr/bin/env bash
# Build a scratch bsc on OTP < 26 (the repo pins OTP 28; leex there provides TokenLoc, OTP 25 does not).
# usage: build-bsc.sh DEST [PATCH...]   -- patches are `diff -u` against compiler/src and are applied to the copy.
# SHIM (read this): TokenLoc -> {TokenLine,1} and an adjust_col/3 stub, so diagnostic COLUMNS are wrong.
# Parser, checker and emitter semantics are untouched. rebar3 does not work in this environment.
set -euo pipefail
dest=$1; shift
root=$(cd "$(dirname "$0")/.." && pwd)
rm -rf "$dest"; mkdir -p "$dest/ebin"
cp "$root"/compiler/src/*.erl "$root"/compiler/src/*.xrl "$root"/compiler/src/*.yrl "$dest/"
for p in "$@"; do (cd "$dest" && patch -s -p0 --no-backup-if-mismatch "$(basename "$(grep -m1 '^--- ' "$p" | awk '{print $2}')")" < "$p"); done
cd "$dest"
sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
echo 'adjust_col(_Chars, Len, C) -> C + Len.' >> bs_lexer.xrl
erl -noshell -eval 'leex:file("bs_lexer.xrl"),yecc:file("bs_parser.yrl"),halt().' >/dev/null
erlc -o ebin *.erl 2>&1 | grep -i 'error' || true
ls ebin | wc -l
