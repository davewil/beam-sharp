%%% Probe for ticket 39 sub-investigation #4 ("records and dispatch").
%%% Hand-written Erlang counterpart to ShapeBench.bs, matching beam-sharp's
%%% own record erasure exactly: a record is a map with a 'Kind' tag atom
%%% (verified against ShapeBench.beam's actual disassembly: `#{'Kind' =>
%%% 'ShapeBench.Circle', 'R' => R}`), dispatch is a `case` on that map,
%%% same loop shape, same field names.
-module(shape_bench_erl).
-export([grind/1]).

area(#{'Kind' := 'ShapeBench.Circle', 'R' := R}) -> R * R * 3;
area(#{'Kind' := 'ShapeBench.Square', 'S' := S}) -> S * S.

pick(0, N) -> #{'Kind' => 'ShapeBench.Circle', 'R' => N};
pick(_, N) -> #{'Kind' => 'ShapeBench.Square', 'S' => N}.

loop(0, Acc) -> Acc;
loop(Left, Acc) ->
    Shape = pick(Left rem 2, Left),
    loop(Left - 1, Acc + area(Shape)).

grind(Left) -> loop(Left, 0).
