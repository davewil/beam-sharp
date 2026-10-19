#!/usr/bin/env escript
%% ticket 82 Q1: what each candidate failure looks like to a supervisor/log, and how big it is.  OTP 28.
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Bad = #{'Kind' => 'Orders.Order', 'Id' => 1, 'Total' => 5, 'Secret' => 7},
    Shipped = catch_it(fun() -> 'Orders':'OrderBody'(Bad) end),
    FC = catch_it(fun() -> shape_fc(Bad) end),
    Enc = catch_it(fun() -> json:encode(#{a => self()}) end),
    [io:format("~-34s class=~w  reason-size=~5w B  ~P~n",
               [Name, C, byte_size(term_to_binary(R)), R, 14])
     || {Name, {C, R}} <- [{"shipped: error({to_json, VErr})", Shipped},
                            {"bare function_clause", FC},
                            {"json:encode on a pid (OTP's own)", Enc}]].
shape_fc(X) -> erlang:error(function_clause, [X]).
catch_it(F) -> try F(), ok catch C:R -> {C, R} end.
