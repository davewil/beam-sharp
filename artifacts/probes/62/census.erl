-module(census).
-export([main/1]).
%% Heuristic census over the real lexer (bs_lexer): a `uident` immediately followed by `(` is a
%% function name at a definition (clause head or signature) or call site; a `uident ( ` that starts in
%% column 1 is a clause head; a signature line is `<type> Name(` at column 1 preceded by `public`/type tokens.
%% Distinct (file,name) pairs at column-1 `Name(` approximate the number of function definitions (sets of clauses).
main(Args) ->
    Sets = [{"compiler/examples (non-exemplar)", filter(wild("compiler/examples/**/*.bs"), fun(P) -> string:find(P, "/exemplars/") =:= nomatch end)},
            {"compiler/examples/exemplars", wild("compiler/examples/exemplars/**/*.bs")},
            {"aoc/", wild("aoc/**/*.bs")},
            {"handoff/audition-switch", wild("handoff/audition-switch/**/*.bs")},
            {"compiler/bin/fixtures", wild("compiler/bin/fixtures/**/*.bs")},
            {"wayfinder/prototypes", wild("wayfinder/prototypes/**/*.bs")}],
    _ = Args,
    io:format("~-34s ~5s ~6s ~8s ~9s ~10s~n", ["corpus", "files", "lexed", "fn names", "clauseHds", "call-like"]),
    Tot = lists:foldl(fun({Name, Fs}, Acc) ->
        Rs = [one(F) || F <- Fs],
        Ok = [R || R <- Rs, R =/= error],
        Names = lists:usort(lists:append([N || {N, _, _} <- Ok])),
        Heads = lists:sum([H || {_, H, _} <- Ok]),
        Calls = lists:sum([C || {_, _, C} <- Ok]),
        io:format("~-34s ~5w ~6w ~8w ~9w ~10w~n", [Name, length(Fs), length(Ok), length(Names), Heads, Calls]),
        {A, B, C} = Acc, {A + length(Fs), B + length(Names), C + Calls}
    end, {0, 0, 0}, Sets),
    io:format("TOTAL files ~p, distinct (per-set) function names ~p, call-like tokens ~p~n", [element(1, Tot), element(2, Tot), element(3, Tot)]),
    AllNames = lists:usort(lists:append([N || {_, Fs} <- Sets, F <- Fs, {N, _, _} <- [one(F)], N =/= []])),
    Us = [N || N <- AllNames, lists:member($_, atom_to_list(N))],
    Ac = [N || N <- AllNames, re:run(atom_to_list(N), "[A-Z][A-Z]") =/= nomatch],
    Dg = [N || N <- AllNames, re:run(atom_to_list(N), "[0-9]") =/= nomatch],
    io:format("function-like names over all corpora: ~p distinct; containing '_': ~p ~p; two adjacent capitals: ~p ~p; digits: ~p ~p~n", [length(AllNames), length(Us), lists:sublist(Us, 6), length(Ac), lists:sublist(Ac, 6), length(Dg), lists:sublist(Dg, 6)]),
    io:format("CONTROL the three patterns do fire on known inputs ('Get_x','HTTPGet','Md5'): ~p~n", [[re:run(X, P) =/= nomatch || {X, P} <- [{"Get_x", "_"}, {"HTTPGet", "[A-Z][A-Z]"}, {"Md5", "[0-9]"}]]]),
    %% CONTROL: a file with a known answer. 2 clause heads (Fib, twice), name Fib, 2 recursive calls inside + 0 else.
    {ok, T, _} = bs_lexer:string("module M\n\npublic int Fib(int n)\n\nFib(n) when n <= 1 -> n\nFib(n) when n > 1 -> Fib(n - 1) + Fib(n - 2)\n"),
    io:format("CONTROL (known answer: names=[Fib] clause heads=2 call-like=5 [1 signature + 2 heads + 2 calls]): ~p~n", [count(T)]).

wild(G) -> lists:sort(filelib:wildcard(G)).
filter(L, F) -> [X || X <- L, F(X)].

one(F) ->
    {ok, B} = file:read_file(F),
    case catch bs_lexer:string(binary_to_list(B)) of
        {ok, T, _} -> count(T);
        _ -> error
    end.

count(Ts) -> count(Ts, [], 0, 0).
count([{uident, {_, Col}, N}, {'(', _} | R], Names, Heads, Calls) ->
    count(R, [N | Names], Heads + case Col of 1 -> 1; _ -> 0 end, Calls + 1);
count([_ | R], Ns, H, C) -> count(R, Ns, H, C);
count([], Ns, H, C) -> {lists:usort(Ns), H, C}.
