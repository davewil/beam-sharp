-module(ok).
-export([go/1]).
go(X) -> erldep:double(X).
