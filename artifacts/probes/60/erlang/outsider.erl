-module(outsider).
-export([run/0]).
%% An arbitrary caller from "outside" calls the export and forges the opaque type.
run() -> {priv_mod:helper(), {secret, 1}, element(2, priv_mod:mk())}.
