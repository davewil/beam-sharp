-module(d3).
-export([exported_plus/1, run/0]).
%% Dialyzer's closed-world rule for LOCAL functions vs open-world for EXPORTED ones.
%% Same body, same only-caller, one exported and one local; and a third local that escapes as a fun.
exported_plus(X) -> X + 1.
local_plus(X) -> X + 1.
escaped_plus(X) -> X + 1.
run() ->
    A = exported_plus(foo),    %% exported fn called with an atom by its own module
    B = local_plus(foo),       %% local fn called only with an atom
    F = fun escaped_plus/1,    %% local fn whose address escapes...
    C = escaped_plus(foo),     %% ...and is also called with an atom locally
    {A, B, C, F}.
