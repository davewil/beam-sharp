#!/usr/bin/env escript
%% t39: interleaved timing of bench_erl compiled 3 ways + beam-sharp Day01; 40 rounds, min and median ms
main(_) ->
  {ok,Bin}=file:read_file("/home/user/beam-sharp/aoc/2025/Day01/input.txt"),
  Ds=[case L of [$L|N]-> -list_to_integer(N); [$R|N]->list_to_integer(N) end || L <- string:split(binary_to_list(Bin),"\n",all), L=/=""],
  Impls=[{erl_default,"b39_default/bench_erl",fun()->bench_erl:part_two(Ds) end},
         {erl_no_type_opt,"b39_notype/bench_erl",fun()->bench_erl:part_two(Ds) end},
         {erl_no_ssa_opt,"b39_nossa/bench_erl",fun()->bench_erl:part_two(Ds) end},
         {beam_sharp,"b39/Day01",fun()->'Day01':'PartTwo'(Ds) end}],
  Time=fun({_N,P,F})-> M=list_to_atom(filename:basename(P)), code:purge(M), code:delete(M), {module,M}=code:load_abs(P), 6770=F(), {T,_}=timer:tc(F), T end,
  Rs=[[{N,Time(I)} || I={N,_,_} <- Impls] || _ <- lists:seq(1,40)],
  [begin Ts=lists:sort([T||R<-Rs,{N2,T}<-R,N2=:=N]), io:format("~-16s min ~.2f ms  median ~.2f ms~n",[N,hd(Ts)/1000,lists:nth(21,Ts)/1000]) end || {N,_,_} <- Impls].
