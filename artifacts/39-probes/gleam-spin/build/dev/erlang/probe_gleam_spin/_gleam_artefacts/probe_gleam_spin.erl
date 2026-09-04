-module(probe_gleam_spin).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([spin_only/2]).

-file("src/probe_gleam_spin.gleam", 4).
-spec wrap(integer()) -> integer().
wrap(N) ->
    ((N rem 100) + 100) rem 100.

-file("src/probe_gleam_spin.gleam", 8).
-spec hit(integer()) -> integer().
hit(N) ->
    case N of
        0 ->
            1;

        _ ->
            0
    end.

-file("src/probe_gleam_spin.gleam", 15).
-spec spin(integer(), integer(), integer(), integer()) -> {integer(), integer()}.
spin(Pos, Step, Left, Zeros) ->
    case Left of
        0 ->
            {Pos, Zeros};

        _ ->
            Next = wrap(Pos + Step),
            spin(Next, Step, Left - 1, Zeros + hit(Next))
    end.

-file("src/probe_gleam_spin.gleam", 25).
-spec spin_only(integer(), integer()) -> {integer(), integer()}.
spin_only(Step, Left) ->
    spin(50, Step, Left, 0).
