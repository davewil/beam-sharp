-module(rogue).
-export([tail/1, body/1, body_looks_nontail/1]).
tail(X) -> who:checked(X).                 %% illegitimate caller, tail position: its own frame is gone
body(X) -> Y = who:checked(X), {ok, Y}.    %% illegitimate caller, genuinely non-tail: frame visible
body_looks_nontail(X) -> Y = who:checked(X), Y.   %% reads as non-tail; erlc rewrites it to a tail call
