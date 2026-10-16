%% 64 / P1 — what does a tagged success cost on the heap, against a bare one?
%% erts_debug:flat_size/1 counts words of the term itself (not shared literals).
-module(p1_size).
-export([main/0]).
main() ->
  Vals = [{"small int", 7}, {"bignum", 1 bsl 70}, {"atom", foo}, {"12B binary", <<"hello world!">>},
          {"100B binary", binary:copy(<<"x">>,100)}, {"5-elem list", [1,2,3,4,5]}, {"map 2 keys", #{a=>1,b=>2}}],
  io:format("~-14s ~8s ~8s ~6s~n", ["value","bare","{ok,V}","delta"]),
  [begin B = erts_debug:flat_size(V), T = erts_debug:flat_size({ok,V}),
     io:format("~-14s ~8w ~8w ~6w~n", [N,B,T,T-B]) end || {N,V} <- Vals],
  io:format("absent: bare atom nothing=~w words, tagged absent=~w words~n",
    [erts_debug:flat_size(nothing), erts_debug:flat_size(absent)]),
  halt().
