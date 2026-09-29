-module(lib_a).
-export([pub/0]).
-export_type([pubt/0]).
-type pubt() :: integer().
-type privt() :: atom().
pub() -> priv().
priv() -> 1.
