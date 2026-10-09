-module(billing).
-export([due/1]).
due(N) -> pricing:compute(N).
