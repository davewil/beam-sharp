-module(p4_spec).
-export([untagged/0, tagged/0, use_untagged/0, use_tagged/0, use_tagged_exhaustive/0]).

-spec untagged() -> term() | nothing.          %% option<term>, bare
untagged() -> persistent_term:get(untagged_key).

-spec tagged() -> {ok, term()} | absent.       %% 48's (:ok, V) | :absent
tagged() -> persistent_term:get(tagged_key).

%% a clause the author wrote believing it distinguishes a case that cannot occur
use_untagged() ->
    case untagged() of
        nothing -> a;
        {error, _} -> b;     %% reachable: term() contains every tuple
        _ -> c
    end.

use_tagged() ->
    case tagged() of
        absent -> a;
        {error, _} -> b;     %% unreachable: spec says only {ok,_} | absent
        {ok, _} -> c
    end.

%% a clause for a value the spec cannot return: `nothing`-vs-term clause ordering
use_tagged_exhaustive() ->
    case tagged() of
        absent -> a;
        {ok, _} -> c
    end.
