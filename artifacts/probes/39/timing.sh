#!/bin/bash
# Ticket 39 §3 (does the 20% exist?): interleaved timing of Erlang vs beam-sharp on OTP 28 (the ticket's) and OTP 29.
# Interleaved so machine drift hits both; one scheduler; 400 rounds each; compares paired rounds, not just minima.
# Elixir/Gleam are omitted from OTP-28 runs (their beams were compiled by OTP 29).
. "$(dirname "$0")/../env.sh"
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
work 39t
bsc -o . $ROOT/aoc/bench/Day01 >/dev/null 2>&1
cp $ROOT/aoc/bench/bench_erl.erl .
cat > ibench.erl <<'B'
-module(ibench).
-export([main/1]).
main([Input, NS]) ->
    N = list_to_integer(NS),
    {ok, Bin} = file:read_file(Input),
    Ds = [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Impls = [{erlang, fun bench_erl:part_two/1}, {beamsharp, fun 'Day01':'PartTwo'/1}],
    [6770 = F(Ds) || {_, F} <- Impls],
    Rounds = [begin
                  Order = case I rem 2 of 0 -> Impls; 1 -> lists:reverse(Impls) end,
                  [{Name, element(1, timer:tc(F, [Ds]))} || {Name, F} <- Order]
              end || I <- lists:seq(1, N)],
    T = fun(Name) -> lists:sort([proplists:get_value(Name, R) || R <- Rounds]) end,
    Q = fun(L, P) -> lists:nth(max(1, round(length(L) * P)), L) end,
    [begin L = T(Name),
           io:format("  ~-10s min ~6.2f  p25 ~6.2f  median ~6.2f  p75 ~6.2f  ms~n",
                     [Name, hd(L)/1000, Q(L,0.25)/1000, Q(L,0.5)/1000, Q(L,0.75)/1000]) end
     || {Name, _} <- Impls],
    Slower = length([1 || R <- Rounds, proplists:get_value(beamsharp, R) > proplists:get_value(erlang, R)]),
    Em = Q(T(erlang), 0.5), Bm = Q(T(beamsharp), 0.5),
    io:format("  paired rounds where beam-sharp was slower than Erlang: ~p of ~p;   median ratio ~.3f   min ratio ~.3f~n",
              [Slower, N, Bm / Em, hd(T(beamsharp)) / hd(T(erlang))]),
    halt().
parse([$L | X]) -> -list_to_integer(X);
parse([$R | X]) -> list_to_integer(X).
B
for otp in otp28 beam; do
  E=$S/mamba/envs/$otp/bin; mkdir -p $otp
  $E/erlc -o $otp bench_erl.erl ibench.erl
  $E/erl -noshell -eval 'compile:file("Day01.abstr",[from_abstr,debug_info,{outdir,"'$otp'"}]),halt().'
  for rep in 1 2; do
    echo "=== $otp (OTP $($E/erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')) run $rep"
    $E/erl -noshell +S 1:1 -pa $otp -eval 'ibench:main(["'$ROOT'/aoc/2025/Day01/input.txt","400"])'
  done
done
