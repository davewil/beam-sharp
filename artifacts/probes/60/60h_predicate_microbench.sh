#!/usr/bin/env bash
# PROBE 60h -- ticket 60 (ENG-242). 60g's wall-clock deltas sit inside run-to-run noise (row a'),
# so this isolates the predicate itself: the exact fun body proto_patch.py adds per `using` edge
# (lists:any over the callee's visible_to list, `=:=` or prefix on atom_to_list), run in one VM
# over 595 edges (the 60g project) x 1000 repetitions, with a 1-, 4- and 16-entry allow list.
# Control: the same loop with an always-false predicate that returns the opposite answer, proving
# the loop evaluates the predicate (result counts differ).
set -uo pipefail
erl -noshell -eval '
Self = list_to_atom("Gen.M150"),
Pred = fun(Allowed) -> lists:any(fun(A) -> Self =:= A orelse
              lists:prefix(atom_to_list(A) ++ ".", atom_to_list(Self)) end, Allowed) end,
Mk = fun(N) -> [list_to_atom("Other.X" ++ integer_to_list(I)) || I <- lists:seq(1,N-1)] ++ [list_to_atom("Gen")] end,
Edges = 595, Reps = 1000,
Run = fun(F) -> {T, C} = timer:tc(fun() ->
            lists:sum([ lists:sum([ case F() of true -> 1; false -> 0 end || _ <- lists:seq(1, Edges)]) || _ <- lists:seq(1, Reps)])
          end), {T / Reps, C div Reps} end,
[ begin L = Mk(N), {Us, Hits} = Run(fun() -> Pred(L) end),
        io:format("allow-list size ~2w: ~.1f us per 595-edge project, accepted ~w/595~n", [N, Us, Hits]) end || N <- [1,4,16] ],
{Us0, Hits0} = Run(fun() -> Pred([list_to_atom("Nobody")]) end),
io:format("CONTROL non-matching list : ~.1f us per 595-edge project, accepted ~w/595~n", [Us0, Hits0]),
halt().'
