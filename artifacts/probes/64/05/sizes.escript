#!/usr/bin/env escript
%% Heap cost (words) of the representations of a "found" value V.
%%   bare     = V                      (B# option<int>/result<int,E> success today)
%%   ok       = {ok, V}                (Erlang maps:find, Elixir Map.fetch, Gleam Ok(V), B# (:ok, V))
%%   some     = {some, V}              (Gleam option.Some(V); B# hypothetical (:some, V))
%%   tagged3  = {ok, V}  vs  bare plus the absent atom (no cost)
%% erts_debug:flat_size = words of the term itself; the wrapper adds a 2-tuple = 3 words (header + 2 slots) when V is immediate,
%% and exactly 3 words when V is boxed (the 2-tuple is a separate heap object pointing to V).
main(_) ->
    Big = lists:seq(1, 3),
    Vs = [{"small int 42", 42},
          {"large int 2^70", 1 bsl 70},
          {"atom", foo},
          {"binary <<\"hello\">> (heap bin, 5B)", <<"hello">>},
          {"binary, 100 bytes (>64: refc)", binary:copy(<<"x">>, 100)},
          {"3-element list", Big},
          {"2-tuple", {a, b}},
          {"map #{a=>1,b=>2,c=>3}", #{a => 1, b => 2, c => 3}},
          {"map 40 keys (hashmap)", maps:from_list([{I, I} || I <- lists:seq(1, 40)])}],
    io:format("~-52s ~6s ~6s ~6s ~7s | ~6s ~6s ~6s~n",
              ["V", "V", "{ok,V}", "{some,V}", "delta", "ttb V", "ttb ok", "ttb some"]),
    lists:foreach(fun({N, V}) ->
        S0 = erts_debug:flat_size(V),
        S1 = erts_debug:flat_size({ok, V}),
        S2 = erts_debug:flat_size({some, V}),
        B0 = byte_size(term_to_binary(V)),
        B1 = byte_size(term_to_binary({ok, V})),
        B2 = byte_size(term_to_binary({some, V})),
        io:format("~-52s ~6w ~6w ~6w ~7w | ~6w ~6w ~6w~n", [N, S0, S1, S2, S1 - S0, B0, B1, B2])
    end, Vs),
    io:format("~nwords on a 64-bit emulator = 8 bytes; wrapper delta in bytes = delta*8~n"),
    io:format("erts word size: ~p bytes~n", [erlang:system_info(wordsize)]),
    io:format("~nExtra: the failure value itself costs 0 words (an atom is immediate): flat_size(absent)=~p flat_size(nothing)=~p~n",
              [erts_debug:flat_size(absent), erts_debug:flat_size(nothing)]),
    Bare = lists:seq(1, 1000),
    Wrapped = [{some, I} || I <- Bare],
    io:format("Extra: 1000 distinct small-int options as a list, words: bare=~p wrapped=~p (delta ~p = 3/elem)~n",
              [erts_debug:flat_size(Bare), erts_debug:flat_size(Wrapped),
               erts_debug:flat_size(Wrapped) - erts_debug:flat_size(Bare)]),
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]).
