-module('14e_bogus_ret').
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2]).

-type state() :: #{balance := integer()}.
-type request() :: {withdraw, integer()} | balance.

%% NARROWED ARGUMENT: claims to accept only request(), not term().
%% Contravariance says this is unsound — OTP will call it with any term.
-spec handle_call(request(), gen_server:from(), state()) ->
          {bogus, integer()}.
handle_call({withdraw, Amt}, _From, S = #{balance := B}) when Amt > 0, Amt =< B ->
    {bogus, B - Amt};
handle_call(balance, _From, S = #{balance := B}) ->
    {bogus, B}.

-spec init(term()) -> {ok, state()}.
init(_) -> {ok, #{balance => 100}}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_, S) -> {noreply, S}.
