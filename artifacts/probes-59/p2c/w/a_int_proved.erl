-module(a_int_proved). -export([pub/1]).
pub(X) when is_integer(X) -> priv(X).
priv(X) when is_integer(X) -> X + 1.
