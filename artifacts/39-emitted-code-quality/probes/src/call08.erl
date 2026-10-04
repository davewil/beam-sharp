-module(call08).
-export([plain/1, spec/1, guard_int/1, guard_range/1, guard_range_cs/1, run/2]).
plain(X)  -> R = lib08:wrap(X), R + 1.
spec(X)   -> R = lib08:wrap_spec(X), R + 1.                       %% remote callee has -spec ... -> 0..99
%% what bsc emits at an FFI boundary today (ticket 18): is_integer only
guard_int(X) -> case lib08:wrap(X) of R when is_integer(R) -> R + 1 end.
%% the same with the interval B# knows (ticket 20 intervals) lowered to a guard
guard_range(X) -> case lib08:wrap(X) of R when is_integer(R), R >= 0, R =< 99 -> R + 1 end.
guard_range_cs(X) -> case lib08:wrap(X) of R when R >= 0, R =< 99 -> R + 1 end.   %% no is_integer (range test on a non-integer is false only for ints? see disasm)
run(F, N) -> run(F, N, 0).
run(_, 0, A) -> A;
run(F, N, A) -> run(F, N-1, A + call08:F(N)).
