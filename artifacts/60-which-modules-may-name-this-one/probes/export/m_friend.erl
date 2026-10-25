-module(m_friend).
%% the only way to give SOME callers g/1 is to export it to ALL: the export table has no caller column
-export([f/1, g/1]).
f(X) -> g(X) + 1.
g(X) -> h(X) * 2.
h(X) -> X + 3.
