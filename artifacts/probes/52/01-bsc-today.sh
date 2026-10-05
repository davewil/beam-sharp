#!/usr/bin/env bash
# CLAIM (ticket 52): "Compile it on a machine with a different ERL_LIBS and it fails at the call site
# with error:undef, having promised nothing."
# This probe separates COMPILE from RUN and tests four shapes with today's bsc (repo build).
# REFUTED IF: compile (no ERL_LIBS) exits non-zero or prints a diagnostic  -> then bsc already checks;
#             OR the run with ERL_LIBS unset does not end in `error:undef`;
#             OR running Pure.Two (does not touch the dependency) fails -> failure would not be at the call site;
#             OR a missing *function* (Nope) and a missing *application* (Ghost) are told apart by the text.
. "$(dirname "$0")/lib.sh"
O=$WORK/o01; rm -rf "$O"; mkdir -p "$O"
run() { echo "\$ $*"; "$@"; echo "[exit=$?]"; echo; }
unset ERL_LIBS
echo "### A. dependency absent from the code path (ERL_LIBS unset)"
run bsc -o "$O" "$BS/Pure"                       # compile only
run bsc -o "$O" "$BS/Pure" Make                  # compile + run the call that reaches the dependency
run bsc -o "$O" "$BS/Pure" Two                   # compile + run a function that never touches it
echo "### B. same program, ERL_LIBS pointing at the mix-built app"
ERL_LIBS=$MYLIBS run bsc -o "$O" "$BS/Pure" Make
echo "### C. ERL_LIBS set to a DIFFERENT directory (an OTP-style app, not the dependency)"
ERL_LIBS=$ERLLIBS run bsc -o "$O" "$BS/Pure" Make
echo "### D. module present, function absent (MyLib.nope/0), ERL_LIBS correct"
ERL_LIBS=$MYLIBS run bsc -o "$O" "$BS/Nope" Call
echo "### E. module absent altogether (Elixir.NoSuchLib), ERL_LIBS correct"
ERL_LIBS=$MYLIBS run bsc -o "$O" "$BS/Ghost" Call
echo "### F. what the compiled beam says about its dependency today"
erl -noshell -eval '{ok,{_,[{attributes,A},{imports,I}]}}=beam_lib:chunks(hd(filelib:wildcard("'$O'/Pure.beam")),[attributes,imports]), io:format("attributes=~p~nimports=~p~n",[A,I]),halt().'
