-module('14e_narrow_ok').
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2]).

-type state() :: #{balance := integer()}.

%% NARROWED RETURN: only {reply, integer(), state()} — a strict subset of the
%% six-way contract. This is ticket 12's worked signature in Erlang spelling.
-spec handle_call(term(), gen_server:from(), state()) ->
          {reply, integer(), state()}.
handle_call({withdraw, Amt}, _From, S = #{balance := B}) when Amt > 0, Amt =< B ->
    {reply, B - Amt, S#{balance := B - Amt}};
handle_call(balance, _From, S = #{balance := B}) ->
    {reply, B, S};
handle_call(_, _, _) ->
    erlang:error(bad_request).

-spec init(term()) -> {ok, state()}.
init(_) -> {ok, #{balance => 100}}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_, S) -> {noreply, S}.
