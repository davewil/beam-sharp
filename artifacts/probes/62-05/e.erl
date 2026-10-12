-module(e).
-export(['New'/1, 'GetById'/1, new/1]).
-spec 'New'(integer()) -> {new, integer()}.
'New'(X) -> {new, X}.
'GetById'(X) -> {get, X}.
new(X) -> 'New'(X).
