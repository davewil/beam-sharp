-module(fold).
-export([g/1, p/1, e/1]).
g(X) when X >= -5 -> a;
g(X) when X >= 0-5 -> b;
g(X) when X >= 2+3 -> c;
g(X) when X >= 1 bsl 3 -> d;
g(X) when X >= (2+3)*-1 -> f;
g(_) -> z.
p(-5) -> a;
p(_) -> z.
e(X) -> X + -5.
