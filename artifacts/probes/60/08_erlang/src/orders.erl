-module(orders).
-export([total/1, peek/1]).
-ignore_xref([{billing, round_, 1}]).
%% names the -moduledoc false module and the -doc false export
total(C) -> billing:ledger_post(C).
%% names a function billing does not export
peek(C) -> billing:round_(C).
