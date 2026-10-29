-module(b_int_unproved). -export([pub/1]).
pub(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
