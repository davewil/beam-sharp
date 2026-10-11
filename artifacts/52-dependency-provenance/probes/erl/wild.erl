-module(wild).
-export([go/0]).
-application(some_app).   %% is there an Erlang `-application` attribute? (no: this is just a wild attribute)
go() -> ok.
