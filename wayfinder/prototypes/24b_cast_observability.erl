%%% 24b — Can a boundary test observe a `cast`, and does sys:get_state buy anything?
%%%
%%% Ticket 24 decision 1 makes the client API against a live process the test boundary.
%%% That immediately raises: a fire-and-forget cast has no reply to synchronise on, so what
%%% does a test await? Two candidates — a following client-API `call`, or `sys:get_state/1`
%%% reaching past the API into the state.
%%%
%%% This measures whether either is actually deterministic, and whether sys:get_state buys
%%% any determinism the client API does not already have. The cast handler sleeps, so a
%%% racing observer sees the pre-cast state and the run fails loudly rather than passing by
%%% luck on a fast machine.
%%%
%%% Run:  erlc -o /tmp 24b_cast_observability.erl && erl -noshell -pa /tmp -s 24b_cast_observability run -s init stop
-module('24b_cast_observability').
-behaviour(gen_server).

-export([run/0]).
-export([start_link/0, note/2, fetch/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-define(REPS, 200).
-define(HANDLER_WORK_MS, 5).
-define(HEAD_START_MS, 20).

%%% ---- the aggregate: one cast in, one call to observe it ----

start_link() -> gen_server:start_link(?MODULE, [], []).

note(Pid, N)  -> gen_server:cast(Pid, {note, N}).   % fire and forget
fetch(Pid)    -> gen_server:call(Pid, fetch).       % the client API's observation

init([]) -> {ok, []}.

handle_cast({note, N}, S) ->
    timer:sleep(?HANDLER_WORK_MS),                  % make a race lose, not flake
    {noreply, [N | S]}.

handle_call(fetch, _From, S) -> {reply, S, S}.

%%% ---- probes ----

run() ->
    io:format("~n=== 24b: observing a cast at the test boundary ===~n"),
    io:format("~p reps each, handler sleeps ~pms~n", [?REPS, ?HANDLER_WORK_MS]),

    io:format("~n1. same process: cast then client-API call~n"),
    report(repeat(fun same_proc_call/0)),

    io:format("~n2. same process: cast then sys:get_state/1~n"),
    report(repeat(fun same_proc_sys/0)),

    io:format("~n3. DIFFERENT processes: A casts, B calls (no pairwise ordering to lean on)~n"),
    report(repeat(fun cross_proc/0)),

    io:format("~n3b. POSITIVE CONTROL: caller given a ~pms head start — this MUST miss.~n",
              [?HEAD_START_MS]),
    io:format("    If it does not, probes 1-3 prove nothing and the harness is broken.~n"),
    report(repeat(fun cross_proc_head_start/0)),

    io:format("~n4. does sys:get_state see state the client API cannot?~n"),
    hidden_state(),
    ok.

repeat(F) ->
    lists:foldl(fun(_, {Ok, Bad}) ->
        case F() of
            ok  -> {Ok + 1, Bad};
            bad -> {Ok, Bad + 1}
        end
    end, {0, 0}, lists:seq(1, ?REPS)).

report({Ok, Bad}) ->
    io:format("   observed: ~p/~p    missed: ~p/~p~n", [Ok, ?REPS, Bad, ?REPS]).

same_proc_call() ->
    {ok, P} = start_link(),
    note(P, 1),
    R = fetch(P),
    stop(P),
    check(R).

same_proc_sys() ->
    {ok, P} = start_link(),
    note(P, 1),
    R = sys:get_state(P),
    stop(P),
    check(R).

%% The cast is sent by a *different* process from the one that calls, with NO happens-before
%% between them: both wait on a barrier and the caller is released first, so the ordering
%% guarantee has nothing to bite on.
%%
%% A first version of this probe had the caster signal the main process before the main
%% process called, which is a causal chain — it reported 200/200 like the others and so
%% could not have detected a miss if one existed. That is this ticket's own §"testing trap"
%% (a precondition the harness removes) reproduced while measuring it, and it is recorded
%% because it was plausible and would have been believed.
cross_proc() ->
    {ok, P} = start_link(),
    Me = self(),
    Caster = spawn(fun() -> receive go -> note(P, 1), Me ! done end end),
    Caller = spawn(fun() -> receive go -> Me ! {result, fetch(P)} end end),
    Caller ! go,                                     % released FIRST — bias toward a miss
    Caster ! go,
    R = receive {result, X} -> X after 5000 -> timeout end,
    receive done -> ok after 5000 -> ok end,
    stop(P),
    check(R).

%% Positive control. The caller is released and given a clear head start, so its call MUST
%% reach the server's mailbox before the cast does and MUST observe the pre-cast state.
%% Its job is to prove the harness can record a miss at all — without it, 200/200 everywhere
%% is indistinguishable from a probe that cannot fail.
cross_proc_head_start() ->
    {ok, P} = start_link(),
    Me = self(),
    Caster = spawn(fun() -> receive go -> note(P, 1), Me ! done end end),
    Caller = spawn(fun() -> receive go -> Me ! {result, fetch(P)} end end),
    Caller ! go,
    timer:sleep(?HEAD_START_MS),
    Caster ! go,
    R = receive {result, X} -> X after 5000 -> timeout end,
    receive done -> ok after 5000 -> ok end,
    stop(P),
    check(R).

check([1]) -> ok;
check([])  -> bad.

%% A field the client API never exposes: fetch/1 returns only the note list.
hidden_state() ->
    {ok, P} = start_link(),
    note(P, 1),
    Api = fetch(P),
    Sys = sys:get_state(P),
    io:format("   client API returns: ~p~n", [Api]),
    io:format("   sys:get_state      : ~p~n", [Sys]),
    io:format("   identical? ~p~n", [Api =:= Sys]),
    stop(P).

stop(P) ->
    unlink(P),
    exit(P, kill),
    ok.
