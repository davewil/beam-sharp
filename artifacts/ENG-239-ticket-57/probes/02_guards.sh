#!/bin/bash
# H: the SAME gap exists in clause guards and switch arms, because apply_guard/3 calls the same alternatives/1
#    (bs_check.erl:5123 and :1984). Prediction: pairs that cover every int are proved exhaustive with 0 and refused
#    (inexhaustive, residual = everything) with -1, 1-2, 2+3.
# FALSIFIED if: the -1 pair is accepted, or the 0 pair is refused (control).
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
erlc -o $W/ebin $D/drv.erl $D/guards.erl
erl -noshell -pa $W/ebin -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]), guards:main(), halt().'
