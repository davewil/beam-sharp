-module(useapp).
-export([go/0, go2/0]).
go() -> 'Elixir.Req':new([]).        %% module in no listed app, nowhere on disk
go2() -> ssl:start().                 %% real OTP app (ssl) NOT in applications
