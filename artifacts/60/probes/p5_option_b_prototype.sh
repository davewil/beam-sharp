#!/usr/bin/env bash
# P5: Option B (an `Internal` path segment limits who may name a module) prototyped as
# option_b.patch against a scratch copy of compiler/src; built on OTP 25 with the same lexer
# deviation as build_bsc.sh. Shows the refusal, the accepted owner, and the diff size.
cd "$(dirname "$0")"; ROOT=$(cd ../../.. && pwd)
./make_option_b_patch.sh >/dev/null
OUT=/tmp/bsc-build-60b; rm -rf $OUT; mkdir -p $OUT/gen $OUT/ebin
sed -e 's/TokenLoc/{TokenLine,1}/g' /tmp/optb-src/b/bs_lexer.xrl > $OUT/gen/bs_lexer.xrl
echo 'adjust_col(_Chars, _Len, C) -> C.' >> $OUT/gen/bs_lexer.xrl
(cd $OUT/gen && erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), halt().')
(cd /tmp/optb-src/b && erl -noshell -eval 'yecc:file("bs_parser.yrl",[{parserfile,"'$OUT'/gen/bs_parser.erl"}]), halt().' >/dev/null)
(cd /tmp/optb-src/b && erlc -o $OUT/ebin -I . $OUT/gen/bs_lexer.erl $OUT/gen/bs_parser.erl *.erl 2>&1 | grep -v '^%' | grep -v 'Warning: format')
export BSC_EBIN=$OUT/ebin
rm -rf /tmp/p5out; mkdir -p /tmp/p5out
echo '--- owner Shop.Orders names Shop.Orders.Internal  (expect 110)'
./_bsc.sh --src-root fx -o /tmp/p5out fx/Shop/Orders Gross 100; echo "exit=$?"
echo '--- sibling Shop.Reports names Shop.Orders.Internal  (expect refusal)'
./_bsc.sh --src-root fx -o /tmp/p5out fx/Shop/Reports Peek 100; echo "exit=$?"
echo '--- --diagnostics term for the refusal'
./_bsc.sh --diagnostics term --src-root fx -o /tmp/p5out fx/Shop/Reports 2>/dev/null; echo "exit=$?"
echo '--- unrelated code is unaffected: Web.Checkout via public Shop.Ledger (expect 101)'
./_bsc.sh --src-root fx -o /tmp/p5out fx/Web/Checkout Total 103; echo "exit=$?"
echo '--- diff size'
wc -l option_b.patch; echo "added lines: $(grep -c '^+[^+]' option_b.patch)  removed: $(grep -c '^-[^-]' option_b.patch)"
echo '--- --api on the violating module (does the query mode refuse too?)'
./_bsc.sh --src-root fx --api fx/Shop/Reports; echo "exit=$?"
