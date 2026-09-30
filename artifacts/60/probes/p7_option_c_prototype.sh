#!/usr/bin/env bash
# P7: Option C (callee-side `friend Mod` lines in the helper module) prototyped as option_c.patch.
cd "$(dirname "$0")"
./make_option_c_patch.sh >/dev/null
OUT=/tmp/bsc-build-60c; rm -rf $OUT; mkdir -p $OUT/gen $OUT/ebin
sed -e 's/TokenLoc/{TokenLine,1}/g' /tmp/optc-src/b/bs_lexer.xrl > $OUT/gen/bs_lexer.xrl
echo 'adjust_col(_Chars, _Len, C) -> C.' >> $OUT/gen/bs_lexer.xrl
(cd $OUT/gen && erl -noshell -eval 'leex:file("bs_lexer.xrl",[]), halt().')
(cd /tmp/optc-src/b && erl -noshell -eval 'R=yecc:file("bs_parser.yrl",[{parserfile,"'$OUT'/gen/bs_parser.erl"}]), io:format("yecc: ~p~n",[R]), halt().')
(cd /tmp/optc-src/b && erlc -o $OUT/ebin -I . $OUT/gen/bs_lexer.erl $OUT/gen/bs_parser.erl *.erl 2>&1 | grep -v '^%' | grep -v 'Warning: format')
export BSC_EBIN=$OUT/ebin
rm -rf /tmp/p7out; mkdir -p /tmp/p7out
for t in "Shop/Billing Bill" "Shop/Orders Apply" "Web/Checkout Total"; do set -- $t
  echo "--- $1 -> $2(103)"; ./_bsc.sh --src-root fx7 -o /tmp/p7out fx7/$1 $2 103; echo "exit=$?"; done
echo '--- diff size'; echo "added lines: $(grep -c '^+[^+]' option_c.patch)  removed: $(grep -c '^-[^-]' option_c.patch)"
