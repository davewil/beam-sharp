-module(callee).
-export([f/1]).
f(X) -> {f, X, hidden(X)}.
hidden(X) -> X + 1.
