-module(onload_mod).
-on_load(init/0).
-export([f/0]).
init() -> io:format("  [on_load ran: this is arbitrary code in the COMPILER's VM]~n"), ok.
f() -> 1.
