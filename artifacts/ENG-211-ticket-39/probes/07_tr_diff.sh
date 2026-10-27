#!/usr/bin/env bash
# Needs the shim bsc on OTP<27 (00_build_shim_bsc.sh), or the real bsc on OTP 28.5 (set BSC="path/to/bsc").
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/bsc39; O=$W/v07; rm -rf $O; mkdir -p $O; cd $O
B=/home/user/beam-sharp/aoc/bench
if [ -n "$BSC" ]; then "$BSC" -o . $B/Day01; else erl -noshell -pa $W/ebin -eval 'bsc:main(["-o",".","'$B'/Day01"]),halt().'; fi
cp $B/bench_erl.erl .; erlc -S bench_erl.erl; erlc +from_abstr -S Day01.abstr
python3 -I "$HERE/07_tr_diff.py" bench_erl.S Day01.S "$(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')"
echo; echo "--- self-test: differ must fire when the optimizer's types really are stripped (erlc +no_type_opt vs bsc Day01)"
mkdir -p nt && erlc +no_type_opt -S -o nt bench_erl.erl
python3 -I "$HERE/07_tr_diff.py" nt/bench_erl.S Day01.S "$(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')" | tail -4
