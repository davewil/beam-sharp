-module(priv_mod).
-export([helper/0, mk/0]).
-export_type([t/0]).
-opaque t() :: {secret, integer()}.
%% Intended as "internal to app shop": nothing here says so to the compiler.
-spec helper() -> integer().
helper() -> 42.
-spec mk() -> t().
mk() -> {secret, 7}.
