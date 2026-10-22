-module(shadow_bif_optout).
-export([f/1]).
-compile({no_auto_import, [length/1]}).
length(_) -> mine.
f(X) -> length(X).
