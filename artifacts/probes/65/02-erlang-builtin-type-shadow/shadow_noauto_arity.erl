-module(shadow_noauto_arity).
-export([f/1]).
%% a user type that merely shares a NAME with a builtin but not its arity
-type integer(A) :: {int, A}.
-spec f(integer(atom())) -> ok.
f(_) -> ok.
