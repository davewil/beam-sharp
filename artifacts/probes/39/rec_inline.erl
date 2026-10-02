-module(rec_inline).
-export([spin/1]).
-compile({inline,[{spin,1},{w,1}]}).
w(X) -> X rem 100.
spin(0) -> 0;
spin(N) -> spin(w(N) - 1 + (N-1)).
