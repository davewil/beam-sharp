#!/usr/bin/env escript
%% P6 - Erlang practice: how often does an author write a TYPE guard (is_integer/is_binary/...) on an
%% exported function vs a module-local one? Source .erl files are NOT installed in this sandbox
%% (only .beam), so this reads abstract code from debug_info chunks of stdlib and kernel (OTP 25).
%% This is a convention census, not a semantic claim: Erlang emits nothing the author did not write.
-mode(compile).
main(_) ->
    Dirs = [code:lib_dir(stdlib, ebin), code:lib_dir(kernel, ebin)],
    Files = lists:append([filelib:wildcard(filename:join(D, "*.beam")) || D <- Dirs]),
    Tests = [is_integer, is_atom, is_binary, is_list, is_map, is_tuple, is_float, is_number,
             is_pid, is_function, is_reference, is_bitstring, is_boolean],
    Acc0 = #{exp => {0, 0}, loc => {0, 0}},
    Acc = lists:foldl(fun(F, A) ->
        case beam_lib:chunks(F, [abstract_code]) of
            {ok, {_, [{abstract_code, {_, Forms}}]}} ->
                Exports = lists:append([L || {attribute, _, export, L} <- Forms]),
                lists:foldl(fun({function, _, N, Ar, Cs}, A1) ->
                    Kind = case lists:member({N, Ar}, Exports) of true -> exp; false -> loc end,
                    Has = lists:any(fun(C) -> has_test(C, Tests) end, Cs),
                    {Y, T} = maps:get(Kind, A1),
                    A1#{Kind := {Y + case Has of true -> 1; false -> 0 end, T + 1}};
                   (_, A1) -> A1 end, A, Forms);
            _ -> A
        end
    end, Acc0, Files),
    {EY, ET} = maps:get(exp, Acc), {LY, LT} = maps:get(loc, Acc),
    io:format("modules scanned: ~p (stdlib + kernel, OTP ~s)~n", [length(Files), erlang:system_info(otp_release)]),
    io:format("exported functions with a type-test guard in some clause : ~p of ~p (~.1f%)~n", [EY, ET, 100 * EY / ET]),
    io:format("local-only functions with a type-test guard in some clause: ~p of ~p (~.1f%)~n", [LY, LT, 100 * LY / LT]),
    case LY > 0 of true -> io:format("ASSERT ok (local functions do carry type guards: authors write them where they want them)~n");
                   false -> halt(1) end.
has_test({clause, _, _, Guards, _}, Tests) -> contains_call(Guards, Tests).
contains_call({call, _, {atom, _, F}, Args}, Tests) ->
    lists:member(F, Tests) orelse contains_call(Args, Tests);
contains_call(T, Tests) when is_tuple(T) -> contains_call(tuple_to_list(T), Tests);
contains_call([H | T], Tests) -> contains_call(H, Tests) orelse contains_call(T, Tests);
contains_call(_, _) -> false.
