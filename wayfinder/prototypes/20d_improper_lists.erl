%%% 20d — Is `list<T>` decidable at ticket 18 §2's boundary?
%%%
%%% Ticket 18 §2 used `list<term>` as the shape `list<Order>` degrades to when
%%% it crosses an FFI boundary, on the grounds that a list is O(1)-decidable.
%%% It is not — not if `list<T>` means a *proper* list.
%%%
%%%     is_list/1 returns true for improper lists.
%%%
%%% The only guard that rejects one is length/1, which is O(n) and raises
%%% badarg (in guard position, a raising BIF simply fails the guard, so
%%% `when length(L) >= 0` IS a properness test — an O(n) one).
%%%
%%% This does NOT break ticket 18's guarantee. The guarantee is "a foreign term
%%% that breaks your types will crash — not always where it entered, but never
%%% silently", and an improper list crashes with function_clause inside the
%%% recursion ticket 17 adopted. Outcome 1-or-2, never outcome 3.
%%%
%%% Run: erlc -o . 20d_improper_lists.erl
%%%      erl -noshell -pa . -eval "'20d_improper_lists':run(),halt()."
%%%
%%% Measured on OTP 28.5, 2026-08-13.

-module('20d_improper_lists').
-export([run/0, map/2]).

%% The lowering ticket 17 §2 adopted for a compiler-known collection operation:
%% inlined monomorphic recursion, not a call to lists:map/2.
map([],      _) -> [];
map([H | T], F) -> [F(H) | map(T, F)].

run() ->
    Proper   = [1, 2, 3],
    Improper = [1, 2 | 3],

    io:format("=== the only O(1) list guard admits improper lists ===~n"),
    io:format("is_list([1,2,3])  : ~p~n", [is_list(Proper)]),     % true
    io:format("is_list([1,2|3])  : ~p  <-- passes~n", [is_list(Improper)]), % true
    io:format("hd/tl work on it  : ~p / ~p~n", [hd(Improper), tl(Improper)]), % 1 / [2|3]
    io:format("length([1,2|3])   : ~p~n", [element(1, catch length(Improper))]), % EXIT badarg

    io:format("~n=== so what happens when one crosses? ===~n"),
    io:format("proper   : ~p~n", [catch map(Proper, fun(X) -> X * 2 end)]),
    %% => [2,4,6]
    R = catch map(Improper, fun(X) -> X * 2 end),
    io:format("improper : ~p / ~p~n", [element(1, R), element(1, element(2, R))]),
    %% => 'EXIT' / function_clause
    %%
    %% A crash, not a wrong answer. 3 matches neither [] nor [_|_], so the
    %% recursion has no clause for it — which is exactly ticket 12's retained
    %% failure arm doing its job. Ticket 18's guarantee holds; the crash is
    %% deferred from the boundary to the traversal, and never silent.
    %%
    %% Hence ticket 20's disposition: improper lists are a NAMED LIMIT, the
    %% same device ticket 18 used for sys:replace_state/2 — not a modelled
    %% shape, and not a hole in the guarantee.
    ok.
