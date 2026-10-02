-module(g).
-export([ge/1, pat/1, calc/1, rng/1, rng2/1, rng3/1, rng4/1]).
-define(LO, -5).
-type neg() :: -5..5.
-type calc() :: (1+1)..(2*3).
-type paren() :: -(5)..5.
-type sub() :: (0-5)..5.
-type mac() :: ?LO..5.
-spec ge(integer()) -> boolean().
ge(N) when N >= -5 -> true;
ge(_) -> false.
pat(-1) -> neg;
pat(_) -> other.
calc(N) when N >= 2 + 3 -> y;
calc(N) when N >= -(5) -> z;
calc(N) when N >= 0 - 5 -> w;
calc(_) -> n.
-spec rng(neg()) -> ok.
rng(_) -> ok.
-spec rng2(calc()) -> ok.
rng2(_) -> ok.
-spec rng3(paren()) -> ok.
rng3(_) -> ok.
-spec rng4(sub() | mac()) -> ok.
rng4(_) -> ok.
