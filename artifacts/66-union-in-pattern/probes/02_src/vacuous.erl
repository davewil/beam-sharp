-module(vacuous).
-export([bad/1]).
%% exemplar 5's shape: declared input is A|B, clause 2 is a member of neither
-type a() :: #{'Kind' := 'T.A'}.
-type b() :: #{'Kind' := 'T.B'}.
-type c() :: a() | b().
-spec bad(c()) -> atom().
bad(#{'Kind' := 'T.A'}) -> a;
bad(#{'Kind' := 'T.B'}) -> b;
bad(#{'Kind' := 'T.E'}) -> e.
