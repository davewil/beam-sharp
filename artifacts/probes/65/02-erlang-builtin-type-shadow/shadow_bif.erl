-module(shadow_bif).
-export([f/1]).
length(_) -> mine.
f(X) -> length(X).
