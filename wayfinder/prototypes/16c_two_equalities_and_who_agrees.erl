%% 16c — Erlang has two equalities. Which one does the rest of the platform agree with?
%%
%% Ticket 16 must pick what beam-sharp's `==` means. Erlang offers `==` (coerces integer
%% against float) and `=:=` (does not). The interesting question is not which is more
%% familiar to a C#/TS reader, but which one the constructs beam-sharp is BUILT ON already
%% agree with — because the clause head is the headline feature, and a guard that disagrees
%% with the head above it is a defect the language would ship on purpose.
%%
%%   erlc -o /tmp/bs16 16c_two_equalities_and_who_agrees.erl && erl -pa /tmp/bs16 \
%%     -eval "'16c_two_equalities_and_who_agrees':main(), halt()." -noshell
%%
%% Observed on OTP 28 / erts 16.4 (local).

-module('16c_two_equalities_and_who_agrees').
-export([main/0]).

main() ->
    io:format("~n== 1. How deep does the ==/=:= disagreement go? ==~n"),
    [io:format("  ~-26s  == => ~-5w  =:= => ~w~n", [f(A) ++ " vs " ++ f(B), A == B, A =:= B])
     || {A, B} <- [{1, 1.0},
                   {{1}, {1.0}},
                   {[1], [1.0]},
                   {#{a => 1}, #{a => 1.0}},     %% map VALUE
                   {#{1 => a}, #{1.0 => a}},     %% map KEY
                   {1, ok}]],
    io:format("  FINDING: the coercion runs deep through tuples, lists and map VALUES --~n"),
    io:format("  and then stops dead at map KEYS. `==` is not consistently coercing even~n"),
    io:format("  within itself.~n"),

    io:format("~n== 2. Does a CLAUSE HEAD coerce, the way `==` does? ==~n"),
    [io:format("  head_match(~-5s) => ~p~n", [f(X), head_match(X)]) || X <- [1, 1.0]],
    io:format("  FINDING: no. Pattern matching is =:=. The headline feature of this~n"),
    io:format("  language already picked a side, and it is the exact one.~n"),

    io:format("~n== 3. Does a map KEY lookup coerce? ==~n"),
    M = #{1 => int_key},
    io:format("  maps:get(1,   #{1 => int_key}) => ~p~n", [t(fun() -> maps:get(1, M) end)]),
    io:format("  maps:get(1.0, #{1 => int_key}) => ~p~n", [t(fun() -> maps:get(1.0, M) end)]),
    io:format("  FINDING: no. Also =:=.~n"),

    io:format("~n== 4. So who actually uses the coercing `==`? ==~n"),
    io:format("  Only the operator itself, and `<`/`>` -- where 1 and 1.0 compare EQUAL:~n"),
    io:format("    1 < 1.0 => ~w    1.0 < 1 => ~w    (neither: they tie)~n", [1 < 1.0, 1.0 < 1]),
    io:format("    1 =:= 1.0 => ~w  -- so the ORDER and TERM EQUALITY disagree too.~n",
              [1 =:= 1.0]),
    io:format("  CONCLUSION for ticket 16: `==` spelling `=:=` puts the operator in~n"),
    io:format("  agreement with clause heads and map keys, i.e. with two constructs, and~n"),
    io:format("  in disagreement with none. The reverse choice disagrees with both.~n"),
    ok.

head_match(1) -> matched_the_integer_clause;
head_match(_) -> fell_through.

t(F) -> try F() of V -> V catch _:E -> {failed, E} end.
f(X) -> lists:flatten(io_lib:format("~p", [X])).
