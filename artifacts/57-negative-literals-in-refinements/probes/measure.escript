#!/usr/bin/env escript
%% usage: measure.escript EBIN FILE REPS  -> reductions (deterministic, load-independent) and wall-ms medians
%% for lex+parse and for bs_check:check/1, over one .bs file. Check errors are counted, not fatal.
main([Ebin, File, RepsS]) ->
    code:add_patha(Ebin),
    Reps = list_to_integer(RepsS),
    {ok, Bin} = file:read_file(File),
    Src = binary_to_list(Bin),
    Parse = fun() -> {ok, T, _} = bs_lexer:string(Src), bs_parser:parse(T) end,
    {ok, Decls} = Parse(),
    Check = fun() -> try bs_check:check(Decls) of R -> R catch C:E -> {C, E} end end,
    R1 = Check(),
    Tag = case R1 of {ok, _, _} -> ok; L when is_list(L) -> {errors, length(L)}; O -> element(1, O) end,
    {PR, PW} = bench(Parse, Reps),
    {CR, CW} = bench(Check, Reps),
    io:format("decls=~p check=~p parse: ~p reductions ~.1f ms | check: ~p reductions ~.1f ms~n",
              [length(Decls), Tag, PR, PW, CR, CW]).

bench(F, Reps) ->
    Ms = [begin
              {reductions, R0} = process_info(self(), reductions),
              T0 = erlang:monotonic_time(microsecond),
              F(),
              T1 = erlang:monotonic_time(microsecond),
              {reductions, R1} = process_info(self(), reductions),
              {R1 - R0, (T1 - T0) / 1000}
          end || _ <- lists:seq(1, Reps)],
    Rs = lists:sort([R || {R, _} <- Ms]), Ts = lists:sort([T || {_, T} <- Ms]),
    {lists:nth((Reps + 1) div 2, Rs), lists:nth((Reps + 1) div 2, Ts)}.
