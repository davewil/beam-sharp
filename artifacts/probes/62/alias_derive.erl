-module(alias_derive).
-export([main/1, corpus/1]).

main([Dir]) ->
    {ok, F} = file:consult(filename:join(Dir, "Names.abstr")),
    [{attribute,_,export,Ex}|_] = [X || X = {attribute,_,export,_} <- F],
    Author = [E || {N,_} = E <- Ex, N =/= 'bs@type_atoms'],
    io:format("== (a) exports of the real B# module `Names` (compiled by bsc): ~p~n", [Author]),
    io:format("~n== (b) derived alias under each rule~n"),
    [io:format("   ~-10s simple=~-18s smart=~s~n", [N, alias_xform:derive(simple, N), alias_xform:derive(smart, N)]) || {N,_} <- lists:usort(Author)],
    io:format("~n== (c) collisions (two B# names, one alias) on that module: ~p~n", [alias_xform:collisions(F)]),
    io:format("~n== (d) does OTP accept the aliased module?~n"),
    {ok, _, _} = compile:forms(F, [debug_info, binary, return_errors]),
    io:format("   CONTROL baseline compiles: ok~n"),
    lists:foreach(fun(Rule) ->
        R = compile:forms(alias_xform:xform(Rule, wrapper, F), [debug_info, binary, return_errors, report_warnings]),
        io:format("   rule=~p -> ~P~n", [Rule, short(R), 30])
    end, [simple, smart]),
    io:format("~n== (e) exhaustive injectivity: every identifier [A-Z][A,B,a,b,1,_]{0,4} (what the lexer admits, restricted alphabet)~n"),
    Alpha = "ABab1_",
    All = [[H|T] || H <- "AB", K <- lists:seq(0, 4), T <- strs(Alpha, K)],
    io:format("   ~p identifiers~n", [length(All)]),
    lists:foreach(fun(Rule) ->
        M = lists:foldl(fun(Id, Acc) -> maps:update_with(alias_xform:derive(Rule, list_to_atom(Id)), fun(L) -> [Id|L] end, [Id], Acc) end, #{}, All),
        Colliding = [V || {_, V} <- maps:to_list(M), length(V) > 1],
        Lost = lists:sum([length(V) - 1 || V <- Colliding]),
        io:format("   rule=~-6s distinct aliases ~p, colliding groups ~p, names with no unique alias ~p; example ~p~n",
                  [Rule, maps:size(M), length(Colliding), Lost, lists:sublist(lists:sort(Colliding), 2)])
    end, [simple, smart]),
    NoUnderscore = [Id || Id <- All, not lists:member($_, Id)],
    lists:foreach(fun(Rule) ->
        M = lists:foldl(fun(Id, Acc) -> maps:update_with(alias_xform:derive(Rule, list_to_atom(Id)), fun(L) -> [Id|L] end, [Id], Acc) end, #{}, NoUnderscore),
        io:format("   restricted to names WITHOUT '_': rule=~-6s colliding groups ~p of ~p names~n", [Rule, length([V || {_, V} <- maps:to_list(M), length(V) > 1]), length(NoUnderscore)])
    end, [simple, smart]),
    %% (f) BIF / reserved collisions
    io:format("~n== (f) derived names that are Erlang auto-imported BIFs / keywords~n"),
    {ok, ExF} = file:consult(filename:join(Dir, "Names.abstr")), _ = ExF,
    BIFs = [{N, A} || {N, A} <- Author, erl_internal:bif(alias_xform:derive(simple, N), A)],
    io:format("   from `Names`: alias is an auto-imported BIF: ~p~n", [BIFs]),
    Kw = ['after','and','andalso','band','begin','bnot','bor','bsl','bsr','bxor','case','catch','cond','div','end','fun','if','let','not','of','or','orelse','receive','rem','try','when','xor','maybe','else'],
    io:format("   Erlang keywords a PascalCase B# name derives to (single-word): ~p~n", [[K || K <- Kw, alias_xform:derive(simple, list_to_atom([hd(string:uppercase(atom_to_list(K))) | tl(atom_to_list(K))])) =:= K]]),
    ok.

strs(_, 0) -> [[]];
strs(A, N) -> [[C|T] || C <- A, T <- strs(A, N-1)].

short({ok, M, _}) -> {ok, M};
short({error, Errs, Warns}) -> {error, Errs, Warns};
short(O) -> O.

%% (g) the 27 real example modules: any collision under either rule?
corpus(Dir) ->
    Fs = lists:sort(filelib:wildcard(filename:join(Dir, "*.abstr"))),
    R = [{filename:basename(P, ".abstr"), alias_xform:collisions(element(2, file:consult(P)))} || P <- Fs],
    Bad = [X || {_, C} = X <- R, C =/= []],
    io:format("== (g) collisions over the ~p real example modules, both rules: ~p~n", [length(Fs), Bad]),
    %% names whose alias would be an auto-imported BIF or module_info/0,1 in real modules
    Names = lists:usort(lists:append([[{N, A} || {attribute,_,export,Ex} <- element(2, file:consult(P)), {N, A} <- Ex, N =/= 'bs@type_atoms', hd(atom_to_list(N)) < $a] || P <- Fs])),
    Hits = [{N, A, alias_xform:derive(simple, N)} || {N, A} <- Names,
            erl_internal:bif(alias_xform:derive(simple, N), A) orelse lists:member(alias_xform:derive(simple, N), [module_info])],
    io:format("   alias would be a BIF/module_info among the real names: ~p~n", [Hits]).
