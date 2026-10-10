%%% PROTOTYPE 25f — exemplar 6: an LLM evaluation client (ReqLLM's evaluate/4).
%%%
%%% Throwaway. Ticket 25. Unlike 25a-25e this is not a hand lowering: the module
%%% compiles, so the Erlang it runs is the Erlang bsc emits. This file only
%%% drives it. 25f_surface_probe.sh builds 'Support.Triage' from the extracted
%%% exemplar (its reply side rewritten onto FromJson<T>, F69) and then runs:
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

serve(Status, Body) -> serve_text(Status, iolist_to_binary(json:encode(Body))).

serve_text(Status, Text) ->
    Self = self(),
    fun(Req) -> Self ! {sent, Req}, {Status, Text} end.

%% A good reply with a second "model" after the first: the body a proxy that
%% keeps the first value and a client that keeps the last would disagree on.
repeated_model() ->
    Good = iolist_to_binary(json:encode(openrouter())),
    Open = binary:part(Good, 0, byte_size(Good) - 1),
    <<Open/binary, ",\"model\":\"other/model\"}">>.

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
    end,
    R.

main() ->
    run("typesafe, 200", <<"typesafe:jev-latest">>, serve(200, typesafe())),
    run("openrouter, 200", <<"openrouter:typesafe/jev-1.13">>, serve(200, openrouter())),
    Malformed = run("openrouter, 200, malformed (ReqLLM's own case)", <<"openrouter:typesafe/jev-1.13">>,
                    serve(200, #{<<"answers">> => #{}})),
    %% Ticket 78 Q24: the reply lacks "model", and the error says so.
    case Malformed of
        {error, {malformed, #{'Kind' := 'ValidationError', 'Path' := [<<"[\"model\"]">>],
                              'Expected' := <<"string">>, 'Reason' := missing}}} ->
            io:format("malformed: ok~n");
        _ ->
            io:format("malformed: WRONG ~0p~n", [Malformed]),
            halt(1)
    end,
    Repeated = run("openrouter, 200, \"model\" twice", <<"openrouter:typesafe/jev-1.13">>,
                   serve_text(200, repeated_model())),
    %% Ticket 78 Q20: the reply names "model" twice, and the error says so.
    case Repeated of
        {error, {malformed, #{'Kind' := 'ValidationError', 'Path' := [],
                              'Expected' := <<"\"model\" once">>, 'Reason' := duplicate_key}}} ->
            io:format("repeated: ok~n");
        _ ->
            io:format("repeated: WRONG ~0p~n", [Repeated]),
            halt(1)
    end,
    Tri = run("openrouter, 200, an answer of type \"tri\"", <<"openrouter:typesafe/jev-1.13">>,
              serve(200, (openrouter())#{<<"answers">> =>
                                             #{<<"department">> => #{<<"type">> => <<"tri">>}}})),
    %% Ticket 78 Q19: the answer's tag names no member, and the error says so.
    case Tri of
        {error, {malformed, #{'Kind' := 'ValidationError',
                              'Path' := [<<"[\"answers\"]">>, <<"[\"department\"]">>,
                                         <<"[\"type\"]">>],
                              'Expected' := <<"\"choice\" | \"noul\" | \"score\"">>,
                              'Reason' := mismatch}}} ->
            io:format("unknown tag: ok~n");
        _ ->
            io:format("unknown tag: WRONG ~0p~n", [Tri]),
            halt(1)
    end,
    run("typesafe, 401", <<"typesafe:jev-latest">>, serve(401, #{<<"error">> => <<"bad key">>})),
    run("unknown provider", <<"anthropic:claude-haiku-4-5">>, serve(200, typesafe())),
    halt(0).
