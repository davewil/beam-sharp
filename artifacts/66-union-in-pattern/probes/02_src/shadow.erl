-module(shadow).
-export([f/1]).
%% clause 2 is shadowed by clause 1: the "unreachable" shape (ticket 04's redundancy)
f(#{'Kind' := 'T.A'}) -> a;
f(#{'Kind' := 'T.A'}) -> a2;
f(#{'Kind' := 'T.B'}) -> b.
