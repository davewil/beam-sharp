-module(a).
-export([h/1]).
h(B) -> nosuch_dep:hash(B).      %% module not on any path, nothing named in source
