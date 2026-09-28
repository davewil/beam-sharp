-module(d2).
-export([go/0, go_untyped/1, go_nested/0, go_nested_untyped/1, go_esc/0, go_esc_untyped/1]).
%% a FORGED value crossing the exported boundary of d1, from another module
go() -> d1:e(#{'Kind' => 'Invoice', total => 7, status => draft}).
%% the same value arriving through an untyped channel: Dialyzer sees term()
go_untyped(Bin) -> d1:e(binary_to_term(Bin)).
%% --- added after verification: callers that actually push a forged value through w/1 and esc() ---
go_nested() -> d1:w(#{'Kind' => 'Wrapper', order => #{'Kind' => 'Invoice', total => 7, status => draft}}).
go_nested_untyped(Bin) -> d1:w(#{'Kind' => 'Wrapper', order => binary_to_term(Bin)}).
go_esc() -> F = d1:esc(), F(#{'Kind' => 'Invoice', total => 7, status => draft}).
go_esc_untyped(Bin) -> F = d1:esc(), F(binary_to_term(Bin)).
