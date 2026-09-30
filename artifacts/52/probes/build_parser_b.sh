#!/usr/bin/env bash
# Builds the SCRATCH parser used by p06: repo grammar + one production (per-block application).  Needs build-bsc.sh first.
set -e
R=/home/user/beam-sharp/compiler/src/bs_parser.yrl; O=${BSC_OUT:-/tmp/bsc52}; mkdir -p $O/genB $O/ebinB
cp $R $O/genB/bs_parser.yrl
awk '/^Erlang code\./ && !d { print "foreign_decl -> '"'"'using'"'"' atom_lit '"'"'in'"'"' atom_lit '"'"'{'"'"' foreign_sigs '"'"'}'"'"' : {foreign, line('"'"'$1'"'"'), value('"'"'$2'"'"'), value('"'"'$4'"'"'), '"'"'$6'"'"'}."; print ""; d=1 } { print }' $O/genB/bs_parser.yrl > $O/genB/p.yrl && mv $O/genB/p.yrl $O/genB/bs_parser.yrl
erl -noshell -eval '{ok,_}=yecc:file("'$O'/genB/bs_parser.yrl",[{parserfile,"'$O'/genB/bs_parser.erl"}]),halt().'
erlc -o $O/ebinB $O/genB/bs_parser.erl
ls $O/ebinB
