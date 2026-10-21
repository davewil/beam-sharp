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

%% The defect itself, executed: with a BARE success, a stored value that IS the atom `nothing`
%% cannot be told from "absent".
ambiguity() ->
    M = #{present_but_nothing => nothing, other => 1},
    FindBare   = fun(K) -> case maps:find(K, M) of {ok, V} -> V; error -> nothing end end,
    FindTagged = fun(K) -> case maps:find(K, M) of {ok, V} -> {some, V}; error -> nothing end end,
    io:format("bare   : present_but_nothing -> ~w ; missing -> ~w ; distinguishable? ~w~n",
        [FindBare(present_but_nothing), FindBare(missing), FindBare(present_but_nothing) =/= FindBare(missing)]),
    io:format("tagged : present_but_nothing -> ~w ; missing -> ~w ; distinguishable? ~w~n",
        [FindTagged(present_but_nothing), FindTagged(missing), FindTagged(present_but_nothing) =/= FindTagged(missing)]).

bare(0, _) -> ok;
bare(N, V) -> put(k, V), bare(N-1, V).
tagged(0, _) -> ok;
tagged(N, V) -> put(k, {some, V}), tagged(N-1, V).   % put/2 makes the tuple escape: the optimiser cannot delete the allocation

time(N) ->
    V = erlang:phash2(make_ref(), 100) + 1000,     % unknown to the compiler
    Best = fun(F) -> lists:min([element(1, timer:tc(?MODULE, F, [N, V])) || _ <- lists:seq(1,7)]) end,
    B = Best(bare), T = Best(tagged),
    io:format("~p round trips: bare ~p ms, tagged ~p ms, delta ~.3f ns/op~n", [N, B div 1000, T div 1000, (T-B)*1000/N]).
