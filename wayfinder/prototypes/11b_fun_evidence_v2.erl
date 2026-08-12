-module(hotmod).
-export([f/1, make_closure/0, make_external/0]).
f(X) -> {v2, X}.
make_closure() -> fun(X) -> {v2, closure, X} end.
make_external() -> fun ?MODULE:f/1.
