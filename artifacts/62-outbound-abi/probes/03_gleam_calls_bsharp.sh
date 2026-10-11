#!/usr/bin/env bash
# One command: ./03_gleam_calls_bsharp.sh -> probes/03_gleam_calls_bsharp.out
# Claim: "@external(erlang, \"Shop\", \"New\") compiles" (ticket only compiled it). Here it is RUN.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
E=$WORK/e; rm -rf $E; mkdir -p $E; bsc --src-root $HERE/bs -o $E $HERE/bs/Abi
G=$WORK/gl; rm -rf $G; mkdir -p $G; cp -r $HERE/gleam_caller $G/
echo "gleam: $(gleam --version)"
(cd $G/gleam_caller && gleam build 2>&1 | grep -v '^$' | tail -6)
echo "--- run caller:main() with the B# beams on the code path (no ERL_LIBS magic; plain -pa)"
erl -noshell -pa $E -pa $G/gleam_caller/build/dev/erlang/caller/ebin -eval 'caller:main(), halt(0).' 2>&1
echo "--- NEGATIVE CONTROL: same call with a wrong function name must fail at run time (Gleam cannot check it)"
erl -noshell -pa $E -eval 'try '"'"'Abi'"'"':'"'"'NoSuch'"'"'(1) catch C:R -> io:format("~p ~p~n",[C,R]) end, halt(0).' 2>&1
echo "--- NEGATIVE CONTROL 2: without the B# beams on the path"
erl -noshell -pa $G/gleam_caller/build/dev/erlang/caller/ebin -eval 'try caller:main() catch C:R -> io:format("~p ~p~n",[C,R]) end, halt(0).' 2>&1 | head -3
