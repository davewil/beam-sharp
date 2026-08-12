%%% PROTOTYPE 14c — a NAMED Gleam subject's tag is a registered atom, not a ref.
%%%
%%% Evidence for ticket 14. Observed locally 2026-08-12 on OTP 28 / Gleam 1.18.1.
%%% Anonymous subjects carry an unguessable make_ref() tag, so a foreign sender
%%% cannot forge a well-typed message. Gleam's own remedy for passing subjects
%%% around -- process.new_name/1 + actor.named -- replaces that ref with a
%%% registered atom, which registered()/0 enumerates.
%%%
%%% RESULT (verbatim):
%%%   name returned to Gleam caller: 'stack$1123'
%%%   discovered by registered()/0 diff: ['stack$1123']
%%%   alive after forged push: true
%%%   popped: {forged,from,erlang}   <-- forged term out of a List(String)
%%%   alive at end: true

-module('14c_gleam_named_forgery').
-export([run/0]).

%% Probe 3: a NAMED subject's tag is a registered atom, not an unguessable ref.
%% Can a foreign Erlang process discover it and forge a well-typed-looking message?
run() ->
    Before = registered(),
    Name = g14:boot_named(),
    io:format("name returned to Gleam caller: ~p~n", [Name]),

    %% Discover the name knowing nothing: just diff the registry.
    Discovered = [N || N <- registered(), not lists:member(N, Before)],
    io:format("discovered by registered()/0 diff: ~p~n", [Discovered]),

    [Found | _] = Discovered,
    Pid = whereis(Found),

    %% Forge a message using only the discovered atom. No ref needed.
    Found ! {Found, {push, {forged, from, erlang}}},
    timer:sleep(50),
    io:format("alive after forged push: ~p~n", [is_process_alive(Pid)]),

    Me = erlang:make_ref(),
    Found ! {Found, {pop, {subject, self(), Me}}},
    receive {Me, R} -> io:format("popped: ~p~n", [R])
    after 500 -> io:format("popped: TIMEOUT~n") end,
    io:format("alive at end: ~p~n", [is_process_alive(Pid)]),
    init:stop().
