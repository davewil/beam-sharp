-module(bench_gleam).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([part_two/1]).

-file("src/bench_gleam.gleam", 1).
-spec wrap(integer()) -> integer().
wrap(N) ->
    ((N rem 100) + 100) rem 100.

-file("src/bench_gleam.gleam", 5).
-spec hit(integer()) -> integer().
hit(N) ->
    case N of
        0 ->
            1;

        _ ->
            0
    end.

-file("src/bench_gleam.gleam", 12).
-spec spin(integer(), integer(), integer(), integer()) -> {integer(), integer()}.
spin(Pos, Step, Left, Zeros) ->
    case Left of
        0 ->
            {Pos, Zeros};

        _ ->
            Next = wrap(Pos + Step),
            spin(Next, Step, Left - 1, Zeros + hit(Next))
    end.

-file("src/bench_gleam.gleam", 22).
-spec sign(integer()) -> integer().
sign(D) ->
    case D < 0 of
        true ->
            -1;

        false ->
            1
    end.

-file("src/bench_gleam.gleam", 29).
-spec size_(integer()) -> integer().
size_(D) ->
    case D < 0 of
        true ->
            - D;

        false ->
            D
    end.

-file("src/bench_gleam.gleam", 36).
-spec clicks(list(integer()), integer(), integer()) -> integer().
clicks(Rs, Pos, Zeros) ->
    case Rs of
        [] ->
            Zeros;

        [D | Rest] ->
            {Next, Hits} = spin(Pos, sign(D), size_(D), Zeros),
            clicks(Rest, Next, Hits)
    end.

-file("src/bench_gleam.gleam", 46).
-spec part_two(list(integer())) -> integer().
part_two(Rs) ->
    clicks(Rs, 50, 0).
