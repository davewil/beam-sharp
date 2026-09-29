#!/usr/bin/env escript
%% PROBE 6 — the PascalCase -> snake_case derivation rule, and how often it collides.
%% argv: REPO_ROOT  GLEAM_SRC(.gleam)  GLEAM_EMITTED(.erl)
%%
%% R1 = "Gleam's rule" as inferred from probe 4: every uppercase letter is lowercased, and an
%%      underscore is inserted before it unless it is the first character.
%% R2 = acronym-aware: an underscore before an uppercase letter only if the previous char is a
%%      lowercase letter or digit, or the previous is uppercase and the NEXT is lowercase.
%%
%% EXPECTED (before run):
%%   R1-check  R1 applied to the 9 constructors of gleam_names/src/gnames.gleam reproduces the
%%             atoms in the .erl gleam actually emitted, 9/9 (that .erl is read from disk, not
%%             hand-copied: the check is against the real compiler).
%%   R2-check  R2 differs from R1 on HTTPGet (http_get vs h_t_t_p_get) and agrees on GetX, Parse2Ints.
%%   COLL-syn  synthetic: R1 collides {GetX, Get_x} (both get_x) and not {HTTPGet, HttpGet};
%%             R2 collides {HTTPGet, HttpGet} and also {GetX, Get_x}.
%%   COLL-real over every `public` function in the repo's own .bs corpus, grouped by module
%%             directory: 0 collisions under R1 and 0 under R2 (small, disciplined corpus).
%%   ACR-real  the corpus contains >= 1 public name with two consecutive capitals.
main([Root, GSrc, GErl]) ->
    %% --- R1 vs the real Gleam output
    {ok, S} = file:read_file(GSrc),
    {match, [Body]} = re:run(S, "pub type T \\{(.*?)\\n\\}", [dotall, {capture, all_but_first, list}]),
    Ctors = [C || {match, [C]} <- [re:run(L, "^\\s*([A-Z][A-Za-z0-9]*)", [{capture, all_but_first, list}]) || L <- string:split(Body, "\n", all)]],
    {ok, E} = file:read_file(GErl),
    {match, [TDecl]} = re:run(E, "-type t\\(\\) :: (.*?)\\.\\n", [dotall, {capture, all_but_first, list}]),
    Atoms = [A || [A] <- element(2, re:run(TDecl ++ " ", "\\{?([a-z][a-z0-9_]*)[,} |]", [global, {capture, all_but_first, list}]))],
    Pairs = lists:zip([r1(C) || C <- Ctors], Atoms -- []) ,
    io:format("gleam constructors -> emitted atom vs R1:~n"),
    [io:format("    ~-12s gleam=~-14s R1=~-14s R2=~s~n", [C, A, r1(C), r2(C)]) || {C, A} <- lists:zip(Ctors, Atoms)],
    R1ok = length(Ctors) =:= 9 andalso length(Atoms) =:= 9 andalso lists:all(fun({R, A}) -> R =:= A end, Pairs),
    R2diff = r2("HTTPGet") =:= "http_get" andalso r1("HTTPGet") =:= "h_t_t_p_get"
             andalso r2("GetX") =:= r1("GetX") andalso r2("Parse2Ints") =:= r1("Parse2Ints"),
    Syn1 = coll(r1fun(), ["GetX", "Get_x", "HTTPGet", "HttpGet"]),
    Syn2 = coll(r2fun(), ["GetX", "Get_x", "HTTPGet", "HttpGet"]),
    io:format("synthetic collisions R1: ~p~n                     R2: ~p~n", [Syn1, Syn2]),
    Syn = Syn1 =:= [{"get_x", ["GetX", "Get_x"]}] andalso
          lists:sort(Syn2) =:= [{"get_x", ["GetX", "Get_x"]}, {"http_get", ["HTTPGet", "HttpGet"]}],
    %% --- the real corpus
    Files = filelib:fold_files(Root, "\\.bs$", true,
              fun(F, Acc) -> case string:find(F, "/artifacts/") of nomatch -> [F | Acc]; _ -> Acc end end, []),
    Fns = lists:append([pubfns(F) || F <- Files]),
    ByMod = lists:foldl(fun({M, N}, D) -> maps:update_with(M, fun(L) -> [N | L] end, [N], D) end, #{}, Fns),
    C1 = lists:append([coll(r1fun(), lists:usort(Ns)) || Ns <- maps:values(ByMod)]),
    C2 = lists:append([coll(r2fun(), lists:usort(Ns)) || Ns <- maps:values(ByMod)]),
    Names = lists:usort([N || {_, N} <- Fns]),
    Acr = [N || N <- Names, re:run(N, "[A-Z][A-Z]") =/= nomatch],
    io:format("corpus: ~p .bs files, ~p modules, ~p public functions (~p distinct names)~n"
              "        collisions R1=~p R2=~p ; names with 2+ consecutive capitals: ~p ~p~n",
              [length(Files), maps:size(ByMod), length(Fns), length(Names), length(C1), length(C2), length(Acr), lists:sublist(Acr, 8)]),
    Chk = [{"R1-check", R1ok}, {"R2-check", R2diff}, {"COLL-syn", Syn},
           {"COLL-real", C1 =:= [] andalso C2 =:= []}, {"ACR-real", Acr =/= []}],
    [io:format("~s ~s~n", [K, case V of true -> "PASS"; false -> "FAIL" end]) || {K, V} <- Chk],
    io:format("~s p6~n", [case lists:all(fun({_, V}) -> V end, Chk) of true -> "PASS"; false -> "FAIL" end]).

r1fun() -> fun(N) -> r1(N) end.
r2fun() -> fun(N) -> r2(N) end.
coll(F, Names) ->
    M = lists:foldl(fun(N, D) -> maps:update_with(F(N), fun(L) -> [N | L] end, [N], D) end, #{}, Names),
    [{K, lists:sort(V)} || {K, V} <- maps:to_list(M), length(V) > 1].

r1(Name) -> r1(Name, true).
r1([], _) -> [];
r1([C | T], First) when C >= $A, C =< $Z -> (if First -> []; true -> "_" end) ++ [C + 32 | r1(T, false)];
r1([C | T], _) -> [C | r1(T, false)].

r2(Name) -> r2(Name, undefined).
r2([], _) -> [];
r2([C | T], Prev) when C >= $A, C =< $Z ->
    Next = case T of [N | _] -> N; [] -> $A end,
    Split = Prev =/= undefined andalso
            (is_lower(Prev) orelse is_digit(Prev) orelse (is_upper(Prev) andalso is_lower(Next))),
    (if Split -> "_"; true -> [] end) ++ [C + 32 | r2(T, C)];
r2([C | T], _) -> [C | r2(T, C)].
is_lower(C) -> C >= $a andalso C =< $z.
is_upper(C) -> C >= $A andalso C =< $Z.
is_digit(C) -> C >= $0 andalso C =< $9.

pubfns(F) ->
    {ok, B} = file:read_file(F),
    Mod = filename:dirname(F),
    [{Mod, N} || L <- string:split(binary_to_list(B), "\n", all),
                 string:prefix(L, "public ") =/= nomatch,
                 {match, [N]} <- [re:run(L, "\\s([A-Z][A-Za-z0-9_]*)\\(", [{capture, all_but_first, list}])]].
