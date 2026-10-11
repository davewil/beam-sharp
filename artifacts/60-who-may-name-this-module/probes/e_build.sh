#!/usr/bin/env bash
# usage: build.sh SRCDIR   -> SRCDIR/../ebin-<name>
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
D=$1; cd $D
erl -noshell -eval 'ok=case leex:file("bs_lexer.xrl",[{error_location,column}]) of {ok,_}->ok; E->io:format("~p~n",[E]),halt(1) end, case yecc:file("bs_parser.yrl",[{verbose,false}]) of {ok,_}->ok; {ok,_,W}->io:format("yecc warn ~p~n",[W]); E2->io:format("~p~n",[E2]),halt(1) end, halt(0).'
rm -rf ../ebin_$(basename $D); mkdir ../ebin_$(basename $D)
erlc +debug_info -o ../ebin_$(basename $D) *.erl 2>&1 | grep -v Warning | head -20
cp /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/bsc-ebin/bsc.app ../ebin_$(basename $D)/
ls ../ebin_$(basename $D) | wc -l
