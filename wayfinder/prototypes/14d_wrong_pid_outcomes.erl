%%% PROTOTYPE 14d — what actually happens when a client API is handed the wrong pid?
%%%
%%% Evidence for ticket 14. Observed locally on OTP 28 (2026-08-12).
%%%
%%% The question: a beam-sharp client function `Apply(pid, ...)` declares a return
%%% type, but nothing proves the pid is the server that produces it. How many of the
%%% ways that can go wrong yield a WRONG VALUE, versus a crash the design already
%%% accepts under ticket 12's signature-directed stance?
%%%
%%% Run: erlc -o . 14d_wrong_pid_outcomes.erl
%%%      erl -noshell -kernel logger_level critical -pa . \
%%%          -eval "'14d_wrong_pid_outcomes':run()" 2>/dev/null
%%%
%%% RESULT (verbatim, trimmed to the outcome tag):
%%%   1 right server                  {ok,<<"an order">>}
%%%   2 dead pid                      {'EXIT',noproc}
%%%   3 wrong server, no such clause  {'EXIT',unhandled}    (the SERVER died too)
%%%   4 not a gen_server at all       {'EXIT',timeout}
%%%   5 shape collision               {ok,4200}   <-- an integer where the client
%%%                                                   API declared a binary
%%%
%%% CONCLUSION: four of the five are crashes, which ticket 12's signature-directed
%%% stance already accepts and which no type could have prevented anyway. Only case 5
%%% returns a wrong value, and it requires two servers to accept the SAME request
%%% shape and reply with DIFFERENT types. That is ticket 06's third outcome (silent
%%% unsoundness) reappearing in the reply channel — already owned by ticket 18, not
%%% by ticket 14, and not an argument for parameterising process identity.
-module('14d_wrong_pid_outcomes').
-behaviour(gen_server).
-export([run/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% Two servers with deliberately overlapping request shapes.
init(Which) -> {ok, Which}.

%% Orders: fetch replies with a binary.
handle_call({fetch, _Id}, _From, orders) -> {reply, {ok, <<"an order">>}, orders};
handle_call({apply, _Id, _E}, _From, orders) -> {reply, {ok, applied}, orders};
%% Payments: SAME request shape, different reply type (an integer, not a binary).
handle_call({fetch, _Id}, _From, payments) -> {reply, {ok, 4200}, payments};
%% No catch-all: this is Erlang's default, i.e. a crash on an unknown request.
handle_call(_, _, _) -> erlang:error(unhandled).

handle_cast(_, S) -> {noreply, S}.
handle_info(_, S) -> {noreply, S}.

%% Each case gets a fresh server, since several of them kill the one they touch.
run() ->
    show("1 right server                 ", fun() ->
        gen_server:call(fresh(orders), {fetch, <<"o1">>}) end),

    show("2 dead pid                     ", fun() ->
        P = fresh(orders), gen_server:stop(P),
        gen_server:call(P, {fetch, <<"o1">>}) end),

    show("3 wrong server, no such clause ", fun() ->
        gen_server:call(fresh(payments), {apply, <<"o1">>, ev}) end),

    show("4 not a gen_server at all      ", fun() ->
        gen_server:call(spawn(fun() -> timer:sleep(5000) end),
                        {fetch, <<"o1">>}, 200) end),

    show("5 shape collision              ", fun() ->
        gen_server:call(fresh(payments), {fetch, <<"o1">>}) end),

    init:stop().

fresh(Which) ->
    {ok, Pid} = gen_server:start(?MODULE, Which, []),
    Pid.

%% Print only the outcome tag: full stacktraces bury the finding.
show(Label, F) ->
    Outcome =
        try F() of
            V -> V
        catch
            exit:{Reason, _} when is_atom(Reason) -> {'EXIT', Reason};
            exit:{{Reason, _}, _} -> {'EXIT', Reason};
            C:R -> {C, R}
        end,
    io:format("~s ~p~n", [Label, Outcome]).
