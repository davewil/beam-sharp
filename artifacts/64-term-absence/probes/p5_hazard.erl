%% p5: the real-world hazard. A map<string, term> (Plug assigns / decoded jsonb /
%% Req headers) whose values legitimately include the atoms the absence/failure
%% channels use. The "untagged" functions are what a B# lowering of option<term> /
%% result<term,E> WOULD emit if the checker let the collapse through (bare value
%% in the success position, marker atom/tuple in the failure position).
%% Run: ./p5_run.sh > p5_hazard.out
-module(p5_hazard).
-export([main/0]).

untagged_opt(M, K)    -> maps:get(K, M, nothing).            %% option<term> as T | :nothing
untagged_res(M, K)    -> case maps:find(K, M) of
                             {ok, V} -> V;
                             error   -> {error, missing}      %% result<term, atom> as T | (:error, E)
                         end.
tagged(M, K)          -> case maps:find(K, M) of {ok, V} -> {ok, V}; error -> absent end.
get_or(M, K, D)       -> maps:get(K, M, D).
has_get(M, K)         -> case maps:is_key(K, M) of true -> {present, maps:get(K, M)}; false -> missing end.

%% ground truth: key present or not
truth(M, K) -> case maps:is_key(K, M) of true -> present; false -> missing end.

%% how a caller classifies an untagged option result
class_opt(nothing) -> missing;
class_opt(_)       -> present.
%% how a caller classifies an untagged result
class_res({error, _}) -> failed;
class_res(_)          -> ok.
%% tagged
class_tag(absent)  -> missing;
class_tag({ok, _}) -> present.

main() ->
    %% realistic: feature-flag-ish assigns; atom values that mean something in the domain
    M = #{<<"retry">>   => nothing,           %% "retry policy: nothing"
          <<"status">>  => error,             %% a recorded status atom
          <<"upstream">> => {error, timeout}, %% a decoded {error, Reason} an upstream stored
          <<"user_id">> => 42,
          <<"locale">>  => <<"en">>},
    Keys = [<<"retry">>, <<"status">>, <<"upstream">>, <<"user_id">>, <<"locale">>, <<"usr_id">>],  %% last: typo
    Rows = [{K, truth(M, K), class_opt(untagged_opt(M, K)),
                class_res(untagged_res(M, K)), class_tag(tagged(M, K)), has_get(M, K)} || K <- Keys],
    io:format("~-12s ~-9s ~-10s ~-10s ~-10s~n", ["key", "truth", "untag-opt", "untag-res", "tagged"]),
    [io:format("~-12s ~-9s ~-10s ~-10s ~-10s~n", [K, T, O, R, G]) || {K, T, O, R, G, _} <- Rows],
    BadOpt = [K || {K, T, O, _, _, _} <- Rows, T =/= O],
    BadRes = [K || {K, T, _, R, _, _} <- Rows, (T =:= present andalso R =:= failed) orelse (T =:= missing andalso R =:= ok)],
    BadTag = [K || {K, T, _, _, G, _} <- Rows, T =/= G],
    BadHasGet = [K || {K, T, _, _, _, H} <- Rows, T =/= element(1, case H of missing -> {missing}; {present, _} -> {present} end)],
    io:format("~nuntagged option misreads : ~p~n", [BadOpt]),
    io:format("untagged result misreads (present value read as failure, or absent read as ok): ~p~n", [BadRes]),
    io:format("tagged misreads            : ~p~n", [BadTag]),
    io:format("Has+Get misreads           : ~p~n", [BadHasGet]),
    %% the typo key: 48l's point - tagging does NOT turn a typo into a compile error
    io:format("typo key usr_id under tagged => ~p (same answer as a legitimately absent optional key)~n",
              [tagged(M, <<"usr_id">>)]),
    %% GetOr with a sentinel default is only as safe as the default
    io:format("get_or(retry, nothing)=~p  get_or(absent key, nothing)=~p  (equal: ~p)~n",
              [get_or(M, <<"retry">>, nothing), get_or(M, <<"zzz">>, nothing),
               get_or(M, <<"retry">>, nothing) =:= get_or(M, <<"zzz">>, nothing)]),
    Ok = BadOpt =/= [] andalso BadRes =/= [] andalso BadTag =:= [] andalso BadHasGet =:= [],
    io:format("ASSERT (untagged misreads exist; tagged and Has+Get have none): ~s~n", [case Ok of true -> "holds"; false -> "FAILS" end]),
    halt(case Ok of true -> 0; false -> 1 end).
