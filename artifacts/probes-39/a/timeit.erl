%% Generic interleaved timer. timeit:main([InputPath, Repeats, "mod1", "mod2", ...]) calls Mod:part_two(Deltas)
%% (or Mod:'PartTwo') round-robin so slow drift hits every variant equally; prints min/median/p90 in ms and
%% rel-to-first by min and median. Answer is checked first.
-module(timeit).
-export([main/1]).
main([In, RepS | Mods0]) ->
    Reps = list_to_integer(RepS),
    Mods = [list_to_atom(M) || M <- Mods0],
    Ds = read(In),
    Ans = [{M, M:part_two(Ds)} || M <- Mods],
    io:format("emu_flavor=~p otp=~s answers=~p~n", [erlang:system_info(emu_flavor), erlang:system_info(otp_release), Ans]),
    [begin M:part_two(Ds) end || _ <- lists:seq(1, 30), M <- Mods],   % warmup
    Samples = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun(M, A) ->
            T0 = erlang:monotonic_time(nanosecond), _ = M:part_two(Ds),
            T1 = erlang:monotonic_time(nanosecond),
            maps:update_with(M, fun(L) -> [T1 - T0 | L] end, [T1 - T0], A)
        end, Acc, Mods)
    end, #{}, lists:seq(1, Reps)),
    Stats = [{M, stat(maps:get(M, Samples))} || M <- Mods],
    {_, {Min0, Med0, _, _}} = hd(Stats),
    io:format("~-14s ~9s ~9s ~9s ~9s ~8s ~8s~n", ["variant", "min ms", "med ms", "p90 ms", "max ms", "min rel", "med rel"]),
    [io:format("~-14s ~9.3f ~9.3f ~9.3f ~9.3f ~7.3fx ~7.3fx~n", [M, Mn/1.0e6, Md/1.0e6, P90/1.0e6, Mx/1.0e6, Mn/Min0, Md/Med0])
     || {M, {Mn, Md, P90, Mx}} <- Stats],
    halt().
stat(L) -> S = lists:sort(L), N = length(S),
    {hd(S), lists:nth(N div 2 + 1, S), lists:nth(trunc(N*0.9), S), lists:last(S)}.
read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
