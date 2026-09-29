#!/usr/bin/env escript
%% PROBE 3b — "a second export label of the same function": can the BEAM export TWO names that
%% share ONE code label? Abstract Format cannot say it (an -export names a function that has a
%% body of its own); the only route is rewriting the .beam's AtU8 + ExpT chunks after the fact.
%% argv: PLAIN_N10_BEAM
%%
%% EXPECTED (before run):
%%   X1 rewriting works: the edited beam loads (code:load_binary -> {module,'N10'}).
%%   X2 get_item5(1) then returns the same as 'GetItem5'(1)  (both exports at one label).
%%   X3 a crash inside the callee, entered via the alias, is attributed in the stacktrace to
%%      whichever name the func_info records: 'GetItem5' (single name; the alias name never appears).
%%   X4 module_info(exports) length is n+3+1 (one extra export).
%%   Conclusion the brief draws if X1..X4 hold: label-sharing is possible only as a post-compile
%%   beam rewrite (compile:forms cannot emit it), and no code is duplicated, unlike the wrapper.
main([Beam]) ->
    {ok, Bin} = file:read_file(Beam),
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    {"AtU8", At} = lists:keyfind("AtU8", 1, Chunks),
    {"ExpT", Ex} = lists:keyfind("ExpT", 1, Chunks),
    Atoms = parse_atoms(At),
    IdxOf = fun(A) -> length(lists:takewhile(fun(X) -> X =/= A end, Atoms)) + 1 end,
    <<NEx:32, ExRest/binary>> = Ex,
    Triples = [{I, Ar, L} || <<I:32, Ar:32, L:32>> <= ExRest],
    NEx = length(Triples),
    {_, 1, Label} = lists:keyfind(IdxOf('GetItem5'), 1, Triples),
    NewAtom = <<"get_item5">>,
    NAt = length(Atoms) + 1,
    <<Cnt:32, AtRest/binary>> = At,
    At2 = <<(Cnt + 1):32, AtRest/binary, (byte_size(NewAtom)):8, NewAtom/binary>>,
    Ex2 = <<(NEx + 1):32, ExRest/binary, NAt:32, 1:32, Label:32>>,
    Chunks2 = lists:keyreplace("ExpT", 1, lists:keyreplace("AtU8", 1, Chunks, {"AtU8", At2}), {"ExpT", Ex2}),
    {ok, New} = beam_lib:build_module(Chunks2),
    _ = Bin,
    R = code:load_binary('N10', "n10_edited.beam", New),
    io:format("load: ~p~n", [R]),
    X1 = element(1, R) =:= module,
    V1 = catch 'N10':get_item5(1), V2 = 'N10':'GetItem5'(1),
    io:format("get_item5(1)=~p GetItem5(1)=~p~n", [V1, V2]),
    X2 = V1 =:= V2,
    Exports = length('N10':module_info(exports)),
    io:format("exports=~p~n", [Exports]),
    X4 = Exports =:= 10 + 3 + 1,
    Crash = try 'N10':get_item5(not_an_int) catch error:E:St -> {E, [{F, A} || {_, F, A, _} <- St]} end,
    io:format("crash via alias: ~p~n", [Crash]),
    X3 = case Crash of {_, [{'GetItem5', _} | _]} -> true; _ -> false end,
    [io:format("~s ~s~n", [K, case V of true -> "PASS"; false -> "FAIL" end])
     || {K, V} <- [{"X1 loads", X1}, {"X2 same value", X2}, {"X3 stack names callee", X3}, {"X4 one extra export", X4}]],
    io:format("~s p3b~n", [case X1 andalso X2 andalso X3 andalso X4 of true -> "PASS"; false -> "FAIL" end]).

parse_atoms(<<N:32, Rest/binary>>) -> parse_atoms(N, Rest, []).
parse_atoms(0, _, Acc) -> lists:reverse(Acc);
parse_atoms(N, <<L:8, A:L/binary, Rest/binary>>, Acc) ->
    parse_atoms(N - 1, Rest, [binary_to_atom(A, utf8) | Acc]).
