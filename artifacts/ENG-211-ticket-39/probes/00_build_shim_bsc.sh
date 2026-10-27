#!/usr/bin/env bash
# Builds a SHIMMED bsc on OTP 25 into $W (default: scratchpad bsc39). The repo pins OTP 28.5; its lexer
# needs leex's TokenLoc (OTP 27+). Shim: TokenLoc -> {TokenLine,1} (columns lost, lines kept) and an
# adjust_col/3 helper. Everything else is the repo's source, unmodified. Only the lexer is altered, so
# bs_emit's forms are real except that every column is 1.
set -e
W="${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39}"
SRC=/home/user/beam-sharp/compiler/src
rm -rf "$W"; mkdir -p "$W/src" "$W/ebin"; cp "$SRC"/* "$W/src/"; cd "$W/src"
sed -i 's/TokenLoc/{TokenLine,1}/g' bs_lexer.xrl
cat >> bs_lexer.xrl <<'X'

adjust_col(Chars, Len, C) ->
    case lists:splitwith(fun(X) -> X =/= $\n end, lists:reverse(Chars)) of
        {_, []} -> C + Len;
        {Same, _}  -> length(Same) + 1
    end.
X
erlc bs_lexer.xrl; erlc bs_parser.yrl 2>&1 | grep -v conflicts || true
erlc +nowarn_export_all +nowarn_unused_function +nowarn_unused_vars -o ../ebin *.erl 2>&1 | grep -iv warning | grep -i error || true
cp bsc.app.src ../ebin/bsc.app
echo "shim bsc at $W/ebin"
