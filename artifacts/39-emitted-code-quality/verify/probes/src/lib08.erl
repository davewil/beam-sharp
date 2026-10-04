-module(lib08).
-export([wrap/1, wrap_spec/1]).
%% Opaque to the caller (remote call): the analyser cannot see the body, so the return type is `any`.
wrap(N) -> ((N rem 100) + 100) rem 100.
-spec wrap_spec(integer()) -> 0..99.        %% the strongest fact a -spec can state
wrap_spec(N) -> ((N rem 100) + 100) rem 100.
