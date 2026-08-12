%%% PROTOTYPE 14b — what does a Gleam actor do with messages its type never mentions?
%%%
%%% Evidence for ticket 14. Observed locally 2026-08-12 on OTP 28 / Gleam 1.18.1,
%%% gleam_otp 1.3.0, gleam_erlang 1.3.0. Compiled against the actor in
%%% 14a_gleam_actor.gleam. Run: erlc into the gleam build ebin, then
%%%   erl -noshell -pa build/dev/erlang/*/ebin -eval '\'14b_gleam_mailbox_probe\':run()'
%%%
%%% RESULT (verbatim):
%%%   subject repr: {subject, <0.82.0>, #Ref<0.3027509567.2668888074.209948>}
%%%   =WARNING= Actor discarding unexpected message: SomeRandomTag(1, 2)
%%%   alive after raw tuple: true
%%%   =WARNING= Actor discarding unexpected message: Hello
%%%   alive after bare atom: true
%%%   alive after ill-typed payload: true
%%%   popped: 12345            <-- an integer out of a List(String), spec'd -> binary()
%%%   popped: <<"typed">>
%%%   alive at end: true

-module('14b_gleam_mailbox_probe').
-export([run/0]).

%% Probe: what does a Gleam actor do with messages its type never mentions?
run() ->
    Subject = g14:boot(),
    {subject, Pid, Tag} = Subject,
    io:format("subject repr: {subject, ~p, ~p}~n", [Pid, Tag]),

    %% 1. A well-typed message, sent the Gleam way.
    Pid ! {Tag, {push, <<"typed">>}},
    timer:sleep(50),

    %% 2. A raw message with no Subject tag at all — arrives from any Erlang caller.
    Pid ! {some_random_tag, 1, 2},
    timer:sleep(50),
    io:format("alive after raw tuple: ~p~n", [is_process_alive(Pid)]),

    %% 3. A bare atom — not even a tuple, so element(1, Msg) would badarg.
    Pid ! hello,
    timer:sleep(50),
    io:format("alive after bare atom: ~p~n", [is_process_alive(Pid)]),

    %% 4. A message with the RIGHT Subject tag but a payload the type forbids.
    %%    This is ticket 06's silent-unsoundness channel, aimed at a mailbox.
    Pid ! {Tag, {push, 12345}},
    timer:sleep(50),
    io:format("alive after ill-typed payload: ~p~n", [is_process_alive(Pid)]),

    %% 5. Ask the actor for its state: did the ill-typed payload land in it?
    Me = erlang:make_ref(),
    Pid ! {Tag, {pop, {subject, self(), Me}}},
    receive
        {Me, Reply} -> io:format("popped: ~p~n", [Reply])
    after 500 -> io:format("popped: TIMEOUT~n") end,

    Pid ! {Tag, {pop, {subject, self(), Me}}},
    receive
        {Me, Reply2} -> io:format("popped: ~p~n", [Reply2])
    after 500 -> io:format("popped: TIMEOUT~n") end,

    io:format("alive at end: ~p~n", [is_process_alive(Pid)]),
    init:stop().
