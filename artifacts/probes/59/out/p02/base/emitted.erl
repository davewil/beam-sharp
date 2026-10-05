-module('Deep').
-export(['Top'/1,
         'SumTotals'/1,
         'SumWeights'/1,
         'WeightPub'/1,
         'Doubled'/1,
         bs@type_atoms/0]).
bs@type_atoms() ->
    ['Deep.Invoice', 'Deep.Order', 'Id', 'Kind', 'Total'].
-spec 'Top'(#{'Id' := integer(),
              'Kind' := 'Deep.Order',
              'Total' := integer()}) ->
               integer().
'Top'(O) when map_get('Kind', O) =:= 'Deep.Order' ->
    'Amount'(O).
-spec 'SumTotals'([#{'Id' := integer(),
                     'Kind' := 'Deep.Order',
                     'Total' := integer()}]) ->
                     integer().
'SumTotals'(Os) ->
    'FoldTotals'(Os, 0).
-spec 'FoldTotals'([#{'Id' := integer(),
                      'Kind' := 'Deep.Order',
                      'Total' := integer()}],
                   integer()) ->
                      integer().
'FoldTotals'([], Acc) ->
    Acc;
'FoldTotals'([O | Rest], Acc) ->
    'FoldTotals'(Rest, Acc + 'Amount'(O)).
-spec 'Amount'(#{'Id' := integer(),
                 'Kind' := 'Deep.Order',
                 'Total' := integer()}) ->
                  integer().
'Amount'(O) when map_get('Kind', O) =:= 'Deep.Order' ->
    map_get('Total', O).
-spec 'SumWeights'([0..255]) -> integer().
'SumWeights'(Xs) ->
    'FoldWeights'(Xs, 0).
-spec 'FoldWeights'([0..255], integer()) -> integer().
'FoldWeights'([], Acc) ->
    Acc;
'FoldWeights'([X | Rest], Acc) ->
    'FoldWeights'(Rest, Acc + 'Weight'(X)).
-spec 'Weight'(0..255) -> integer().
'Weight'(Bs@r1) when Bs@r1 >= 9 ->
    2;
'Weight'(Bs@r1) when Bs@r1 =< 8 ->
    1.
-spec 'WeightPub'(0..255) -> integer().
'WeightPub'(Bs@r1)
    when
        is_integer(Bs@r1)
        andalso
        Bs@r1 =< 255
        andalso
        Bs@r1 >= 9 ->
    2;
'WeightPub'(Bs@r1)
    when
        is_integer(Bs@r1)
        andalso
        Bs@r1 >= 0
        andalso
        Bs@r1 =< 8 ->
    1.
-spec 'Doubled'([integer()]) -> [integer()].
'Doubled'(Xs) ->
    lists:map(fun 'Twice'/1, Xs).
-spec 'Twice'(integer()) -> integer().
'Twice'(N) ->
    N * 2.
