-module(fc17).
-export([run/1, run_exported_callee/1, g/1]).
f(1) -> a;
f(2) -> b.
run(X) -> {ok, f(X)}.
g(1) -> a;
g(2) -> b.
run_exported_callee(X) -> {ok, g(X)}.
