%% Shared generator for probes 01 and 03: hand-written Erlang standing in for
%% what bsc would emit for `Handle(C c)` over `type C = A1 | ... | An`
%% (records are tagged maps #{'Kind' => 'T.Ai', 'Id' => _}) plus a wider
%% parameter (`D = C | :none`), so the union is a real discriminator.
-module(lib_gen).
-export([source/3, variants/0, tag/1, input/1]).

variants() -> [dup, guard_semi, guard_orelse, outline].

tag(I) -> list_to_atom("T.A" ++ integer_to_list(I)).

input(N) -> [#{'Kind' => tag(I), 'Id' => I} || I <- lists:seq(1, N)].

%% Body of B chained operations; identical text for every member, which is the
%% "duplicated right-hand side" the ticket complains about.
body(B) ->
    Ops = [io_lib:format("        X~p = erlang:phash2({X~p, ~p, maps:get('Id', C)}),~n", [I, I-1, I]) || I <- lists:seq(1, B)],
    ["        X0 = maps:get('Id', C),\n", Ops, io_lib:format("        {ok, X~p}", [B])].

source(Variant, N, B) ->
    Tags = [tag(I) || I <- lists:seq(1, N)],
    Head = io_lib:format("-module(m).~n-export([handle/1, bench/2]).~n", []),
    Clauses = case Variant of
        dup ->
            [io_lib:format("handle(#{'Kind' := '~s'} = C) ->~n~s;~n", [T, body(B)]) || T <- Tags]
            ++ ["handle(none) -> none.\n"];
        guard_semi ->   %% guard disjunction with `;`
            Gs = string:join([io_lib:format("K =:= '~s'", [T]) || T <- Tags], "; "),
            [io_lib:format("handle(#{'Kind' := K} = C) when ~s ->~n~s;~n", [Gs, body(B)]),
             "handle(none) -> none.\n"];
        guard_orelse -> %% single guard expression with orelse
            Gs = string:join([io_lib:format("K =:= '~s'", [T]) || T <- Tags], " orelse "),
            [io_lib:format("handle(#{'Kind' := K} = C) when ~s ->~n~s;~n", [Gs, body(B)]),
             "handle(none) -> none.\n"];
        outline ->      %% one private body function, each clause calls it
            [io_lib:format("handle(#{'Kind' := '~s'} = C) -> body(C);~n", [T]) || T <- Tags]
            ++ ["handle(none) -> none.\n",
                io_lib:format("body(C) ->~n~s.~n", [body(B)])]
    end,
    Bench = "bench(0, _) -> ok;\nbench(N, L) -> bl(L), bench(N-1, L).\n"
            "bl([]) -> ok;\nbl([H|T]) -> handle(H), bl(T).\n",
    lists:flatten([Head, Clauses, Bench]).
