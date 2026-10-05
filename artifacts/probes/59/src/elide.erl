%% Plain-Erlang counterpart of ticket 18's section 4 elision claims (18a e_ex / e_lo / e_un),
%% plus the record-tag analogue 18a did not measure.
-module(elide).
-export([ex_caller/1, ex_f/1, lo_caller/1, un_caller/1, tag_caller/1]).

%% (a) EXPORTED guarded callee, called locally with a proven integer
ex_f(N) when is_integer(N) -> N + 1.
ex_caller(X) when is_integer(X) -> ex_f(X).

%% (b) PRIVATE guarded callee; its only caller has already proven is_integer
lo_f(N) when is_integer(N) -> N + 1.
lo_caller(X) when is_integer(X) -> lo_f(X).

%% (c) PRIVATE guarded callee; caller passes an unknown term
un_f(N) when is_integer(N) -> N + 1.
un_caller(X) -> un_f(X).

%% (d) PRIVATE callee with a record-tag test; its only caller has just run the identical test
tag_f(O) when map_get('Kind', O) =:= 'Order' -> map_get('Total', O).
tag_caller(O) when map_get('Kind', O) =:= 'Order' -> tag_f(O).
