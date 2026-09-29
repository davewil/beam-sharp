-module('Api').
-export(['New'/1, 'HTTPGet'/1, 'Get_X'/1]).
'New'(X) -> {new, X}.
'HTTPGet'(X) -> {http, X}.
'Get_X'(X) -> {getx, X}.
