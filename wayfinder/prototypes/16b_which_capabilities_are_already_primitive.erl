%% 16b — Which of ticket 16's motivating capabilities are already primitive on the BEAM?
%%
%% Ticket 16 asks for a mechanism supporting "anything comparable", "anything with a
%% length", and "anything serialisable". Before designing one, measure how much of that
%% the runtime already supplies with no dispatch at all.
%%
%%   erlc -o /tmp/bs16 16b_which_capabilities_are_already_primitive.erl && erl -pa /tmp/bs16 \
%%     -eval "'16b_which_capabilities_are_already_primitive':main(), halt()." -noshell
%%
%% Observed on OTP 28 / erts 16.4 (local). Results are in the ticket; the headline is that
%% the three motivating capabilities land in three DIFFERENT buckets, and only one of them
%% wants generating.

-module('16b_which_capabilities_are_already_primitive').
-export([main/0]).

main() ->
    io:format("~n== 1. Comparison: is it total across unrelated types? ==~n"),
    %% Erlang defines one arbitrary but total order over ALL terms:
    %%   number < atom < reference < fun < port < pid < tuple < map < nil < list < bitstring
    Pairs = [{1, ok}, {ok, {1}}, {{1}, #{a => 1}}, {#{a => 1}, []},
             {[], [1]}, {[1], <<"x">>}, {self(), make_ref()}],
    [io:format("  ~-24s <  ~-24s => ~p~n", [f(A), f(B), A < B]) || {A, B} <- Pairs],
    io:format("  every pair compares without error, and nothing declared anything.~n"),
    io:format("  FINDING: \"anything comparable\" needs no mechanism. It is already total.~n"),

    io:format("~n== 2. Comparison: the number wrinkle ==~n"),
    io:format("  1 == 1.0  => ~p   (arithmetic equality, coerces across int/float)~n", [1 == 1.0]),
    io:format("  1 =:= 1.0 => ~p   (term equality, does not)~n", [1 =:= 1.0]),
    io:format("  1 <  1.0  => ~p   1.0 <  1 => ~p   -- so in the ORDER they are equal,~n",
              [1 < 1.0, 1.0 < 1]),
    io:format("  while =:= says they are not. Two equalities, and beam-sharp must pick~n"),
    io:format("  which one `==` spells.~n"),

    io:format("~n== 3. Length: one polymorphic function, or several monomorphic ones? ==~n"),
    Sizers = [{"length/1     (list)   ", fun() -> length([a, b, c]) end},
              {"byte_size/1  (binary) ", fun() -> byte_size(<<"abc">>) end},
              {"bit_size/1   (bitstr) ", fun() -> bit_size(<<1:3>>) end},
              {"map_size/1   (map)    ", fun() -> map_size(#{a => 1, b => 2}) end},
              {"tuple_size/1 (tuple)  ", fun() -> tuple_size({a, b, c}) end}],
    [io:format("  ~s => ~p~n", [Name, F()]) || {Name, F} <- Sizers],
    io:format("  length/1 on a binary => ~p~n", [t(fun() -> length(<<"abc">>) end)]),
    io:format("  size/1 exists but is NOT universal -- tuple and binary only:~n"),
    [io:format("    size/1 on ~-8s => ~p~n", [N, t(fun() -> size(X) end)])
     || {N, X} <- [{"tuple", {a,b,c}}, {"binary", <<"abc">>},
                   {"list", [a,b,c]}, {"map", #{a => 1}}]],
    io:format("  FINDING: five monomorphic names. \"anything with a length\" is a union~n"),
    io:format("  parameter with a clause each -- see 4, the guards already exist.~n"),

    io:format("~n== 4. Are the size functions guard-safe (usable in a clause head)? ==~n"),
    [io:format("  ~-28s => ~p~n", [f(X), guarded(X)])
     || X <- [<<"abcd">>, [a, b, c], #{a => 1}, 42]],
    io:format("  FINDING: yes. The clause head IS the dispatch, with no new machinery.~n"),

    io:format("~n== 5. Serialisation: is there a structure-derived encoder? ==~n"),
    T = #{order_id => 7, lines => [{sku, <<"A">>, 2}]},
    B = term_to_binary(T),
    io:format("  term_to_binary/1 round-trips any term => ~p (~p bytes)~n",
              [binary_to_term(B) =:= T, byte_size(B)]),
    io:format("  ...but that is the BEAM's own wire format, which nothing off-platform reads.~n"),
    io:format("  json:encode/1 (OTP 27+), by shape:~n"),
    [io:format("    ~-22s => ~p~n", [f(X), t(fun() -> iolist_to_binary(json:encode(X)) end)])
     || X <- [#{a => 1}, [1, 2, 3], <<"str">>, ok, 1.5, #{1 => a},
              {a, b}, #{k => {1, 2}}, [{a, 1}], T]],
    io:format("  FINDING: it fails on TUPLES, at any depth, and only at RUNTIME, with~n"),
    io:format("  {unsupported_type, Offender}. The tuple is beam-sharp's own workhorse --~n"),
    io:format("  ticket 09's newtype remedy and ticket 15's `(:error, E)` are both tuples --~n"),
    io:format("  so a large share of declared types are un-encodable by the platform encoder,~n"),
    io:format("  and the platform says so too late. THIS is the case that wants generating:~n"),
    io:format("  a ToJson<T> obligation reads the declared type and refuses at compile time.~n"),
    ok.

guarded(X) when is_binary(X), byte_size(X) > 2 -> {binary, byte_size(X)};
guarded(X) when is_list(X), length(X) > 2      -> {list, length(X)};
guarded(X) when is_map(X), map_size(X) >= 1    -> {map, map_size(X)};
guarded(_)                                     -> no_clause.

t(F) -> try F() of V -> V catch _:E -> {failed, E} end.
f(X) -> lists:flatten(io_lib:format("~p", [X])).
