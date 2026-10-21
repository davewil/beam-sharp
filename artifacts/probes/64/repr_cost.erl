%% 64 / probe 1 — what a tagged success costs on the BEAM, and what the bare form cannot express.
%% Words: erts_debug:flat_size/1. Time: compiled (not interpreted) loops, value hidden from the optimiser
%% via an argument that arrives through apply/3, best of 7. Run: ./run_p1.sh
-module(repr_cost).
-export([sizes/0, ambiguity/0, time/1, bare/2, tagged/2]).

sizes() ->
    io:format("OTP ~s, word = ~p bytes~n", [erlang:system_info(otp_release), erlang:system_info(wordsize)]),
    Vals = [{"small int", 42}, {"atom", ok}, {"binary 20B", <<"abcdefghijklmnopqrst">>},
            {"list of 8", lists:seq(1,8)}, {"map of 3", #{a=>1,b=>2,c=>3}}],
    io:format("~-12s ~6s ~9s ~7s~n", ["value","bare","{some,V}","extra"]),
    [io:format("~-12s ~6w ~9w ~7w~n", [N, erts_debug:flat_size(V), erts_debug:flat_size({some,V}),
                                       erts_debug:flat_size({some,V}) - erts_debug:flat_size(V)]) || {N,V} <- Vals],
    io:format("(extra = the 2-tuple: 1 header word + tag word + payload slot, 3 words; payload itself is shared)~n").

%% NOTE: the finders below are hand-written, so this block only restates the encoding; the evidence that B#
%% itself loses the information is 64-p4. The defect, restated: with a BARE success, a stored value that IS the atom `nothing`
%% cannot be told from "absent".
ambiguity() ->
    M = #{present_but_nothing => nothing, other => 1},
    FindBare   = fun(K) -> case maps:find(K, M) of {ok, V} -> V; error -> nothing end end,
    FindTagged = fun(K) -> case maps:find(K, M) of {ok, V} -> {some, V}; error -> nothing end end,
    io:format("bare   : present_but_nothing -> ~w ; missing -> ~w ; distinguishable? ~w~n",
        [FindBare(present_but_nothing), FindBare(missing), FindBare(present_but_nothing) =/= FindBare(missing)]),
    io:format("tagged : present_but_nothing -> ~w ; missing -> ~w ; distinguishable? ~w~n",
        [FindTagged(present_but_nothing), FindTagged(missing), FindTagged(present_but_nothing) =/= FindTagged(missing)]).

%% Returned-and-matched, as a lookup's caller sees it: the callee returns bare V or {some,V}; the caller unwraps
%% and accumulates, so neither the allocation nor the match can be removed. wrap/1 and id/1 are not inlined.
-compile({no_inline, [{wrap, 1}, {id, 1}]}).
id(V) -> V.
wrap(V) -> {some, V}.
bare(N, V) -> bare(N, V, 0).
bare(0, _, Acc) -> Acc;
bare(N, V, Acc) -> Y = id(V), bare(N-1, V, Acc + Y).
tagged(N, V) -> tagged(N, V, 0).
tagged(0, _, Acc) -> Acc;
tagged(N, V, Acc) -> {some, Y} = wrap(V), tagged(N-1, V, Acc + Y).

time(N) ->
    V = erlang:phash2(make_ref(), 100) + 1000,     % unknown to the compiler
    Best = fun(F) -> lists:min([element(1, timer:tc(?MODULE, F, [N, V])) || _ <- lists:seq(1,7)]) end,
    B = Best(bare), T = Best(tagged),
    io:format("~p round trips: bare ~p ms, tagged ~p ms, delta ~.3f ns/op~n", [N, B div 1000, T div 1000, (T-B)*1000/N]).
