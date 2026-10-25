-module(m_one).
-export([f/1]).
f(X) -> g(X) + 1.
g(X) -> h(X) * 2.
h(X) -> X + 3.
