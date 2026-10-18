#!/usr/bin/env bash
# S-GLEAM — what does gleam emit at a pub vs private function entry?  Gleam 1.12.0, target erlang.
source "$(dirname "$0")/../lib.sh"
P=$WORK/gp; rm -rf $P; cp -r "$(dirname "$0")/gleam_p" $P
cd $P && gleam build 2>&1 | tail -3
E=$(find build -name 'gp.erl' | head -1); echo "--- $E (functions only):"
grep -vE '^-(compile|define|file|export|type|spec|opaque)|^%|^$' $E | head -30
echo "--- Erlang caller hands the pub Int function a float, and the pub Order function a wrong map:"
erl -noshell -pa build/dev/erlang/gp/ebin -eval '
  io:format("double(1.5)         -> ~p~n",[gp:double(1.5)]),
  io:format("pub_total(wrong)    -> ~p~n",[catch gp:pub_total({not_order, 1, 2})]),
  io:format("pub_total({order,1,99})-> ~p~n",[catch gp:pub_total({order, 1, 99})]),
  halt().'
echo "--- is_integer/is_float anywhere in the compiler's Erlang emitter (erlang.rs, v1.12.0): $(grep -c 'is_integer\|is_float' /tmp/dl/src/erlang.rs)"
