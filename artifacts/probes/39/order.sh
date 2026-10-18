#!/bin/bash
# Ticket 39: the original harness times each implementation in ONE block of 25 runs, always in the same order
# (Erlang, Elixir, Gleam, beam-sharp last). Does being later in the block order cost anything?
# Blocks of 25 runs per implementation, repeated 12 times, with the two orders alternated.
. "$(dirname "$0")/../env.sh"
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
work 39o
bsc -o . $ROOT/aoc/bench/Day01 >/dev/null 2>&1
cp $ROOT/aoc/bench/bench_erl.erl .
cat > oblock.erl <<'B'
-module(oblock).
-export([main/1]).
main([Input]) ->
    {ok, Bin} = file:read_file(Input),
    Ds = [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    E = {erlang, fun bench_erl:part_two/1}, B = {beamsharp, fun 'Day01':'PartTwo'/1},
    Block = fun({Name, F}) -> {Name, hd(lists:sort([element(1, timer:tc(F, [Ds])) || _ <- lists:seq(1, 25)]))} end,
    Rs = lists:append([begin
            Order = case I rem 2 of 1 -> [E, B]; 0 -> [B, E] end,
            [{I rem 2, Pos, Block(Impl)} || {Pos, Impl} <- lists:zip([first, second], Order)]
         end || I <- lists:seq(1, 12)]),
    Avg = fun(L) -> lists:sum(L) / length(L) / 1000 end,
    Sel = fun(Name, Pos) -> [M || {_, P, {N, M}} <- Rs, N =:= Name, P =:= Pos] end,
    io:format("  min-of-25 block time, mean over 12 repeats (ms):~n"),
    [io:format("    ~-9s when timed ~-6s ~6.2f~n", [N, P, Avg(Sel(N, P))]) || N <- [erlang, beamsharp], P <- [first, second]],
    halt().
parse([$L | X]) -> -list_to_integer(X);
parse([$R | X]) -> list_to_integer(X).
B
for otp in otp28 beam; do
  E=$S/mamba/envs/$otp/bin; mkdir -p $otp
  $E/erlc -o $otp bench_erl.erl oblock.erl
  $E/erl -noshell -eval 'compile:file("Day01.abstr",[from_abstr,debug_info,{outdir,"'$otp'"}]),halt().'
  echo "=== $otp"; $E/erl -noshell +S 1:1 -pa $otp -eval 'oblock:main(["'$ROOT'/aoc/2025/Day01/input.txt"])'
done
