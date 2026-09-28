-module(d3).
-export([exported_two/1, run/0]).
%% Dialyzer's treatment of a function whose every visible caller passes an atom, where the function has an
%% integer clause. Same body three times: exported, local, and local-with-its-address-taken.
exported_two(X) when is_integer(X) -> int;
exported_two(X) when is_atom(X)    -> atom.

local_two(X) when is_integer(X) -> int;
local_two(X) when is_atom(X)    -> atom.

escaped_two(X) when is_integer(X) -> int;
escaped_two(X) when is_atom(X)    -> atom.

run() ->
    A = exported_two(foo),
    B = local_two(foo),
    C = escaped_two(foo),
    F = fun escaped_two/1,     %% the address escapes: any caller anywhere may now apply it
    {A, B, C, F}.
