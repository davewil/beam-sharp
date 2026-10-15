#!/usr/bin/env escript
%% 64_repr_cost.escript
%% CLAIM (ticket 64 notes / brief): a tagged success costs a tuple per hit: +2 words heap (header + tag... see
%% output) and +4..6 bytes in term_to_binary, while a bare success is free; lookups through a tagged shape
%% cost measurably more than the bare shape.
%% REFUTED if: erts_debug:size of {ok,V} - size of V is not 3 words for every V (immediates: 0 -> 3), or the 1e6-lookup
%%   medians of the maps:get/3 bare shape and the maps:find tagged shape are within noise (min/median overlap).
%% Note maps:find itself allocates the {ok,V} (a BIF), so only the get/3 shape is allocation-free; the escript
%% reports that honestly: the find->unwrap bare shape is NOT cheaper than the tagged one.
%% Prints sizes (words, bytes) and 1e6-lookup time per shape: min and median of 21 runs, ms.
-mode(compile).
main(_) ->
  io:format("erts_debug:size/1 is in WORDS (8 bytes each on this 64-bit VM); tbin = byte_size(term_to_binary(T)).~n"),
  io:format("OTP ~s, word size ~p~n", [erlang:system_info(otp_release), erlang:system_info(wordsize)]),
  Big  = binary:copy(<<"x">>, 1000000),
  Heap = binary:copy(<<"y">>, 40),          %% heap binary (<=64B)
  Vals = [{"small int 42", 42},
          {"bignum 2^70", 1 bsl 70},
          {"atom", hello},
          {"3-key map", #{a=>1,b=>2,c=>3}},
          {"40B binary (heap bin)", Heap},
          {"1,000,000B binary (refc)", Big}],
  io:format("~-26s ~8s ~8s ~8s | ~8s ~8s ~8s~n",["value","bare w","{ok,V} w","{just,V}w","bare B","{ok,V} B","{just,V}B"]),
  [begin
     io:format("~-26s ~8w ~8w ~8w | ~8w ~8w ~8w~n",
       [L, erts_debug:size(V), erts_debug:size({ok,V}), erts_debug:size({just,V}),
        byte_size(term_to_binary(V)), byte_size(term_to_binary({ok,V})), byte_size(term_to_binary({just,V}))])
   end || {L,V} <- Vals],
  io:format("~nflat_size (copy cost on send): int 42 bare=~p {ok,42}=~p; 3-key map bare=~p {ok,M}=~p~n",
     [erts_debug:flat_size(42), erts_debug:flat_size({ok,42}),
      erts_debug:flat_size(#{a=>1,b=>2,c=>3}), erts_debug:flat_size({ok,#{a=>1,b=>2,c=>3}})]),
  %% 1e6 lookups
  M = maps:from_list([{I, I} || I <- lists:seq(1, 1000)]),     %% int values
  Keys = list_to_tuple([(I rem 1100) + 1 || I <- lists:seq(1, 1000)]),  %% ~9% misses
  N = 1000000,
  Shapes = [
   {"bare, lowered as maps:get(K,M,Default) (option<int> lowering)", fun bare_default/3},
   {"bare, lowered as maps:find then unwrap to V | nothing", fun bare_option/3},
   {"tagged ok/error: maps:find -> {ok,V}|error, matched", fun tagged_find/3},
   {"tagged {just,V}|nothing built from find, matched", fun tagged_just/3}],
  io:format("~n1e6 lookups over a 1000-key int map (~~9% misses), consumer sums hits; 21 runs, ms~n"),
  io:format("~-58s ~8s ~8s ~s~n",["shape","min","median","checksum"]),
  [begin
     _ = F(M, Keys, 100000),                       %% warm
     Ts = [begin T0 = erlang:monotonic_time(microsecond), R = F(M, Keys, N),
                 T1 = erlang:monotonic_time(microsecond), {T1-T0, R} end || _ <- lists:seq(1,21)],
     Us = lists:sort([U || {U,_} <- Ts]), {_, Chk} = hd(Ts),
     io:format("~-58s ~8.1f ~8.1f ~w~n",[L, hd(Us)/1000, lists:nth(11,Us)/1000, Chk])
   end || {L,F} <- Shapes],
  ok.

key(Keys, I) -> element((I rem 1000) + 1, Keys).

bare_default(M, Keys, N) -> bd(M, Keys, N, 0).
bd(_,_,0,A) -> A;
bd(M,Keys,I,A) -> case maps:get(key(Keys,I), M, absent) of absent -> bd(M,Keys,I-1,A); V -> bd(M,Keys,I-1,A+V) end.

bare_option(M, Keys, N) -> bo(M, Keys, N, 0).
bo(_,_,0,A) -> A;
bo(M,Keys,I,A) ->
  R = case maps:find(key(Keys,I), M) of {ok,V} -> V; error -> nothing end,
  case R of nothing -> bo(M,Keys,I-1,A); V2 -> bo(M,Keys,I-1,A+V2) end.

tagged_find(M, Keys, N) -> tf(M, Keys, N, 0).
tf(_,_,0,A) -> A;
tf(M,Keys,I,A) -> case maps:find(key(Keys,I), M) of {ok,V} -> tf(M,Keys,I-1,A+V); error -> tf(M,Keys,I-1,A) end.

tagged_just(M, Keys, N) -> tj(M, Keys, N, 0).
tj(_,_,0,A) -> A;
tj(M,Keys,I,A) ->
  R = case maps:find(key(Keys,I), M) of {ok,V} -> {just,V}; error -> nothing end,
  case R of {just,V2} -> tj(M,Keys,I-1,A+V2); nothing -> tj(M,Keys,I-1,A) end.
