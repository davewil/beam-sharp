#!/usr/bin/env escript
%%! -pa compiler/_build/default/lib/bsc/ebin
%% PROBE 62g — blast radius of renaming, and snake_case COLLISIONS among real B# functions.
%% Uses the compiler's own lexer+parser (bs_lexer:string/1, bs_parser:parse/1), not a regex.
%% For every .bs file under the repo (excluding _build and artifacts/): count function declarations (the parser's `signature` declaration: element 3 = name, 5 = params, 6 = vis),
%% group by the file's directory (a module is a directory, F15), and for each module report, per arity:
%%   - public names whose snake_case form equals ANOTHER public name's snake_case form (a collision)
%%   - public names whose snake_case form equals the name itself (already lowercase; nothing to alias)
%% CONTROL: the synthetic module at the end MUST report a collision (GetId/GetID/Get_Id), or the detector is broken.
%% Run from repo root:  escript artifacts/probes/62/62g_blast_radius.escript
main(_) ->
    Files = [F || F <- filelib:wildcard("**/*.bs"),
                  string:find(F, "_build") =:= nomatch,
                  not lists:prefix("artifacts/", F)],
    Per = [{filename:dirname(F), parse(F)} || F <- Files],
    Bad = [F || {F, error} <- [{F, parse(F)} || F <- Files]],
    Groups = lists:foldl(fun({D, Fs}, M) -> maps:update_with(D, fun(X) -> X ++ Fs end, Fs, M) end, #{},
                         [{D, Fs} || {D, Fs} <- Per, is_list(Fs)]),
    All = lists:append([Fs || {_, Fs} <- maps:to_list(Groups)]),
    Pub = [X || {_, _, public} = X <- All],
    io:format("files parsed: ~w (~w unparsable by the current grammar: ~p)~n", [length(Files) - length(Bad), length(Bad), Bad]),
    io:format("function declarations: ~w  public: ~w  private: ~w~n", [length(All), length(Pub), length(All) - length(Pub)]),
    io:format("public names with an uppercase first letter: ~w of ~w~n",
              [length([N || {N, _, _} <- Pub, hd(atom_to_list(N)) >= $A, hd(atom_to_list(N)) =< $Z]), length(Pub)]),
    ByTop = lists:foldl(fun({D, Fs}, M) ->
                Top = case string:tokens(D, "/") of [T | _] -> T; [] -> "." end,
                maps:update_with(Top, fun(X) -> X + length(Fs) end, length(Fs), M) end, #{}, maps:to_list(Groups)),
    io:format("declarations by top-level dir: ~p~n", [lists:sort(maps:to_list(ByTop))]),
    Coll = lists:append([collisions(D, Fs) || {D, Fs} <- maps:to_list(Groups)]),
    io:format("~nREAL-CORPUS collisions (same module dir, same arity, same snake_case): ~w~n", [length(Coll)]),
    [io:format("  ~s ~p~n", [D, C]) || {D, C} <- Coll],
    Ctl = collisions("synthetic", [{'GetId', 1, public}, {'GetID', 1, public}, {'Get_Id', 1, public}, {'GetId', 2, public}]),
    io:format("CONTROL (synthetic GetId/GetID/Get_Id/1, GetId/2): ~p~n", [Ctl]),
    Ctl =/= [] orelse begin io:format("DETECTOR BROKEN~n"), halt(1) end,
    %% Names whose snake form is not obviously a stable spelling (digits, acronyms, runs of capitals)
    Odd = lists:usort([N || {N, _, public} <- All, re:run(atom_to_list(N), "[A-Z]{2}|[0-9]|_", [{capture, none}]) =:= match]),
    io:format("public names with an acronym run, digit or underscore (spelling-sensitive): ~p~n", [Odd]).

parse(F) ->
    {ok, Bin} = file:read_file(F),
    try
        {ok, Toks, _} = bs_lexer:string(binary_to_list(Bin)),
        {ok, Decls} = bs_parser:parse(Toks),
        [{element(3, D), length(element(5, D)), element(6, D)} || D <- Decls, is_tuple(D), element(1, D) =:= signature]
    catch _:_ -> error end.

collisions(D, Fs) ->
    Pub = [{N, A} || {N, A, public} <- Fs],
    By = lists:foldl(fun({N, A}, M) -> maps:update_with({snake(N), A}, fun(X) -> lists:usort([N | X]) end, [N], M) end, #{}, Pub),
    [{D, {S, A, Ns}} || {{S, A}, Ns} <- maps:to_list(By), length(Ns) > 1].

snake(Atom) -> list_to_atom(string:lowercase(snake1(atom_to_list(Atom), none))).
snake1([], _) -> [];
snake1([C | T], Prev) ->
    Up = C >= $A andalso C =< $Z,
    NextLow = case T of [N | _] -> N >= $a andalso N =< $z; [] -> false end,
    PrevLow = Prev =/= none andalso ((Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9)),
    PrevUp = Prev =/= none andalso (Prev >= $A andalso Prev =< $Z),
    Sep = Up andalso (PrevLow orelse (PrevUp andalso NextLow)),
    (case Sep of true -> [$_]; false -> [] end) ++ [C] ++ snake1(T, C).
