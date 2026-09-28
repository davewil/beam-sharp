-module(d2).
-export([go/0, go_untyped/1]).
%% a FORGED value crossing the exported boundary of d1, from another module
go() -> d1:e(#{'Kind' => 'Invoice', total => 7, status => draft}).
%% the same value arriving through an untyped channel: Dialyzer sees term()
go_untyped(Bin) -> d1:e(binary_to_term(Bin)).
