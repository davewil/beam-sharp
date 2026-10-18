#!/usr/bin/env bash
# 09 — how much does each option change the emitted code of the repo's real examples?
# Compiles every compiler/examples module directory with each variant and sums the
# Code chunks of the .beam files produced.  Modules that fail to compile on OTP 25 fail
# identically on every variant and are excluded from every column (same set).
HERE0="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE0/../../.." && pwd)"
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
export PATH=/tmp/bin:$PATH
W=$(mktemp -d)
for v in v0 v1 v2 v3 v4; do
  mkdir -p $W/$v
  for d in "$REPO"/compiler/examples/*/ ; do
    n=$(basename $d)
    ( cd "$REPO/compiler" && "$SCRATCH/var/$v/bsc" --src-root examples -o $W/$v/$n "examples/$n" >/dev/null 2>&1 )
  done
  erl -noshell -eval '
    Fs = filelib:wildcard("'$W/$v'/*/*.beam") ++ filelib:wildcard("'$W/$v'/*/*/*.beam"),
    Sz = [begin {ok,{_,[{"Code",C}]}} = beam_lib:chunks(F,["Code"]), {filename:basename(F), byte_size(C)} end || F <- Fs],
    As = filelib:wildcard("'$W/$v'/*/*.abstr") ++ filelib:wildcard("'$W/$v'/*/*/*.abstr"),
    Count = fun(Pat) -> lists:sum([begin {ok,B}=file:read_file(A), length(binary:matches(B, Pat)) end || A <- As]) end,
    Insn = fun(Op) -> lists:sum([begin {beam_file,_,_,_,_,Fns}=beam_disasm:file(F),
                 length([I || {function,_,_,_,Code} <- Fns, I <- Code, is_tuple(I), tuple_size(I)>1, element(1,I)=:=test, element(2,I)=:=Op]) end || F <- Fs]) end,
    io:format("'$v': ~p beams, Code total ~p B | before erlc (.abstr): is_integer ~p, is_float ~p, tag tests ~p | after erlc (.beam): is_integer insns ~p, is_float insns ~p~n",
       [length(Sz), lists:sum([S || {_,S} <- Sz]), Count(<<"is_integer">>), Count(<<"is_float">>), Count(<<"map_get">>) , Insn(is_integer), Insn(is_float)]),
    file:write_file("'$W/$v'.sizes", [io_lib:format("~s ~p~n",[N,S]) || {N,S} <- lists:sort(Sz)]), halt().'
done
echo "--- per-module Code-byte deltas vs v0 (modules that change):"
for v in v1 v2 v3 v4; do
  echo "## $v"; join <(sort $W/v0.sizes) <(sort $W/$v.sizes) | awk '$2!=$3{printf "  %-28s %5d -> %5d  (%+d)\n",$1,$2,$3,$3-$2}' | head -12
done
