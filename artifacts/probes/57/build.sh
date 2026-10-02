#!/usr/bin/env bash
# Usage: build.sh OUTDIR [base|grammar|neg|arith]
# Build the REAL B# lexer/parser/checker on OTP 25 into $1 (scratch).
# bsc itself is not buildable here (needs OTP 26 leex); the parser, lexer and
# checker modules are. Two probe-only shims, applied to the SCRATCH copy only:
#   1. leex on OTP 25 names the token location TokenLine, not TokenLoc.
#   2. OTP 26 leex generates adjust_col/3; defined by hand (used only inside
#      $"..{hole}.." interpolation, which no probe here uses).
# Tokens therefore carry integer lines, not {Line,Col}; no AST shape below depends on it.
set -euo pipefail
src=$(cd "$(dirname "$0")/../../../compiler/src" && pwd)
out=$1; variant=${2:-base}; here=$(cd "$(dirname "$0")" && pwd)
rm -rf "$out"; mkdir -p "$out"; cd "$out"
cp "$src"/*.erl "$src"/*.xrl "$src"/*.yrl .
case $variant in
  base) ;;
  grammar) patch -s bs_parser.yrl "$here/grammar-fold.patch" ;;
  neg|arith|negt) patch -s bs_check.erl "$here/checker-fold-$variant.patch" ;;
  *) echo "unknown variant $variant"; exit 2 ;;
esac
sed -i 's/TokenLoc/TokenLine/g' bs_lexer.xrl
cat >> bs_lexer.xrl <<'EOS'

adjust_col(Chars, Len, C) ->
    case lists:member($\n, Chars) of
        false -> C + Len;
        true  -> length(lists:takewhile(fun(X) -> X =/= $\n end, lists:reverse(Chars))) + 1
    end.
EOS
erl -noshell -eval 'yecc:file("bs_parser.yrl",[{verbose,false}]), leex:file("bs_lexer.xrl"), halt().' 2>&1 | grep -v conflicts || true
erlc -o . *.erl 2>&1 | grep -i "error" || true
test -f bs_parser.beam -a -f bs_lexer.beam -a -f bs_check.beam
