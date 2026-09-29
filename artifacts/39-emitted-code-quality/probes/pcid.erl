%%% pcid.erl -- added after verification. Asserts pc_a.S and pc_b.S (typed / +no_type_opt) are identical after
%%% erasing {tr,R,_} -> R and dropping label/line/func_info/'%'; asserts the streams are non-empty (non-vacuous).
-module(pcid).
-export([main/0]).
main() ->
    A = s("build/pc_a.S"), B = s("build/pc_b.S"),
    true = length(A) > 10,
    Tr = fun(F) -> {ok, Bin} = file:read_file(F), length(binary:matches(Bin, <<"{tr,">>)) end,
    io:format("instrs typed=~p nt=~p identical_after_tr_erasure=~p~n", [length(A), length(B), A =:= B]),
    io:format("{tr,..} operands typed=~p nt=~p~n", [Tr("build/pc_a.S"), Tr("build/pc_b.S")]),
    [io:format("  only typed: ~p~n", [I]) || I <- A -- B],
    [io:format("  only nt:    ~p~n", [I]) || I <- B -- A],
    halt().
s(F) ->
    {ok, T} = file:consult(F),
    %% only function l/2's body (module_info/0,1 embed the module name atom and would differ trivially)
    [_ | After] = lists:dropwhile(fun(X) -> not (is_tuple(X) andalso element(1, X) =:= function andalso element(2, X) =:= l) end, T),
    Body = lists:takewhile(fun(X) -> not (is_tuple(X) andalso element(1, X) =:= function) end, After),
    [strip(I) || I <- Body, not (is_tuple(I) andalso lists:member(element(1, I), [label, line, func_info, '%']))].
strip({tr, R, _}) -> R;
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(X) -> X.
