-module(fib_erl).
-export([fib/1]).

%% Transliterated from examples/fib.bs, including its hand-written reverse —
%% `lists:reverse/1` is a BIF and would be measuring OTP rather than the emitter.
fib(N) when N =< 0 -> [];
fib(N) when N > 0 -> series(N, 0, 1, []).

series(N, _A, _B, Acc) when N =< 0 -> reverse(Acc, []);
series(N, A, B, Acc) when N > 0 -> series(N - 1, B, A + B, [A | Acc]).

reverse([], Acc) -> Acc;
reverse([X | Rest], Acc) -> reverse(Rest, [X | Acc]).
