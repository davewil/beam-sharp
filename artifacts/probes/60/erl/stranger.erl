-module(stranger).
%% Unrelated to callee: no shared app, no shared prefix, no declaration of any kind.
-export([static/1, dynamic/3, via_apply/1]).
static(X) -> callee:f(X).
dynamic(M, F, A) -> M:F(A).
via_apply(X) -> apply(list_to_atom("callee"), list_to_atom("f"), [X]).
