#!/usr/bin/env escript
%% PREDICTION (written before running; OTP 25 stdlib-4.3.1.3 / compiler-8.2.6.3):
%%  E1 erl_parse yields {op,_,'-',{integer,_,5}} for -5 in BOTH a guard comparand and a
%%     pattern (erl_parse.yrl:240 expr and :270 pat_expr are the same shape). erl_parse does not fold.
%%  E2 The fold happens later and in different places: pattern position at v3_core:pattern/2 via
%%     erl_eval:partial_eval (general: 2+3 folds too); guard/expression position in sys_core_fold
%%     (so `to_core` output for a guard shows a literal -5 or a call to erlang:'-'... to be seen).
%%  E3 Folded (hand-built {integer,L,-5}) and unfolded ({op,'-',{integer,5}}) forms give an identical
%%     "Code" chunk after compile (beam byte-identical modulo compile-info chunk), for guard and pattern.
%%  E4 erl_parse:normalise({op,-,{integer,5}}) = -5 (erl_parse.yrl:1441); i.e. the parser ships its own
%%     fold for attribute/constant terms.
main(_) ->
    F = fun(Src) -> {ok, Ts, _} = erl_scan:string(Src), {ok, Fm} = erl_parse:parse_form(Ts), Fm end,
    Guard = F("f(X) when X >= -5 -> ok; f(_) -> no."),
    Pat   = F("g(-5) -> ok; g(_) -> no."),
    Sum   = F("h(X) when X >= 2 + 3 -> ok; h(_) -> no."),
    PatSum= F("k(2 + 3) -> ok; k(_) -> no."),
    io:format("E1 guard  clause: ~p~n", [first_clause(Guard)]),
    io:format("E1 pattern clause: ~p~n", [first_clause(Pat)]),
    io:format("E1 normalise({op,-,5}) = ~p~n", [erl_parse:normalise({op,1,'-',{integer,1,5}})]),
    io:format("E2 erl_eval:partial_eval(-5)  = ~p~n", [erl_eval:partial_eval({op,1,'-',{integer,1,5}})]),
    io:format("E2 erl_eval:partial_eval(2+3) = ~p~n", [erl_eval:partial_eval({op,1,'+',{integer,1,2},{integer,1,3}})]),
    io:format("E2 erl_lint:is_pattern_expr(-5)=~p (2+3)=~p (X+1)=~p~n",
       [erl_lint:is_pattern_expr({op,1,'-',{integer,1,5}}),
        erl_lint:is_pattern_expr({op,1,'+',{integer,1,2},{integer,1,3}}),
        erl_lint:is_pattern_expr({op,1,'+',{var,1,'X'},{integer,1,3}})]),
    Mod = {attribute,1,module,m},
    Exp = {attribute,1,export,[{f,1},{g,1},{h,1},{k,1}]},
    All = [Mod, Exp, Guard, Pat, Sum, PatSum, {eof,9}],
    %% compile.erl:814 `to_core0` stops after v3_core; :832 sys_core_fold runs before `to_core` (:842).
    %% PREDICTION E2': to_core0 shows the guard's -5 as a call to erlang:'-'(5) (unfolded) and the
    %% pattern's -5 as a literal (v3_core:pattern -> erl_eval:partial_eval); to_core shows both folded.
    {ok, m, Core0} = compile:forms(All, [to_core0, binary]),
    {ok, m, Core1} = compile:forms(All, [to_core, binary]),
    io:format("E2 to_core0 (after v3_core only), f/1 g/1 h/1 k/1:~n~s~n", [only(Core0)]),
    io:format("E2 to_core (after sys_core_fold), f/1 g/1 h/1 k/1:~n~s~n", [only(Core1)]),
    {ok, m, Asm} = compile:forms(All, ['S', binary]),
    io:format("E2b optimised assembly f/1 (guard, -5):~n~p~n", [fn_asm(Asm, f)]),
    io:format("E2b optimised assembly h/1 (guard, 2+3):~n~p~n", [fn_asm(Asm, h)]),
    io:format("E2b optimised assembly g/1 (pattern -5):~n~p~n", [fn_asm(Asm, g)]),
    io:format("E2b optimised assembly k/1 (pattern 2+3):~n~p~n", [fn_asm(Asm, k)]),
    %% E3: identical code from folded vs unfolded abstract form
    G2 = fold_neg(Guard), P2 = fold_neg(Pat),
    ExpFG = {attribute,1,export,[{f,1},{g,1}]},
    Opts = [binary, no_line_info],
    {ok, m, B1} = compile:forms([Mod,ExpFG,Guard,Pat,{eof,9}], Opts),
    {ok, m, B2} = compile:forms([Mod,ExpFG,G2,P2,{eof,9}], Opts),
    io:format("E3 folded form really differs at abstract level: ~p~n", [Guard =/= G2 andalso Pat =/= P2]),
    io:format("E3 Code chunk equal: ~p ; whole beam binary equal: ~p~n", [chunk(B1,"Code") =:= chunk(B2,"Code"), B1 =:= B2]),
    io:format("E3 size unfolded ~p bytes, folded ~p bytes~n", [byte_size(B1), byte_size(B2)]),
    ok.

first_clause({function,_,_,_,[C|_]}) -> C.
fn_asm({_M,_E,_A,Fs,_L}, Name) -> [strip(F) || {function,N,_,_,_}=F <- Fs, N =:= Name].
strip({function,N,A,E,Is}) -> {function,N,A,E,[I || I <- Is, element(1,I) =/= line]}.
chunk(Bin, Name) -> {ok,_,Cs} = beam_lib:all_chunks(Bin), proplists:get_value(Name, Cs).
fold_neg(T) when is_tuple(T) ->
    case T of
        {op,L,'-',{integer,_,N}} -> {integer,L,-N};
        _ -> list_to_tuple([fold_neg(X) || X <- tuple_to_list(T)])
    end;
fold_neg(L) when is_list(L) -> [fold_neg(X) || X <- L];
fold_neg(X) -> X.
only(Core) ->
    Txt = lists:flatten(core_pp:format(Core)),
    Lines = string:split(Txt, "\n", all),
    Keep = [L || L <- Lines, string:find(L, "erlang':") =/= nomatch orelse
                  string:find(L, "<-5>") =/= nomatch orelse string:find(L, "<5>") =/= nomatch orelse
                  string:find(L, "<X>") =/= nomatch orelse
                  (string:find(L, "'f'/1 =") =/= nomatch) orelse (string:find(L, "'g'/1 =") =/= nomatch) orelse
                  (string:find(L, "'h'/1 =") =/= nomatch) orelse (string:find(L, "'k'/1 =") =/= nomatch) orelse
                  (string:find(L, ") ->") =/= nomatch andalso string:find(L, "-5") =/= nomatch) orelse
                  string:find(L, " 5) ->") =/= nomatch orelse string:find(L, " -5) ->") =/= nomatch],
    string:join([L || L <- Keep, string:find(L, "get_module_info") =:= nomatch], "\n").
