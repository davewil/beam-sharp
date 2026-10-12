-module(entry).
-export([ex/1, local_caller/1, remote_caller/1]).
%% ex/1 is exported AND called locally AND called remotely: how many entries does it have?
ex(X) when is_integer(X) -> X + 1.
local_caller(Y)  -> ex(Y) + 1.
remote_caller(Y) -> entry:ex(Y) + 1.
