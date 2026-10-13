#!/usr/bin/env bash
# Print the guards of selected functions of the emitted B59 module. Usage: BSC=<bsc> absdump.sh
set -u
BSC=${BSC:?}; W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/B59"
cat > "$W/B59/b59.bs" <<'B'
module B59
type Byte = int where value >= 0 and value <= 255
public int Via(Byte b)
Via(b) -> PrivInt(b)
private int PrivInt(Byte b)
PrivInt(b) -> b + 1
B
cd "$W" && "$BSC" B59 >/dev/null 2>&1; D=$(find "$W" -name 'B59.beam' -printf '%h\n' | head -1)
erl -noshell -eval '
 {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks("'"$D"'/B59.beam",[abstract_code]),
 [io:format("~s guards: ~s~n",[N, lists:flatten([erl_pp:guard(G) || {clause,_,_,G,_} <- Cs, G =/= []])]) || {function,_,N,_,Cs} <- AC, N =/= '"'"'bs@type_atoms'"'"'],
 {ok,{_,[{"Code",C}]}} = beam_lib:chunks("'"$D"'/B59.beam",["Code"]), io:format("Code chunk bytes: ~p~n",[byte_size(C)]), halt().' 2>&1 | tail -12
