%% Call-time bench for ticket 62 option 2. Compares, for the SAME B# function
%% (`Awk.GetOrder/2`, emitted with two is_integer guards):
%%   direct : 'Awk':'GetOrder'(X, Y)        the PascalCase export
%%   alias  : 'Awk':get_order(X, Y)         the patched compiler's wrapper (tail-calls the export)
%%   dup    : 'AwkDup':get_order(X, Y)      the SAME emitted clauses duplicated under the snake name
%% Every variant is a literal remote call in its own loop. N = 10,000,000 calls, 7 repetitions.
-module('62_alias_bench').
-export([run/1]).

run([AwkProtoDir, StockAbstr]) ->
    code:add_patha(AwkProtoDir),
    {ok, Forms0} = file:consult(StockAbstr),
    %% dup: rename module, duplicate GetOrder's clauses under get_order, export it
    Forms = [dupmod(F) || F <- Forms0],
    {value, {function, _, 'GetOrder', 2, Cl}} = lists:keysearch('GetOrder', 3, [F || F <- Forms, element(1, F) =:= function]),
    [ModAttr | Rest] = Forms,
    Forms1 = [ModAttr, {attribute, 0, export, [{get_order, 2}]} | Rest]
             ++ [{function, 0, get_order, 2, Cl}],
    {ok, 'AwkDup', Bin} = compile:forms(strip_specs(Forms1), [return_errors]),
    {module, 'AwkDup'} = code:load_binary('AwkDup', "AwkDup", Bin),
    io:format("sanity: direct=~p alias=~p dup=~p~n",
              ['Awk':'GetOrder'(1, 2), 'Awk':get_order(1, 2), 'AwkDup':get_order(1, 2)]),
    N = 10000000,
    Rows = [{direct, fun() -> l_direct(N, 0) end},
            {alias,  fun() -> l_alias(N, 0) end},
            {dup,    fun() -> l_dup(N, 0) end},
            {empty,  fun() -> l_empty(N, 0) end}],
    _ = [F() || {_, F} <- Rows],                       % warm up
    [report(Name, [timeit(F) || _ <- lists:seq(1, 7)], N) || {Name, F} <- Rows],
    halt().

dupmod({attribute, L, module, 'Awk'}) -> {attribute, L, module, 'AwkDup'};
dupmod(F) -> F.
strip_specs(Fs) -> [F || F <- Fs, element(1, F) =/= attribute orelse element(3, F) =/= spec].

timeit(F) ->
    T0 = erlang:monotonic_time(nanosecond), _ = F(),
    (erlang:monotonic_time(nanosecond) - T0) / 1.0e6.            % ms

report(Name, Ms, N) ->
    S = lists:sort(Ms), Min = hd(S), Med = lists:nth(4, S),
    io:format("~-7s n=7 x ~p calls  min=~.1f ms  median=~.1f ms  (~.2f ns/call at min)~n",
              [Name, N, Min, Med, Min * 1.0e6 / N]).

l_direct(0, A) -> A;
l_direct(N, A) -> l_direct(N - 1, 'Awk':'GetOrder'(N, A band 7)).
l_alias(0, A) -> A;
l_alias(N, A) -> l_alias(N - 1, 'Awk':get_order(N, A band 7)).
l_dup(0, A) -> A;
l_dup(N, A) -> l_dup(N - 1, 'AwkDup':get_order(N, A band 7)).
l_empty(0, A) -> A;
l_empty(N, A) -> l_empty(N - 1, N + (A band 7)).
