-module(mapget_helper).
-export([mk/1]).
mk(N) -> #{'Kind' => circle, 'R' => N}.
