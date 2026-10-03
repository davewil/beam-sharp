#!/bin/sh
# p01: does a B# program that uses an Elixir module compile with no dependency
# on the code path, and what happens at run time with and without it?
# Baseline claim in ticket 52: "fails at the call site with error:undef".
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh
W=$(mktemp -d); cp -r "$HERE/Probe" "$W/"; cd "$W"
echo "== A. ERL_LIBS unset: compile+run"
env -u ERL_LIBS $BSC Probe Shout '"hi"'; echo "exit=$?"
echo "== B. ERL_LIBS=elixir libs: compile+run"
ERL_LIBS=/tmp/otp/lib/elixir/lib $BSC Probe Shout '"hi"'; echo "exit=$?"
echo "== C. compile on machine WITH elixir; run beam on machine WITHOUT"
ERL_LIBS=/tmp/otp/lib/elixir/lib $BSC Probe >/dev/null 2>&1; ls *.beam
env -u ERL_LIBS erl -noshell -pa . -eval 'try io:format("~p~n",[ (catch '"'"'Probe'"'"':'"'"'Shout'"'"'(<<"hi">>)) ]) after halt() end.' 
echo "== D. -pa . and what module name did it emit?"
ls
