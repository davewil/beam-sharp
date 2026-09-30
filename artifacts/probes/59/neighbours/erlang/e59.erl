-module(e59).
-export([pub/1, use/1]).
-spec pub(integer()) -> integer().
pub(N) -> N + 1.
-spec priv(integer()) -> integer().
priv(N) -> N + 1.
use(N) -> priv(N).
