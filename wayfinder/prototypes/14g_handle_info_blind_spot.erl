%%% PROTOTYPE 14g — the blind spot at the showcase.
%%%
%%% Evidence for ticket 14. Observed locally on OTP 28 (2026-08-12).
%%%
%%% Ticket 11 makes `handle_info`'s argument `term`; ticket 12 makes the catch-all
%%% mandatory and legal because that residual is open. Both are right. But together
%%% they mean a clause written with the WRONG SHAPE for a system message never fires,
%%% and the mandatory catch-all absorbs the message in silence.
%%%
%%% Exhaustiveness cannot catch it: the residual is open, so no case is missing.
%%% Redundancy cannot catch it: against `term`, every clause is reachable.
%%% This is the language's headline guarantee having a hole exactly at its showcase.
%%%
%%% Run: erlc -o . 14g_handle_info_blind_spot.erl
%%%      erl -noshell -kernel logger_level critical -pa . \
%%%          -eval "'14g_handle_info_blind_spot':run()" 2>/dev/null
%%%
%%% RESULT (verbatim):
%%%   a real DOWN message arrived:  true
%%%   the DOWN clause fired:        false      <-- swallowed by the catch-all
%%%   the catch-all ran:            1 time(s)
-module('14g_handle_info_blind_spot').
-behaviour(gen_server).
-export([run/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

init(_) -> {ok, #{seen => false, catchall => 0}}.

%% A four-element DOWN pattern. The real message has FIVE elements:
%%   {'DOWN', Ref, process, Pid, Reason}
%% One element out, and this clause can never match -- but nothing says so.
handle_info({'DOWN', _Ref, _Pid, _Reason}, S) ->
    {noreply, S#{seen := true}};

%% The mandatory catch-all. Ticket 12: (:noreply, a) is an honest value here.
handle_info(_Other, S = #{catchall := N}) ->
    {noreply, S#{catchall := N + 1}}.

%% `watch` monitors from inside the server, so the DOWN lands in ITS mailbox.
handle_cast({watch, Target}, S) ->
    _ = erlang:monitor(process, Target),
    {noreply, S};
handle_cast(_, S) ->
    {noreply, S}.

handle_call(get, _From, S) -> {reply, S, S}.

run() ->
    {ok, Pid} = gen_server:start(?MODULE, [], []),
    Watched = spawn(fun() -> timer:sleep(20) end),
    gen_server:cast(Pid, {watch, Watched}),
    timer:sleep(200),

    #{seen := Seen, catchall := N} = gen_server:call(Pid, get),
    io:format("a real DOWN message arrived:  ~p~n", [N > 0 orelse Seen]),
    io:format("the DOWN clause fired:        ~p      <-- ~s~n",
              [Seen, case Seen of
                         false -> "swallowed by the catch-all";
                         true  -> "matched"
                     end]),
    io:format("the catch-all ran:            ~p time(s)~n", [N]),
    init:stop().
