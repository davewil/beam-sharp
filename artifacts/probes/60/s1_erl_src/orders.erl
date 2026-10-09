-module(orders).
-export([total/1]).
total(N) -> pricing:compute(N) + 1.
