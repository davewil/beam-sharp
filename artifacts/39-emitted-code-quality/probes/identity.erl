%%% identity.erl -- are the hot functions' instruction streams identical across variants once every
%%% {tr,Reg,Type} operand is replaced by plain Reg and labels/line/func_info bookkeeping is ignored?
%%% Prediction (P3,P5): all variants differ ONLY in {tr} annotations and in the extra guard instructions
%%% of the GUARD_* variants; v_exp and v_exp_spec are identical to v_base after stripping.
%%% Input: build/<mod>.S produced by erlc +to_asm (consultable terms). Compares spin/4 and wrap/1 (wrap is
%%% inlined by the compiler in some variants; then it is reported as absent and spin/4 carries the work).
-module(identity).
-export([main/0]).
main() ->
    Ms = [v_base, v_bs, v_base_nt, v_bs_nt, v_exp, v_exp_is, v_exp_rng, v_exp_spec, v_priv_rng, v_bs_rng, v_abstr, v_abstr_rng, ex_asm],
    lists:foreach(fun(F) ->
        Ref = fn(v_base, F),
        true = Ref =/= none andalso length(Ref) >= 4,   %% guard against a vacuous all-empty comparison
        io:format("~p: v_base has ~p instrs (labels/line stripped, {tr,R,_}->R)~n", [F, len(Ref)]),
        [io:format("   ~-11s present=~-5w instrs=~-4w identical_to_v_base=~w~n",
                   [M, X =/= none, len(X), X =:= Ref]) || M <- Ms, X <- [fn(M, F)]]
    end, [{spin,4}, {wrap,1}]),
    %% Where do the streams differ? (tr-stripped, so these are REAL instruction differences)
    lists:foreach(fun({A, B, F}) ->
        XA = fn(A, F), XB = fn(B, F),
        io:format("~ndiff ~p ~p vs ~p (lines only in first / only in second):~n", [F, A, B]),
        [io:format("   - ~p~n", [I]) || I <- XA -- XB],
        [io:format("   + ~p~n", [I]) || I <- XB -- XA]
    end, [{v_base, v_base_nt, {spin,4}}, {v_base, v_exp, {spin,4}}, {v_exp, v_exp_spec, {spin,4}},
          {v_exp, v_exp_is, {spin,4}}, {v_exp, v_exp_rng, {spin,4}}, {v_base, v_priv_rng, {spin,4}}, {v_base, v_abstr, {spin,4}}, {v_base, ex_asm, {spin,4}}, {v_base, ex_asm, {wrap,1}}]),
    halt().
len(none) -> 0; len(L) -> length(L).
fn(M, {N, A}) ->
    {ok, Terms} = file:consult("build/" ++ atom_to_list(M) ++ ".S"),
    %% the .S is a flat term list: {function,N,A,Entry}. then that function's instructions up to the next {function,..}
    case take(Terms, N, A) of
        none -> none;
        Code -> [strip(I) || I <- Code, not (is_tuple(I) andalso lists:member(element(1, I), [label, line, func_info, '%']))]
    end.
take([{function, N, A, _} | T], N, A) -> lists:takewhile(fun(X) -> not (is_tuple(X) andalso element(1, X) =:= function) end, T);
take([_ | T], N, A) -> take(T, N, A);
take([], _, _) -> none.
strip({tr, R, _}) -> R;
strip(T) when is_tuple(T) -> list_to_tuple([strip(E) || E <- tuple_to_list(T)]);
strip(L) when is_list(L) -> [strip(E) || E <- L];
strip(X) -> X.
