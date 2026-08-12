%%% PROTOTYPE 15c — is `try` the only way to survive a callee crash?
%%%
%%% Evidence for ticket 15. Observed locally on OTP 28 (2026-08-12).
%%%
%%% Ticket 14 (14d) measured that four of five wrong-pid failures reach the caller
%%% as an EXIT, not a value. Ticket 12 accepts that: the caller dies, the supervisor
%%% restarts. But a client API that wants to declare `result<T, E>` rather than die
%%% needs SOME way to convert that exit into a value.
%%%
%%% The question this ticket must answer is whether that conversion requires
%%% `try`/`catch` IN THE SURFACE LANGUAGE, or whether it can live entirely inside a
%%% prelude function -- in which case beam-sharp needs no exception-handling syntax
%%% at all, and the crash-versus-value choice stays where ticket 12 put it: in the
%%% signature.
%%%
%%% Run: erlc -o . 15c_surviving_a_callee_crash.erl
%%%      erl -noshell -kernel logger_level critical -pa . \
%%%          -eval "'15c_surviving_a_callee_crash':run()" 2>/dev/null

-module('15c_surviving_a_callee_crash').
-behaviour(gen_server).
-export([run/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

init(_) -> {ok, state}.

%% Only one request shape is handled. Anything else crashes the server, which
%% propagates to the caller of gen_server:call as an exit.
handle_call(good, _From, S) -> {reply, {ok, 42}, S};
handle_call(bad, _From, S)  -> erlang:error(deliberate_failure), {reply, never, S}.
handle_cast(_, S) -> {noreply, S}.
handle_info(_, S) -> {noreply, S}.

%%% ---------------------------------------------------------------------------
%%% Route 1: no protection. Ticket 12's default -- the caller dies.
%%% ---------------------------------------------------------------------------
plain(Pid, Req) -> gen_server:call(Pid, Req, 1000).

%%% ---------------------------------------------------------------------------
%%% Route 2: `try`. What Elixir/Erlang code actually writes today.
%%% This is the construct ticket 15 is deciding whether to put in the surface.
%%% ---------------------------------------------------------------------------
with_try(Pid, Req) ->
    try gen_server:call(Pid, Req, 1000) of
        Reply -> Reply
    catch
        exit:Reason  -> {error, {exit, Reason}};
        error:Reason -> {error, {error, Reason}};
        throw:Reason -> {error, {throw, Reason}}
    end.

%%% ---------------------------------------------------------------------------
%%% Route 3: monitor + receive. NO try, NO catch anywhere.
%%%
%%% This is what gen_server:call itself is built from. If this works, the
%%% conversion is expressible with ticket 14's `receive` (a filter) plus ordinary
%%% clause heads -- and needs nothing from ticket 15's exception surface.
%%% ---------------------------------------------------------------------------
with_monitor(Pid, Req) ->
    Ref = erlang:monitor(process, Pid),
    Pid ! {'$gen_call', {self(), Ref}, Req},
    receive
        {Ref, Reply} ->
            erlang:demonitor(Ref, [flush]),
            Reply;
        {'DOWN', Ref, process, _P, Reason} ->
            {error, {down, Reason}}
    after 1000 ->
            erlang:demonitor(Ref, [flush]),
            {error, timeout}
    end.

%%% ---------------------------------------------------------------------------
%%% Route 4: does an exit CROSS a monitor when the caller is not linked?
%%% i.e. is route 3 genuinely safe, or does the caller still die?
%%% ---------------------------------------------------------------------------

%% NOTE: the child must NOT wrap F() in `catch`. An earlier version of this probe
%% did, and every case reported SURVIVED -- the harness was supplying the very
%% protection the probe exists to measure. The child runs F() bare; if F crashes,
%% the child dies and the DOWN message is the observation.
show(Label, F) ->
    Parent = self(),
    Child = spawn(fun() -> Parent ! {result, F()} end),
    MRef = erlang:monitor(process, Child),
    receive
        {result, R} ->
            erlang:demonitor(MRef, [flush]),
            io:format("~-42s caller SURVIVED, got ~p~n", [Label, R]);
        {'DOWN', MRef, process, Child, Why} ->
            io:format("~-42s caller DIED: ~p~n", [Label, element(1, Why)])
    after 3000 -> io:format("~-42s hung~n", [Label])
    end.

run() ->
    {ok, P1} = gen_server:start(?MODULE, [], []),
    show("1 plain call, server crashes",
         fun() -> plain(P1, bad) end),

    {ok, P2} = gen_server:start(?MODULE, [], []),
    show("2 try/catch, server crashes",
         fun() -> with_try(P2, bad) end),

    {ok, P3} = gen_server:start(?MODULE, [], []),
    show("3 monitor+receive, server crashes",
         fun() -> with_monitor(P3, bad) end),

    {ok, P4} = gen_server:start(?MODULE, [], []),
    show("4 monitor+receive, happy path",
         fun() -> with_monitor(P4, good) end),

    show("5 monitor+receive, dead pid",
         fun() -> with_monitor(spawn(fun() -> ok end), good) end),

    %% 6: a LOCAL crash in the caller's own code -- not a callee at all.
    show("6 local raise in caller's own code",
         fun() -> erlang:error(my_own_bug) end),

    %% 7: can a monitor rescue a LOCAL crash? (it cannot -- shown for contrast)
    show("7 local raise, wrapped in try",
         fun() -> try erlang:error(my_own_bug)
                  catch error:R -> {error, {error, R}} end end),
    init:stop().
