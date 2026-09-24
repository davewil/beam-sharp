%%% PROTOTYPE 25g — exemplar 7: a B# Jev.Server.
%%%
%%% Throwaway. Ticket 25. Like 25f this drives the module bsc builds rather
%%% than a hand lowering. 25g_surface_probe.sh builds 'Support.Triage' (25f),
%%% 'Jev' and 'Triage' from the extracted exemplars and runs:
%%%
%%%   erlc 25g_replay.erl && erl -noshell -pa EBIN -s '25g_replay' main
%%%
%%% The transport is a fun, as Jev's tests stub Req with a plug. It reads the
%%% issue title out of the request body and answers with the TypeSafe reply
%%% Jev's README describes for that issue, so nothing leaves the machine. One
%%% issue's transport crashes, to show a crashed request answering its caller.
-module('25g_replay').
-export([main/0]).

answer(Kind, KindConf, Severity, Security) ->
    #{<<"model">> => <<"jev-1.13.0">>,
      <<"answers">> =>
          #{<<"kind">> => #{<<"type">> => <<"choice">>, <<"choice">> => Kind,
                            <<"confidence">> => KindConf},
            <<"severity">> => #{<<"type">> => <<"score">>, <<"score">> => Severity,
                                <<"confidence">> => 0.6},
            <<"security">> => #{<<"type">> => <<"noul">>, <<"noul">> => Security}},
      <<"usage">> => #{<<"input_tokens">> => 812, <<"output_tokens">> => 0}}.

reply_for(<<"App crashes on launch">>)         -> answer(<<"bug">>, 0.93, 2.4, 0.03);
reply_for(<<"Passwords visible in debug log">>) -> answer(<<"bug">>, 0.7, 2.0, 0.91);
reply_for(<<"Dark mode?">>)                     -> answer(<<"feature">>, 0.8, 0.4, 0.01);
reply_for(<<"hmm">>)                            -> answer(<<"other">>, 0.3, 1.0, 0.02);
reply_for(<<"Crash the request">>)              -> erlang:error(transport_down).

send() ->
    fun(#{'Body' := Body}) ->
        #{<<"state">> := #{<<"title">> := Title}} = json:decode(Body),
        {200, iolist_to_binary(json:encode(reply_for(Title)))}
    end.

issue(Title, Body) -> #{'Kind' => 'Triage.Issue', 'Title' => Title, 'Body' => Body}.

main() ->
    {ok, P} = gen_server:start('Triage',
                               #{'Kind' => 'Triage.Config', 'Send' => send(),
                                 'Token' => <<"test">>}, []),
    Issues = [issue(<<"App crashes on launch">>, <<"Since 2.3.1 the app closes immediately on iOS 17.">>),
              issue(<<"Passwords visible in debug log">>, <<"The auth module logs the raw password.">>),
              issue(<<"Dark mode?">>, <<"Would be nice to have a dark theme.">>),
              issue(<<"hmm">>, <<"it does not work">>),
              issue(<<"Crash the request">>, <<"the transport raises">>)],
    Self = self(),
    %% All five in flight at once, as Jev's README runs them.
    [spawn(fun() -> Self ! {I, gen_server:call(P, {labels, I}, 5000)} end) || I <- Issues],
    [receive {I, Labels} ->
         io:format("~-34s ~p~n", [maps:get('Title', I), Labels])
     end || I <- Issues],
    io:format("server alive after a crashed request: ~p~n", [is_process_alive(P)]),
    halt().
