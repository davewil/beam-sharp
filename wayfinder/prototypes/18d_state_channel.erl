%%% PROTOTYPE 18d — the state channel, and what Erlang's own boundary check defends
%%%
%%% Ticket 18 §3. Two measurements the ticket turns on. Provenance: local, OTP 28.
%%%
%%% Reproduce:
%%%   erlc -o /tmp 18d_state_channel.erl
%%%   erl -pa /tmp -noshell -s '18d_state_channel' main -s init stop
%%%
%%% Recorded result (OTP 28):
%%%   -- sys:replace_state --
%%%   normal                     : 100
%%%   after sys:replace_state    : <<"lots">>
%%%     is_integer(that balance) : false
%%%   -- binary_to_term [safe] --
%%%   wrong-shaped term, [safe]  : {order,<<"7">>}      %% passes straight through
%%%   unknown atom, [safe]       : {error,badarg}       %% refused
%%%   unknown atom, no opts      : a_brand_new_atom_here
%%%
%%% WHY IT MATTERS. Ticket 14 §4 narrowed a callback's *request* argument to
%%% `term` by contravariance, but its own example still declares the STATE
%%% (`(:reply, int, Account) HandleCall(term, From, Account);`) and 14 never
%%% justified that position. sys:replace_state/2 is a documented OTP function any
%%% process can call, so the declared state type is violable — and note the
%%% callback's clause head `#account{balance = B} = S` MATCHED (tag and arity
%%% correct) and bound B bare. The tag/payload asymmetry a third time.
%%%
%%% It is also the one channel codegen cannot reach: OTP applies the supplied fun
%%% inside its own loop, which beam-sharp does not compile. Hence §3's named limit
%%% rather than a decision.
%%%
%%% The second measurement is the control on "does the platform defend anything?".
%%% binary_to_term/2 with [safe] is Erlang's only built-in boundary check, and it
%%% protects a RESOURCE (the atom table) not a CLAIM (the shape you expected).
-module('18d_state_channel').
-behaviour(gen_server).

-export([main/0]).
-export([start/0, balance/1, init/1, handle_call/3, handle_cast/2]).

-record(account, {id :: integer(), balance :: integer()}).

main() ->
    replace_state_probe(),
    safe_probe(),
    ok.

%% ---------------------------------------------------------------- the state channel

replace_state_probe() ->
    io:format("-- sys:replace_state --~n"),
    {ok, P} = start(),
    io:format("normal                     : ~p~n", [balance(P)]),
    %% any process may do this; nothing in the callback module is consulted
    sys:replace_state(P, fun(_Old) -> {account, <<"one">>, <<"lots">>} end),
    B = balance(P),
    io:format("after sys:replace_state    : ~p~n", [B]),
    io:format("  is_integer(that balance) : ~p~n", [is_integer(B)]),
    gen_server:stop(P).

start()     -> gen_server:start(?MODULE, [], []).
balance(P)  -> gen_server:call(P, balance).

init([]) -> {ok, #account{id = 1, balance = 100}}.

%% the state is DECLARED as an #account{} -- the beam-sharp equivalent of `Account`.
%% The head matches the tag and the arity; B is bound, never checked.
handle_call(balance, _From, #account{balance = B} = S) -> {reply, B, S}.

handle_cast(_Msg, S) -> {noreply, S}.

%% ------------------------------------------- what [safe] actually defends

safe_probe() ->
    io:format("-- binary_to_term [safe] --~n"),
    Bin = term_to_binary({order, <<"7">>}),
    io:format("wrong-shaped term, [safe]  : ~p~n", [binary_to_term(Bin, [safe])]),
    Evil = <<131, 100, 0, 21, "a_brand_new_atom_here">>,
    R = try binary_to_term(Evil, [safe]) catch C:E -> {C, E} end,
    io:format("unknown atom, [safe]       : ~p~n", [R]),
    io:format("unknown atom, no opts      : ~p~n", [binary_to_term(Evil)]).
