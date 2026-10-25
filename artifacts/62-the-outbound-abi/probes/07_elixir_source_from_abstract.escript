#!/usr/bin/env escript
%% Probe 07: Elixir's .ex/.erl sources are not installed (only .beam). The tokenizer/parser beams carry
%% abstract_code with ORIGINAL source line numbers, so we locate the alias/quoted-call rules from them.
main([Beam, Needle]) ->
    {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks(Beam,[abstract_code]),
    walk(AC, Needle).
walk(T, N) when is_tuple(T) ->
    case T of
        {string, L, S} -> case string:find(S, N) of nomatch -> ok; _ -> io:format("~s line ~p: ~p~n",[N,L,S]) end;
        {bin_element, _, {string, L, S}, _, _} -> case string:find(S, N) of nomatch -> ok; _ -> io:format("line ~p: ~s~n",[L,string:slice(S,0,160)]) end;
        _ -> ok
    end,
    walk(tuple_to_list(T), N);
walk([H|T], N) -> walk(H, N), walk(T, N);
walk(_, _) -> ok.
