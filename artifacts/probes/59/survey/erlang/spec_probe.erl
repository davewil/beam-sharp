-module(spec_probe).
-export([pub/1, via_priv/1]).
%% A -spec on an exported and on a local function: neither is checked at run time.
-spec pub(integer()) -> integer().
pub(N) -> N + 1.
-spec priv(integer()) -> integer().
priv(N) -> N + 1.
-spec via_priv(integer()) -> integer().
via_priv(N) -> priv(N).
