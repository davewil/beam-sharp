-module(alias_measure).
-export([main/1]).

main([Dir]) ->
    Abstrs = lists:sort(filelib:wildcard(filename:join(Dir, "*.abstr"))),
    Mods = [{filename:basename(P, ".abstr"), read(P), P} || P <- Abstrs],
    io:format("modules: ~p~n", [length(Mods)]),
    %% CONTROL: rebuilding the baseline from .abstr reproduces bsc's own .beam byte-for-byte
    %% (else every size below is measured on a different artifact than bsc ships).
    Same = [N || {N, _F, P} <- Mods, begin {ok,_,B} = compile:file(P, [from_abstr, debug_info, binary]), {ok, Orig} = file:read_file(filename:rootname(P)++".beam"), B =:= Orig end],
    io:format("CONTROL baseline rebuild == bsc .beam byte-identical: ~p of ~p~n", [length(Same), length(Mods)]),
    lists:foreach(fun(Rule) -> lists:foreach(fun(Mode) -> report(Rule, Mode, Mods) end, [wrapper, spec]) end, [simple]),
    report(smart, wrapper, Mods),
    load_time(Mods),
    compile_time(Mods),
    erlang:halt(0).

read(P) -> {ok, F} = file:consult(P), F.
comp(Forms) -> {ok, M, B} = compile:forms(Forms, [debug_info, binary, return_errors]), {ok, M, B}.

chunk_sizes(Bin) ->
    {ok, _, Cs} = beam_lib:all_chunks(Bin),
    maps:from_list([{list_to_atom(Id), byte_size(D)} || {Id, D} <- Cs]).

nexp(Bin) -> {ok, {_, [{exports, E}]}} = beam_lib:chunks(Bin, [exports]), length(E).

report(Rule, Mode, Mods) ->
    Rows = [begin
                {ok,_,B0} = comp(F),
                {ok,_,B1} = comp(alias_xform:xform(Rule, Mode, F)),
                {N, byte_size(B0), byte_size(B1), nexp(B0), nexp(B1), chunk_sizes(B0), chunk_sizes(B1)}
            end || {N, F, _} <- Mods],
    T0 = lists:sum([A || {_,A,_,_,_,_,_} <- Rows]),
    T1 = lists:sum([B || {_,_,B,_,_,_,_} <- Rows]),
    E0 = lists:sum([A || {_,_,_,A,_,_,_} <- Rows]),
    E1 = lists:sum([B || {_,_,_,_,B,_,_} <- Rows]),
    io:format("~n== rule=~p mode=~p over ~p modules (all compiler/examples)~n", [Rule, Mode, length(Rows)]),
    io:format("beam bytes: ~p -> ~p  (+~p, +~.1f%)~n", [T0, T1, T1-T0, (T1-T0)*100/T0]),
    io:format("export-table entries (incl module_info x2, bs@type_atoms): ~p -> ~p~n", [E0, E1]),
    Keys = ['Code','ExpT','AtU8','LocT','FunT','ImpT','Dbgi','Attr','CInf','StrT','LitT','Line','Type'],
    lists:foreach(fun(K) ->
        S0 = lists:sum([maps:get(K, C0, 0) || {_,_,_,_,_,C0,_} <- Rows]),
        S1 = lists:sum([maps:get(K, C1, 0) || {_,_,_,_,_,_,C1} <- Rows]),
        io:format("  chunk ~-5s ~7p -> ~7p  (~+p)~n", [K, S0, S1, S1-S0])
    end, Keys),
    %% biggest single module (Shop)
    {_, A, B, EA, EB, _, _} = lists:keyfind("Shop", 1, Rows),
    io:format("  Shop alone: beam ~p -> ~p bytes (+~p), exports ~p -> ~p~n", [A, B, B-A, EA, EB]).

load_time(Mods) ->
    N = 400,
    Bins = fun(Rule, Mode) -> [{list_to_atom(Nm), begin {ok,_,B} = comp(case Mode of base -> F; _ -> alias_xform:xform(Rule, Mode, F) end), B end} || {Nm, F, _} <- Mods] end,
    Sets = [{baseline, Bins(simple, base)}, {alias_wrapper, Bins(simple, wrapper)}, {alias_wrapper_spec, Bins(simple, spec)}],
    io:format("~n== module load time: code:load_binary over all ~p modules, ~p rounds per repetition x 5 repetitions; median of rounds, best repetition kept (microseconds)~n", [length(Mods), N div 5]),
    %% interleave to cancel drift: run each set 5 times and keep the best median
    Res = [{Name, lists:min([round_med(Set, N div 5) || _ <- lists:seq(1,5)])} || {Name, Set} <- Sets],
    [io:format("  ~-20s median ~p us per full set~n", [Nm, M]) || {Nm, M} <- Res].

round_med(Set, N) ->
    Ts = [begin
              [begin code:purge(M), code:delete(M), code:purge(M) end || {M,_} <- Set],
              {T, _} = timer:tc(fun() -> [{module,_} = code:load_binary(M, atom_to_list(M) ++ ".beam", B) || {M,B} <- Set] end),
              T
          end || _ <- lists:seq(1, N)],
    lists:nth(length(Ts) div 2 + 1, lists:sort(Ts)).

compile_time(Mods) ->
    N = 15,
    T = fun(Mode) ->
            Ts = [begin {X,_} = timer:tc(fun() -> [comp(case Mode of base -> F; _ -> alias_xform:xform(simple, Mode, F) end) || {_, F, _} <- Mods] end), X end || _ <- lists:seq(1, N)],
            S = lists:sort(Ts), {hd(S), lists:nth(N div 2 + 1, S)}
        end,
    {B0, M0} = T(base), {B1, M1} = T(wrapper),
    io:format("~n== OTP compile:forms time over all ~p modules, N=~p: baseline min/median ~p/~p us ; with aliases ~p/~p us~n", [length(Mods), N, B0, M0, B1, M1]).
