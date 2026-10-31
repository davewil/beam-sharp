#!/usr/bin/env escript
%% Probe 3: derivation-rule census over the real B# corpus.
%% Run: escript p3_derivation_census.escript /home/user/beam-sharp/compiler
%% Extracts `public ... Name(` declarations by regex (bsc cannot run here, so
%% this is a textual census, not a parse). Applies three alias rules and counts
%% collisions per module, and against names the BEAM reserves.
%% Exit 1 if: the corpus yields too few names (vacuous), a planted-collision
%% control is NOT detected, or the recommended rule collides on the corpus.
main([Root]) ->
    Files = filelib:fold_files(Root, "\\.bs$", true,
              fun(F, A) -> case string:find(F, "_build") of nomatch -> [F|A]; _ -> A end end, []),
    %% F15: a module is a directory, so collisions are checked per directory.
    ByDir = lists:foldl(fun(F, M) -> maps:update_with(filename:dirname(F), fun(L) -> names(F) ++ L end, names(F), M) end, #{}, Files),
    PerModule = [{D, lists:usort(N)} || {D, N} <- maps:to_list(ByDir)],
    io:format("module directories: ~p~n", [length(PerModule)]),
    All = lists:usort(lists:append([N || {_, N} <- PerModule])),
    io:format("bs files: ~p   distinct public names: ~p~n", [length(Files), length(All)]),
    Rules = [{naive_underscore_before_every_upper, fun(X) -> r_naive(X) end},
             {acronym_aware_snake, fun(X) -> r_acronym(X) end},
             {lower_first_only, fun(X) -> r_lowerfirst(X) end}],
    Reserved = ["module_info", "behaviour_info"],
    Res = [begin
        Colls = lists:append([collisions(R, N, F) || {F, N} <- PerModule]),
        Rsv   = [{X, R(X)} || X <- All, lists:member(R(X), Reserved)],
        io:format("~n== rule ~p~n   corpus collisions: ~p~n   reserved-name hits: ~p~n",
                  [Name, Colls, Rsv]),
        io:format("   samples: ~p~n", [[{X, R(X)} || X <- ["New","GetId","GetID","HTTPGet","ParseURL","Pay","ToJson","V2Parse","Get_Id"]]]),
        {Name, Colls, Rsv}
    end || {Name, R} <- Rules],
    %% controls: the detector must see a planted collision, and a planted reserved name
    PlantC = collisions(fun(X) -> r_acronym(X) end, ["GetID","GetId","Other"], planted),
    PlantR = [X || X <- ["ModuleInfo","Foo"], lists:member(r_acronym(X), Reserved)],
    io:format("~ncontrol planted GetID/GetId under acronym rule: ~p~n", [PlantC]),
    io:format("control planted ModuleInfo reserved hit: ~p~n", [PlantR]),
    Pairs = [{R, R2} || R <- ["GetID","GetId"], R2 <- [r_naive(R)]],
    io:format("naive rule GetID/GetId -> ~p (distinct, but ugly)~n", [Pairs]),
    Ok = [length(All) >= 30, PlantC =/= [], PlantR =/= [],
          element(2, lists:keyfind(acronym_aware_snake, 1, Res)) =:= []],
    io:format("~nassertions (non-vacuous, controls fire, recommended rule clean on corpus): ~p~n", [Ok]),
    halt(case lists:all(fun(X) -> X end, Ok) of true -> 0; false -> 1 end).

names(F) ->
    {ok, B} = file:read_file(F),
    case re:run(B, "^\\s*public\\s+[^()=\\n]*?\\b([A-Z][A-Za-z0-9_]*)\\s*(?:<[^>]*>)?\\(", [multiline, global, {capture, [1], list}]) of
        {match, Ms} -> lists:usort([N || [N] <- Ms]);
        nomatch -> []
    end.

collisions(R, Names, Where) ->
    Groups = lists:foldl(fun(N, M) -> maps:update_with(R(N), fun(L) -> [N|L] end, [N], M) end, #{}, Names),
    [{Where, Snake, lists:sort(Ns)} || {Snake, Ns} <- maps:to_list(Groups), length(Ns) > 1].

r_lowerfirst([C|T]) -> [string:to_lower(C)|T].
r_naive([C|T]) -> string:to_lower([C]) ++ lists:append([ if U -> [$_, string:to_lower(X)]; true -> [X] end
                       || X <- T, U <- [X >= $A andalso X =< $Z]]).
r_acronym(S) -> %% heck/serde-style: boundary lower|digit->Upper, and Upper->Upper+lower
    r_acr(S, [], none).
r_acr([], Acc, _) -> lists:reverse(Acc);
r_acr([C|T], Acc, Prev) ->
    Up = C >= $A andalso C =< $Z,
    Next = case T of [N|_] -> N; [] -> $\s end,
    NextLower = Next >= $a andalso Next =< $z,
    PrevLowerOrDigit = Prev =/= none andalso ((Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9)),
    PrevUp = Prev =/= none andalso (Prev >= $A andalso Prev =< $Z),
    Boundary = Up andalso (PrevLowerOrDigit orelse (PrevUp andalso NextLower)),
    L = string:to_lower(C),
    Acc1 = case Boundary of true -> [L, $_ | Acc]; false -> [L | Acc] end,
    r_acr(T, Acc1, C).
