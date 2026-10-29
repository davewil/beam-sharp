-module(c_int_mixed). -export([pub/1,pub2/1]).
pub(X) when is_integer(X) -> priv(X).
pub2(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
