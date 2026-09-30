#!/usr/bin/env bash
# No rebar3 is installed and OTP is 25 (repo pins 28.5).  Two deviations, both on a COPY of the lexer:
#  - leex in OTP 25 has no `TokenLoc` or `error_location`; TokenLoc is rewritten to {TokenLine,1},
#    so columns in diagnostics are wrong (always 1).  Line numbers and everything else are unaffected.
#  - adjust_col/3 (template-string hole positions only) is stubbed.
# No module is edited in compiler/.  json:encode (OTP 27+) is only reached by --diagnostics json.
set -e
R=/home/user/beam-sharp/compiler; O=${BSC_OUT:-/tmp/bsc52}
mkdir -p $O/ebin $O/gen
sed 's/TokenLoc/{TokenLine,1}/g' $R/src/bs_lexer.xrl > $O/gen/bs_lexer.xrl
printf '\nadjust_col(_, _, C) -> C.\n' >> $O/gen/bs_lexer.xrl
erl -noshell -eval '{ok,_}=leex:file("'$O'/gen/bs_lexer.xrl",[{scannerfile,"'$O'/gen/bs_lexer.erl"}]),{ok,_}=yecc:file("'$R'/src/bs_parser.yrl",[{parserfile,"'$O'/gen/bs_parser.erl"}]),halt().'
erlc -o $O/ebin -I $R/src $O/gen/*.erl $R/src/*.erl 2>&1 | grep -i 'error' || true
cp $R/src/bsc.app.src $O/ebin/bsc.app
ls $O/ebin | wc -l
