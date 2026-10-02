-module('Elixir.Req').
-export([new/1]).
-on_load(boot/0).
boot() -> io:format("ON_LOAD RAN (a compile-time ensure_loaded executed foreign code)~n"), ok.
new(O) -> {req_request, O}.
