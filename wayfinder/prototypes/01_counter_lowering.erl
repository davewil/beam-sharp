%% PROTOTYPE — throwaway. The hand-written Erlang that §3 of 01-sample-code.md lowers to.
%%
%% Point of this file: prove the multi-clause showcase is not a sketch. Each beam-sharp
%% clause becomes one native Erlang clause head, guards included, and the result runs as a
%% real gen_server. Ticket 02 established the Abstract Format expresses this natively.
%%
%% Deliberately NO -behaviour attribute: ticket 06 found it has no runtime effect and that
%% neither Gleam nor purerl emits one. This module proves that empirically by working anyway.

-module('01_counter_lowering').
-export([start_link/1, increment/1, get/1, add/2, set/2, tick/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link(Start) -> gen_server:start_link(?MODULE, Start, []).

increment(P) -> gen_server:call(P, increment).
get(P)       -> gen_server:call(P, get).
add(P, M)    -> gen_server:call(P, {add, M}).
set(P, M)    -> gen_server:call(P, {set, M}).
tick(P)      -> P ! {tick, make_ref()}, ok.

init(Start) -> {ok, Start}.

%% One beam-sharp clause -> one Erlang clause head. Order and guards preserved verbatim.
handle_call(increment, _From, N)             -> {reply, N + 1, N + 1};
handle_call(get,       _From, N)             -> {reply, N, N};
handle_call({add, M},  _From, N) when M > 0  -> {reply, N + M, N + M};
handle_call({add, _},  _From, N)             -> {reply, N, N};
handle_call({set, M},  _From, _N)            -> {reply, M, M}.

handle_cast(_Msg, N) -> {noreply, N}.

%% The Known | dynamic split: proved arms first, then the arm the platform forces.
handle_info({tick, _Ref}, N)              -> {noreply, N + 1};
handle_info({'DOWN', _R, _T, _P, _I}, N)  -> {noreply, N};
handle_info(Other, N) ->
    io:format("  [warn] unexpected message: ~p~n", [Other]),
    {noreply, N}.
