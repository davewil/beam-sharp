#!/usr/bin/env escript
%% p14: what does recording the application in the emitted .beam cost, and can a tool read it without loading?
%% Compiles the same module with 0, 1 and 3 `-bs_requires` attributes via compile:forms/2 (the path bsc's emit takes,
%% bsc.erl:843 `from_abstr`), reports byte_size of the .beam and reads the attribute back with beam_lib.
main(_) ->
    Base = fun(Attrs) ->
        [{attribute,1,module,m}, {attribute,2,export,[{f,0}]}] ++ Attrs ++
        [{function,3,f,0,[{clause,3,[],[],[{atom,3,ok}]}]}] end,
    Size = fun(Attrs) ->
        {ok, m, Bin} = compile:forms(Base(Attrs), [debug_info]), Bin end,
    B0 = Size([]),
    B1 = Size([{attribute,2,bs_requires,[libdep]}]),
    B3 = Size([{attribute,2,bs_requires,[libdep, finch, jason]}]),
    io:format("beam bytes: none=~p one_app=~p (+~p) three_apps=~p (+~p)~n",
              [byte_size(B0), byte_size(B1), byte_size(B1)-byte_size(B0), byte_size(B3), byte_size(B3)-byte_size(B0)]),
    {ok, {m, [{attributes, A}]}} = beam_lib:chunks(B3, [attributes]),
    io:format("read back without loading: ~p~n", [A]).
