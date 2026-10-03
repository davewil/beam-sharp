-module(t).
-export([main/1]).
main([Dir, Input]) ->
    {ok, B} = file:read_file(Input),
    Ds = [case L of [$L|N] -> -list_to_integer(N); [$R|N] -> list_to_integer(N) end
          || L <- string:split(binary_to_list(B), "\n", all), L =/= ""],
    Ms = [a0_control, a1_true_fact, a2_LIE_step],
    [code:load_abs(Dir ++ "/" ++ atom_to_list(M)) || M <- Ms],
    [io:format("~-14s answer=~p (expected 6770)~n", [M, catch M:'PartTwo'(Ds)]) || M <- Ms],
    [[M:'PartTwo'(Ds) || _ <- lists:seq(1,20)] || M <- Ms],
    Rs = [begin {A,B2} = lists:split(R rem 3, Ms), [begin {T,_} = timer:tc(M,'PartTwo',[Ds]), {M,T} end || M <- B2 ++ A] end || R <- lists:seq(0,39)],
    io:format("~n40 rotated runs, ms:  min / median / IQR~n"),
    [begin L = lists:sort([T || R <- Rs, {Mm,T} <- R, Mm =:= M]),
           io:format("~-14s ~7.2f ~7.2f ~7.2f~n", [M, hd(L)/1000, lists:nth(21,L)/1000, (lists:nth(31,L)-lists:nth(11,L))/1000]) end || M <- Ms],
    halt().
