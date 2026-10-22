%% Hand-written Erlang mimicking what bs_emit WOULD have to emit if "narrow" were made sound by checking container
%% elements at the exported door (Option 3). NOT output of bsc: bsc emits no element check today (probe 01).
-module(deep_door).
-export([run/0]).

%% as emitted today: head matches the list shape only
shallow([])      -> 0;
shallow([O | T]) -> inner(O) + shallow(T).

%% door checks every element's tag on entry; the recursion re-enters the exported name, so it re-checks the tail
deep(Os) when is_list(Os) ->
    case lists:all(fun(O) -> is_map(O) andalso map_get('Kind', O) =:= 'T.Order' end, Os) of
        true -> deep_body(Os)
    end.
deep_body([])      -> 0;
deep_body([O | T]) -> inner(O) + deep(T).

%% same check but the recursion goes through a local worker (one pass); needs the author to split the function
once(Os) when is_list(Os) ->
    true = lists:all(fun(O) -> is_map(O) andalso map_get('Kind', O) =:= 'T.Order' end, Os),
    shallow(Os).

inner(O) -> map_get('Total', O).

run() ->
    O = #{'Kind' => 'T.Order', 'Id' => 1, 'Total' => 10},
    [begin
         Os = lists:duplicate(N, O),
         T = fun(F) -> {U, _} = timer:tc(fun() -> [F(Os) || _ <- lists:seq(1, 20)] end), U / 20 end,
         io:format("n=~-6w shallow ~10.1f us   door-check-per-entry (recursion re-enters) ~12.1f us   check-once ~10.1f us~n",
                   [N, T(fun shallow/1), T(fun deep/1), T(fun once/1)])
     end || N <- [100, 1000, 4000]],
    ok.
