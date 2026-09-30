#!/usr/bin/env bash
# What does inlining do to the stack trace of a crash inside the inlined function?
R=/home/user/beam-sharp/artifacts/39; O=$R/build/st
for o in "" "+inline"; do
  erlc $o -o $O $R/probes/st.erl
  echo "--- erlc $o"; erl -noshell -pa $O -eval 'try st:f(0) catch error:E:S -> io:format("~p~n~p~n",[E,S]) end, halt().'
done
