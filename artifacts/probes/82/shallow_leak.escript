#!/usr/bin/env escript
%% ticket 82 Q2: does ticket 26 section 4's single top-level map_size test keep its promise at depth?  OTP 28.
%% Order { Id, Line: Line { Sku, Qty } }.  The value carries an UNDECLARED field inside the nested record.
main(_) ->
    Value = #{'Kind' => 'Nested.Order', 'Id' => 1,
              'Line' => #{'Kind' => 'Nested.Line', 'Sku' => 2, 'Qty' => 3, 'Secret' => 9}},
    TopOk = is_map(Value) andalso map_size(Value) =:= 3,
    io:format("top-level map_size test passes: ~p~n", [TopOk]),
    io:format("json:encode then publishes: ~s~n", [iolist_to_binary(json:encode(Value))]),
    io:format("B# deep validator (probes/82/Nested): ~s~n",
              [os:cmd("cd " ++ filename:dirname(escript:script_name()) ++ " && PATH=/opt/otp28/bin:$PATH "
                      "${BSC:-/tmp/dl/compiler-build/_build/default/bin/bsc} -o /tmp/dl/outN Nested Body "
                      "\"{ Kind = :'Nested.Order', Id = 1, Line = { Kind = :'Nested.Line', Sku = 2, Qty = 3, Secret = 9 } }\" 2>&1")]).
