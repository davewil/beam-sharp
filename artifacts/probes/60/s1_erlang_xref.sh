#!/bin/bash
# S1: Erlang. erlc accepts billing -> pricing:compute/1 (exported, no caller restriction exists); xref reports callers only as an after-the-fact lint.
D=$(mktemp -d); cp "$(dirname "$0")"/s1_erl_src/*.erl $D; cd $D
erlc +debug_info *.erl && echo "erlc: all four modules compiled, billing -> pricing accepted"
erl -noshell -eval 'x:main(), halt().'
echo "--- control: same modules compiled WITHOUT +debug_info (xref has nothing to read)"
rm -f *.beam; erlc *.erl; erl -noshell -eval 'io:format("~p~n",[catch x:main()]), halt().' 2>&1 | head -2 | cut -c1-160
rm -rf $D
