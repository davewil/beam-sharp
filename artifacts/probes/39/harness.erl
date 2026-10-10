%% Round-robin timing: each round calls every variant once, in rotating order, so drift and
%% frequency changes hit all variants alike. Prints min / median / p25..p75 (the noise band).
-module(harness).
-export([main/1]).

main([Dir, Input, RoundsS | Labels0]) ->
    Rounds = list_to_integer(RoundsS),
    code:add_patha(Dir),
    Deltas = read(Input),
    Labels = [list_to_atom(L) || L <- Labels0],
    [code:ensure_loaded(M) || M <- Labels],
    %% variants exporting Spin under either name; 'part_two' everywhere
    Part = fun(M) -> case erlang:function_exported(M, part_two, 1) of
                         true -> part_two; false -> 'PartTwo' end end,
    Spin = fun(M) -> case erlang:function_exported(M, spin, 4) of
                         true -> spin; false -> 'Spin' end end,
    Whole = [{M, fun() -> M:(Part(M))(Deltas) end} || M <- Labels],
    Loop  = [{M, fun() -> M:(Spin(M))(50, 1, 673364, 0) end} || M <- Labels,
                 erlang:function_exported(M, spin, 4) orelse erlang:function_exported(M, 'Spin', 4)],
    run("whole fold (part_two, 673,364 iterations over 4,732 rotations)", Whole, Rounds),
    run("Spin alone (one call, 673,364 iterations)", Loop, Rounds),
    halt().

run(Title, [], _) -> io:format("~n~s~n  (no variant exports the loop: skipped)~n", [Title]);
run(Title, Fs, Rounds) ->
    Answers = lists:usort([F() || {_, F} <- Fs]),
    io:format("~n~s~n  distinct answers across variants: ~p~n", [Title, Answers]),
    N = length(Fs),
    Acc = lists:foldl(fun(R, A) ->
            Rot = rotate(Fs, R rem N),
            lists:foldl(fun({M,F}, A2) ->
                {T,_} = timer:tc(F), maps:update_with(M, fun(L)->[T|L] end, [T], A2) end, A, Rot)
          end, #{}, lists:seq(1, Rounds)),
    Rows = [begin S = lists:sort(Ts), {M, q(S,0), q(S,50), q(S,25), q(S,75)} end
            || {M,_} <- Fs, Ts <- [maps:get(M, Acc)]],
    Base = lists:min([Min || {_,Min,_,_,_} <- Rows]),
    io:format("  ~-16s ~9s ~9s ~9s ~9s ~7s~n", ["variant","min ms","med ms","p25 ms","p75 ms","min/best"]),
    [io:format("  ~-16s ~9.2f ~9.2f ~9.2f ~9.2f ~6.2fx~n",
               [M, Min/1000, Med/1000, P25/1000, P75/1000, Min/Base]) || {M,Min,Med,P25,P75} <- Rows].

rotate(L, 0) -> L;
rotate([H|T], N) -> rotate(T ++ [H], N-1).
q(S, 0) -> hd(S);
q(S, P) -> lists:nth(max(1, round(length(S)*P/100)), S).

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
