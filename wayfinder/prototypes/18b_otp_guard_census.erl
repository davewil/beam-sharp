%%% PROTOTYPE 18b — do OTP's own exported functions defend their parameters?
%%%
%%% Ticket 18 §1. The census that killed the "we would merely automate an idiom
%%% the ecosystem already writes by hand" argument. Provenance: local, OTP 28.
%%%
%%% Reproduce:
%%%   erlc -o /tmp 18b_otp_guard_census.erl
%%%   erl -pa /tmp -noshell -s '18b_otp_guard_census' main -s init stop
%%%
%%% Recorded result (OTP 28, stdlib + kernel, 199 modules):
%%%   exported functions            : 4193
%%%     every parameter defended    :  512 (12.2%)
%%%   exported parameter positions  : 7606
%%%     bare variable, no guard     : 6333 (83.3%)
%%%
%%% Run:  erlc -o /tmp otp_guard_census.erl && erl -pa /tmp -noshell -s otp_guard_census main -s init stop
-module('18b_otp_guard_census').
-export([main/0]).

apps() -> ["stdlib", "kernel"].

main() ->
    Files = lists:append([beams(A) || A <- apps()]),
    Rows = lists:filtermap(fun scan/1, Files),
    {Mods, Funs, FullyDef, PartDef, Params, DefParams, NoDebug} =
        lists:foldl(fun({F, FD, PD, P, DP}, {M, AF, AFD, APD, AP, ADP, ND}) ->
                        {M + 1, AF + F, AFD + FD, APD + PD, AP + P, ADP + DP, ND}
                    end, {0,0,0,0,0,0,0}, Rows),
    io:format("OTP ~s -- apps: ~p~n", [erlang:system_info(otp_release), apps()]),
    io:format("modules with debug_info scanned : ~p (skipped, no abstract code: ~p)~n",
              [Mods, length(Files) - length(Rows) + NoDebug]),
    io:format("exported functions              : ~p~n", [Funs]),
    io:format("  every parameter defended      : ~p (~.1f%)~n", [FullyDef, pct(FullyDef, Funs)]),
    io:format("  at least one param defended   : ~p (~.1f%)~n", [PartDef, pct(PartDef, Funs)]),
    io:format("exported parameter positions    : ~p~n", [Params]),
    io:format("  defended (matched or guarded) : ~p (~.1f%)~n", [DefParams, pct(DefParams, Params)]),
    io:format("  bare variable, no guard       : ~p (~.1f%)~n",
              [Params - DefParams, pct(Params - DefParams, Params)]),
    ok.

pct(_, 0) -> 0.0;
pct(A, B) -> 100.0 * A / B.

beams(App) ->
    case code:lib_dir(list_to_atom(App)) of
        {error, _} -> [];
        Dir -> filelib:wildcard(filename:join([Dir, "ebin", "*.beam"]))
    end.

scan(File) ->
    case beam_lib:chunks(File, [abstract_code, exports]) of
        {ok, {_M, [{abstract_code, {raw_abstract_v1, Forms}}, {exports, Exports}]}} ->
            Fs = [{N, A, Clauses} || {function, _, N, A, Clauses} <- Forms],
            Exported = [F || {N, A, _} = F <- Fs, lists:member({N, A}, Exports)],
            {true, tally(Exported)};
        _ ->
            false
    end.

tally(Funs) ->
    lists:foldl(fun({_N, A, Clauses}, {F, FD, PD, P, DP}) ->
        Defended = [pos_defended(I, Clauses) || I <- lists:seq(1, A)],
        NDef = length([x || true <- Defended]),
        {F + 1,
         FD + case A > 0 andalso NDef =:= A of true -> 1; false -> 0 end,
         PD + case NDef > 0 of true -> 1; false -> 0 end,
         P + A,
         DP + NDef}
    end, {0,0,0,0,0}, Funs).

%% defended at position I only if EVERY clause defends it
pos_defended(I, Clauses) ->
    lists:all(fun({clause, _, Patterns, Guards, _Body}) ->
                  Pat = lists:nth(I, Patterns),
                  pattern_tests(Pat) orelse guard_mentions(Pat, Guards)
              end, Clauses).

%% a pattern that is not a bare variable or _ constrains the term
pattern_tests({var, _, '_'}) -> false;
pattern_tests({var, _, _})   -> false;
pattern_tests(_)             -> true.

%% does any guard test mention the variable bound at this position?
guard_mentions({var, _, '_'}, _) -> false;
guard_mentions({var, _, Name}, Guards) -> lists:any(fun(G) -> mentions(Name, G) end, Guards);
guard_mentions(_, _) -> false.

mentions(Name, Term) when is_tuple(Term) ->
    case Term of
        {var, _, Name} -> true;
        _ -> lists:any(fun(E) -> mentions(Name, E) end, tuple_to_list(Term))
    end;
mentions(Name, L) when is_list(L) -> lists:any(fun(E) -> mentions(Name, E) end, L);
mentions(_, _) -> false.
