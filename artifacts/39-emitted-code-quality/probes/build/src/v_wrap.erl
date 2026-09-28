%%% loop.erl -- one source, many compile-time variants of the AoC-2025 Day-01 part-two hot loop.
%%% Shape copied from aoc/bench/bench_erl.erl (baseline) and aoc/bench/Day01/bench_bs.bs.
%%% Variants are selected by -D macros (see run.sh); MOD names the module.
%%%
%%%   (none)     baseline: private helpers, part_two/1 the only export.  == bench_erl.erl
%%%   BSSHAPE    Sign/Size clause forms and order as B# writes them in Day01/bench_bs.bs
%%%              (`Sign(d) when d < 0`, `Sign(d) when d >= 0`, ...). Hit/Spin/Wrap unchanged.
%%%   EXPORTALL  every function exported => beam_ssa_type must assume `any` args (SOURCE
%%%              beam_ssa_type.erl:119-121,438-441). Removes call-site inference, changes no instruction.
%%%   GUARD_IS   EXPORTALL + is_integer(P) on the hot params only.
%%%   GUARD_RNG  EXPORTALL + is_integer(P), P>=0, P=<99 on Pos/N (a "range-narrowing guard").
%%%   WRAP       spin/4 EXPORTED with the F37-style boundary guard (is_integer, >=0, =<99), body moved to a PRIVATE
%%%              worker spin_w/4 that recurses without guards (the option-2 shape: guard once, not per iteration).
%%%   REMOTE     wrap/1 written with the remote-call spelling erlang:rem/2 that B# FFI emits (`:erlang.rem`).
%%%   SPEC_WIDE  what bs_emit does for every function (ticket 13): -spec with integer() everywhere (no range).
%%%   BSATOMS    adds the exported 'bs@type_atoms'/0 that bs_emit adds to every module (bs_emit.erl:72-75).
%%%   SPEC       EXPORTALL + tight -spec ranges (spin(0..99, -1..1, ...), wrap(integer())->0..99)
-module(?MOD).
-export([part_two/1]).
-ifdef(WRAP).
-export([spin/4]).
-endif.
-ifdef(EXPORTALL).
-compile([export_all, nowarn_export_all]).
-endif.

-ifdef(BSATOMS).
-export(['bs@type_atoms'/0]).
'bs@type_atoms'() -> #{}.
-endif.

-ifdef(SPEC_WIDE).
-spec wrap(integer()) -> integer().
-spec hit(integer()) -> integer().
-spec spin(integer(), integer(), integer(), integer()) -> {integer(), integer()}.
-spec sign(integer()) -> integer().
-spec size_(integer()) -> integer().
-spec clicks([integer()], integer(), integer()) -> integer().
-spec part_two([integer()]) -> integer().
-endif.

-ifdef(SPEC).
-spec wrap(integer()) -> 0..99.
-spec spin(0..99, -1..1, non_neg_integer(), non_neg_integer()) -> {0..99, non_neg_integer()}.
-endif.

-ifdef(REMOTE).
wrap(N) -> erlang:'rem'(erlang:'rem'(N, 100) + 100, 100).
-else.
-ifdef(GUARD_RNG).
wrap(N) when is_integer(N), N >= -99, N =< 199 -> ((N rem 100) + 100) rem 100.
-else.
-ifdef(GUARD_IS).
wrap(N) when is_integer(N) -> ((N rem 100) + 100) rem 100.
-else.
wrap(N) -> ((N rem 100) + 100) rem 100.
-endif.
-endif.
-endif.

hit(0) -> 1;
hit(_) -> 0.

-ifdef(WRAP).
spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99 -> spin_w(Pos, Step, Left, Zeros).
spin_w(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin_w(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin_w(Next, Step, Left - 1, Zeros + hit(Next)).
-else.
-ifdef(GUARD_RNG).
spin(Pos, _Step, 0, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99 -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99 ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
-else.
-ifdef(GUARD_IS).
spin(Pos, _Step, 0, Zeros) when is_integer(Pos) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) when is_integer(Pos) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
-else.
spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + hit(Next)).
-endif.
-endif.
-endif.

-ifdef(BSSHAPE).
sign(D) when D < 0 -> -1;
sign(D) when D >= 0 -> 1.
size_(D) when D < 0 -> -D;
size_(D) when D >= 0 -> D.
-else.
sign(0) -> 1;
sign(D) when D > 0 -> 1;
sign(D) when D < 0 -> -1.
size_(D) when D >= 0 -> D;
size_(D) when D < 0 -> -D.
-endif.

clicks([], _Pos, Zeros) -> Zeros;
clicks([D | Rest], Pos, Zeros) ->
    {Next, Hits} = spin(Pos, sign(D), size_(D), Zeros),
    clicks(Rest, Next, Hits).

part_two(Rs) -> clicks(Rs, 50, 0).
