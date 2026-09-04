%%% Probe for ticket 39 sub-decision 2 (causation test). spin/4 is IDENTICAL
%%% to bench_erl.erl's, except wrap/1 and hit/1 are called across a module
%%% boundary (xmod_a), which defeats the same-module SSA type fixpoint that
%%% gave probe_erl_spin.erl (and beam-sharp's real Day01.beam) the exact
%%% {t_integer,{0,99}}-style ranges measured in dump_s / beam_disasm output.
-module(xmod_b).
-export([spin_only/2]).

spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};
spin(Pos, Step, Left, Zeros) ->
    Next = xmod_a:wrap(Pos + Step),
    spin(Next, Step, Left - 1, Zeros + xmod_a:hit(Next)).

spin_only(Step, Left) -> spin(50, Step, Left, 0).
