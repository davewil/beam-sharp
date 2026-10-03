-module(b).
-export([h/0]).
-include_lib("nosuch_app/include/x.hrl").   %% the ONE place Erlang source names an application
h() -> ok.
