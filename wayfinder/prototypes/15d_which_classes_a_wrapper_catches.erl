%%% PROTOTYPE 15d — what may a generated foreign-boundary wrapper safely catch?
%%%
%%% Evidence for ticket 15. Observed locally on OTP 28 (2026-08-12).
%%%
%%% Ticket 15 settled that the compiler emits a try/catch wrapper around a foreign
%%% call declared to return `result<T, E>`. This probe asks which of the BEAM's three
%%% exception classes that wrapper may catch.
%%%
%%% The feared hazard: a wide `catch exit:R` swallows a supervisor's shutdown signal,
%%% turning an orderly kill into a value the code ignores -- the OTP equivalent of
%%% catching ThreadAbortException.
%%%
%%% The question that decides it: does `try/catch exit:` catch an exit SIGNAL sent
%%% from another process, or only an exit RAISED locally inside the evaluated
%%% expression? If signals are not catchable, the hazard does not exist and a wide
%%% catch is safe.
%%%
%%% Run: erlc -o /tmp/15d 15d_which_classes_a_wrapper_catches.erl
%%%      erl -noshell -kernel logger_level critical -pa /tmp/15d \
%%%          -eval "'15d_which_classes_a_wrapper_catches':run()" 2>/dev/null

-module('15d_which_classes_a_wrapper_catches').
-export([run/0]).

%% The wrapper the compiler would generate: widest possible catch.
wide(F) ->
    try F() of
        V -> {ok, V}
    catch
        error:R -> {caught, error, R};
        throw:R -> {caught, throw, R};
        exit:R  -> {caught, exit, R}
    end.

observe(Label, Fun) ->
    Parent = self(),
    Child = spawn(fun() -> Parent ! {done, Fun()} end),
    MRef = erlang:monitor(process, Child),
    receive
        {done, R} ->
            erlang:demonitor(MRef, [flush]),
            io:format("~-46s SURVIVED  ~p~n", [Label, R]);
        {'DOWN', MRef, process, Child, Why} ->
            W = case Why of {W0, _} -> W0; W0 -> W0 end,
            io:format("~-46s DIED      ~p~n", [Label, W])
    after 2000 -> io:format("~-46s hung~n", [Label])
    end.

run() ->
    io:format("~n--- locally raised, inside the wrapper ---~n"),
    observe("1 error raised locally",
            fun() -> wide(fun() -> erlang:error(boom) end) end),
    observe("2 throw raised locally",
            fun() -> wide(fun() -> throw(boom) end) end),
    observe("3 exit called locally",
            fun() -> wide(fun() -> exit(boom) end) end),

    io:format("~n--- gen_server:call failures (exit raised in the CALLER) ---~n"),
    observe("4 call to a dead pid",
            fun() ->
                Dead = spawn(fun() -> ok end),
                timer:sleep(20),
                wide(fun() -> gen_server:call(Dead, req, 200) end)
            end),

    io:format("~n--- exit SIGNAL from another process ---~n"),
    %% A linked process dies. The signal arrives asynchronously; the wrapper is
    %% sitting in a receive inside F(). Can the catch intercept it?
    observe("5 linked process dies while wrapper is running",
            fun() ->
                Me = self(),
                spawn_link(fun() -> timer:sleep(50), exit(killed_by_peer) end),
                wide(fun() -> receive never -> ok after 500 -> {no_signal, Me} end end)
            end),

    %% Same, but the peer sends an explicit exit signal to us by pid.
    observe("6 explicit exit signal sent to us by pid",
            fun() ->
                Me = self(),
                spawn(fun() -> timer:sleep(50), exit(Me, terminated_by_peer) end),
                wide(fun() -> receive never -> ok after 500 -> no_signal end end)
            end),

    %% And the unblockable one.
    observe("7 exit(Pid, kill)",
            fun() ->
                Me = self(),
                spawn(fun() -> timer:sleep(50), exit(Me, kill) end),
                wide(fun() -> receive never -> ok after 500 -> no_signal end end)
            end),
    init:stop().
