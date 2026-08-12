-module(p27c).
-export([map_mono/2, misuse_mono/0]).

%% CONTROL: same shape, but ground types instead of type variables.
-spec map_mono([integer()], fun((integer()) -> binary())) -> [binary()].
map_mono(Xs, F) -> [F(X) || X <- Xs].

misuse_mono() ->
    Ys = map_mono([1,2,3], fun(X) -> integer_to_binary(X) end),
    hd(Ys) + 1.
