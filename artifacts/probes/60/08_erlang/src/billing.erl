-module(billing).
-moduledoc false.
-export([charge/1, ledger_post/1]).
-doc false.
ledger_post(C) -> C + 1.
charge(C) -> round_(ledger_post(C)).
round_(C) -> C.
