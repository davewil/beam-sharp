%%% Probe 59h: 18b's census (method unchanged: a position is defended only if EVERY clause constrains it
%%% structurally or mentions it in a guard), split exported vs LOCAL. Question: do Erlang authors guard
%%% private functions at the rate they guard public ones? OTP 25 stdlib + kernel, abstract code of shipped beams.
-module(census59).
-export([main/0]).

main() ->
    Files = lists:append([filelib:wildcard(filename:join([code:lib_dir(A), "ebin", "*.beam"])) || A <- [stdlib, kernel]]),
    Rows = lists:filtermap(fun scan/1, Files),
    io:format("OTP ~s, stdlib+kernel, ~p modules with abstract code~n", [erlang:system_info(otp_release), length(Rows)]),
    report("exported", lists:append([E || {E, _} <- Rows])),
    report("LOCAL   ", lists:append([L || {_, L} <- Rows])),
    halt().

scan(File) ->
    case beam_lib:chunks(File, [abstract_code, exports]) of
        {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}, {exports, Exports}]}} ->
            Fs = [{N, A, C} || {function, _, N, A, C} <- Forms, N =/= module_info, hd(atom_to_list(N)) =/= $-],
            {true, {[F || {N, A, _} = F <- Fs, lists:member({N, A}, Exports)],
                    [F || {N, A, _} = F <- Fs, not lists:member({N, A}, Exports)]}};
        _ -> false
    end.

report(Label, Funs) ->
    Pos = [pos_defended(I, C) || {_, A, C} <- Funs, I <- lists:seq(1, A)],
    Typed = [pos_type_guarded(I, C) || {_, A, C} <- Funs, I <- lists:seq(1, A)],
    N = length(Pos),
    io:format("~s: ~p functions, ~p parameter positions; defended (pattern or guard mention) ~p (~.1f%); "
              "named in a type-test guard (is_integer/is_atom/...) in every clause ~p (~.1f%)~n",
              [Label, length(Funs), N, count(Pos), 100 * count(Pos) / N, count(Typed), 100 * count(Typed) / N]).

count(L) -> length([x || true <- L]).

pos_defended(I, Clauses) ->
    lists:all(fun({clause, _, Ps, Gs, _}) ->
                  P = lists:nth(I, Ps),
                  (not is_var(P)) orelse (var_name(P) =/= '_' andalso lists:any(fun(G) -> mentions(var_name(P), G) end, Gs))
              end, Clauses).

pos_type_guarded(I, Clauses) ->
    lists:all(fun({clause, _, Ps, Gs, _}) ->
                  P = lists:nth(I, Ps),
                  (not is_var(P)) orelse (var_name(P) =/= '_' andalso lists:any(fun(G) -> type_test(var_name(P), G) end, Gs))
              end, Clauses).

is_var({var, _, _}) -> true;
is_var(_) -> false.
var_name({var, _, N}) -> N.

mentions(N, {var, _, N}) -> true;
mentions(N, T) when is_tuple(T) -> lists:any(fun(E) -> mentions(N, E) end, tuple_to_list(T));
mentions(N, L) when is_list(L) -> lists:any(fun(E) -> mentions(N, E) end, L);
mentions(_, _) -> false.

type_test(N, {call, _, {atom, _, F}, [{var, _, N}]}) ->
    lists:member(F, [is_integer, is_atom, is_binary, is_list, is_tuple, is_map, is_float, is_number, is_pid, is_function, is_boolean]);
type_test(N, T) when is_tuple(T) -> lists:any(fun(E) -> type_test(N, E) end, tuple_to_list(T));
type_test(N, L) when is_list(L) -> lists:any(fun(E) -> type_test(N, E) end, L);
type_test(_, _) -> false.
