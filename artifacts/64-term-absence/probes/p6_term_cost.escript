#!/usr/bin/env escript
%% p6: heap words of bare V vs {ok,V} vs {some,V}; also erlang:external_size.
%% erts_debug:flat_size/1 counts words of a freshly-built flat copy (includes the
%% 3-word tuple header+tag+value overhead; literals in compiled code live in the
%% literal area and cost nothing per call - see p7).
%% Run: escript p6_term_cost.escript > p6_term_cost.out ; exit 1 if tagged is NOT >= bare + 2 words.
main(_) ->
    Vs = [{"atom",              nothing},
          {"small int",         42},
          {"binary <<\"hello\">> (heap bin)", <<"hello">>},
          {"binary 100B (refc, off-heap)",    binary:copy(<<"x">>, 100)},
          {"5-elem list",       [1,2,3,4,5]},
          {"nested map",        #{a => #{b => [1,2,3], c => <<"x">>}, d => 1}},
          {"existing {ok,_} tuple (reuse)", {ok, 1}}],
    io:format("~-34s ~6s ~6s ~6s ~8s~n", ["V", "bare", "{ok,V}", "delta", "ext_sz+"]),
    Bad = [begin
             B = erts_debug:flat_size(V), T = erts_debug:flat_size({ok, V}),
             S = erts_debug:flat_size({some, V}),
             EB = erlang:external_size(V), ET = erlang:external_size({ok, V}),
             io:format("~-34s ~6w ~6w ~6w ~8w   {some,V}=~w~n", [N, B, T, T - B, ET - EB, S]),
             case (T - B =:= 3) andalso (S =:= T) of true -> []; false -> [N] end
           end || {N, V} <- Vs],
    case lists:append(Bad) of [] -> io:format("ASSERT delta == 3 words (arity word + tag slot + value slot) and {some,V} == {ok,V}: holds~n"), halt(0);
                              Ns -> io:format("ASSERT FAILS for ~p~n", [Ns]), halt(1) end.
