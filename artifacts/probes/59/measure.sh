#!/usr/bin/env bash
# Ticket 59: cost of the private-function guards. Usage: BSC=<bsc variant> measure.sh
# Prints: Code-chunk bytes of the emitted beam, and median ns/call of a private call in a tight B# loop.
set -u
BSC=${BSC:?set BSC}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/B59"
cat > "$W/B59/b59.bs" <<'B'
module B59

record Inner { N: int }
type Byte = int where value >= 0 and value <= 255

public int RunRec(int n, int acc)
RunRec(n, acc) when n <= 0 -> acc
RunRec(n, acc) when n > 0 -> RunRec(n - 1, acc + PrivRec(Inner{ N = n }))

private int PrivRec(Inner i)
PrivRec(i) -> i.N

public int RunInt(int n, int acc)
RunInt(n, acc) when n <= 0 -> acc
RunInt(n, acc) when n > 0 -> RunInt(n - 1, acc + PrivInt(7))

private int PrivInt(Byte b)
PrivInt(b) -> b + 1
B
cd "$W" && "$BSC" B59 2>&1 | head -3
D=$(find "$W" -name 'B59.beam' -printf '%h\n' | head -1)
erl -noshell -pa "$D" -eval '
 {ok,{_,[{"Code",C}]}}=beam_lib:chunks("'"$D"'/B59.beam",["Code"]),
 {ok,{_,[{"AtU8",_}]}}=beam_lib:chunks("'"$D"'/B59.beam",["AtU8"]),
 io:format("code_chunk_bytes=~p file_bytes=~p~n",[byte_size(C), filelib:file_size("'"$D"'/B59.beam")]),
 N=5000000,
 Med=fun(F)-> L=lists:sort([element(1,timer:tc(F)) || _<-lists:seq(1,15)]), lists:nth(8,L) end,
 R=Med(fun()-> '"'"'B59'"'"':'"'"'RunRec'"'"'(N,0) end),
 I=Med(fun()-> '"'"'B59'"'"':'"'"'RunInt'"'"'(N,0) end),
 io:format("RunRec(private tag test): ~.2f ns/iter~nRunInt(private int test): ~.2f ns/iter~n",[R*1000/N, I*1000/N]),
 halt().' 2>&1
