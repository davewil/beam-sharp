-module(orpat_bad).
-export([f/1]).
%% NEGATIVE control: an or-pattern in a function head. Erlang has none.
f(#{kind := a, id := I} | #{kind := b, id := I}) -> I;
f(_) -> 0.
