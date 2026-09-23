%%% PROTOTYPE 25f — exemplar 6: an LLM evaluation client (ReqLLM's evaluate/4).
%%%
%%% Throwaway. Ticket 25. Unlike 25a-25e this is not a hand lowering: the module
%%% compiles, so the Erlang it runs is the Erlang bsc emits. This file only
%%% drives it. 25f_surface_probe.sh builds 'Support.Triage' from the extracted
%%% exemplar (with the one wall worked around: Model.Id declared binary) and
%%% then runs:
%%%
%%%   erlc 25f_replay.erl && erl -noshell -pa EBIN -s '25f_replay' main
%%%
%%% The transport is a fun, as ReqLLM's own tests hand Req a plug. It records
%%% the request it was given and answers with a wire body taken from ReqLLM's
%%% test suite, so nothing leaves the machine.
-module('25f_replay').
-export([main/0]).

%% The wire bodies ReqLLM's own test suite serves for evaluate/4
%% (test/req_llm/evaluation_test.exs, req_llm 5a0735d).
typesafe() ->
    #{<<"model">> => <<"jev-1.13.0">>,
      <<"answers">> =>
          #{<<"department">> => #{<<"type">> => <<"choice">>, <<"choice">> => <<"billing">>,
                                  <<"probabilities">> => #{<<"billing">> => 0.9, <<"support">> => 0.1},
                                  <<"confidence">> => 0.8},
            <<"severity">> => #{<<"type">> => <<"score">>, <<"score">> => 1.2,
                                <<"legend">> => #{<<"0">> => <<"low">>, <<"1">> => <<"medium">>, <<"2">> => <<"high">>},
                                <<"probabilities">> => #{<<"0">> => 0.1, <<"1">> => 0.6, <<"2">> => 0.3},
                                <<"confidence">> => 0.6},
            <<"urgent">> => #{<<"type">> => <<"noul">>, <<"noul">> => 0.93}},
      <<"usage">> => #{<<"input_tokens">> => 100, <<"output_tokens">> => 20}}.

openrouter() ->
    (typesafe())#{<<"id">> => <<"gen-jev-test">>, <<"model">> => <<"typesafe/jev-1.13">>,
                  <<"provider">> => <<"TypeSafe AI">>,
                  <<"usage">> => #{<<"input_tokens">> => 100, <<"output_tokens">> => 20, <<"cost">> => 0.0042}}.

questions() ->
    [{<<"department">>, #{'Kind' => 'Support.Triage.Choice', 'Instructions' => <<"Which team should handle this?">>,
                          'Criteria' => [{<<"billing">>, <<"Billing and refunds">>}, {<<"support">>, <<"Other requests">>}]}},
     {<<"severity">>, #{'Kind' => 'Support.Triage.Score', 'Instructions' => <<"How severe is this?">>,
                        'Criteria' => [<<"low">>, <<"medium">>, <<"high">>]}},
     {<<"urgent">>, #{'Kind' => 'Support.Triage.YesNo', 'Instructions' => <<"Is this urgent?">>}}].

serve(Status, Body) ->
    Self = self(),
    fun(Req) -> Self ! {sent, Req}, {Status, iolist_to_binary(json:encode(Body))} end.

run(Label, Spec, Send) ->
    R = 'Support.Triage':'Evaluate'(Send, <<"test-key">>, Spec, <<"Please refund me today">>, questions()),
    Sent = receive {sent, Q} -> Q after 0 -> none end,
    io:format("~n== ~s~n", [Label]),
    case Sent of
        none -> io:format("sent: nothing~n");
        #{'Url' := U, 'Body' := B} -> io:format("sent: ~s~n      ~s~n", [U, B])
    end,
    io:format("got:  ~p~n", [R]),
    case R of
        #{'Kind' := 'Support.Triage.Evaluation'} ->
            io:format("route: ~p~n", ['Support.Triage':'Decide'(R)]);
        _ -> ok
    end.

main() ->
    run("typesafe, 200", <<"typesafe:jev-latest">>, serve(200, typesafe())),
    run("openrouter, 200", <<"openrouter:typesafe/jev-1.13">>, serve(200, openrouter())),
    run("openrouter, 200, malformed (ReqLLM's own case)", <<"openrouter:typesafe/jev-1.13">>,
        serve(200, #{<<"answers">> => #{}})),
    run("typesafe, 401", <<"typesafe:jev-latest">>, serve(401, #{<<"error">> => <<"bad key">>})),
    run("unknown provider", <<"anthropic:claude-haiku-4-5">>, serve(200, typesafe())),
    halt(0).
