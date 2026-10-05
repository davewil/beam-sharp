-module('Scope').
-export(['OuterRec'/1,'OuterInt'/1,bs@type_atoms/0]).
bs@type_atoms() ->
    ['Id', 'Kind', 'Scope.Order', 'Total'].
-spec 'OuterRec'(#{'Id' := integer(),
                   'Kind' := 'Scope.Order',
                   'Total' := integer()}) ->
                    integer().
'OuterRec'(O) when map_get('Kind', O) =:= 'Scope.Order' ->
    'InnerRec'(O).
-spec 'InnerRec'(#{'Id' := integer(),
                   'Kind' := 'Scope.Order',
                   'Total' := integer()}) ->
                    integer().
'InnerRec'(O) when map_get('Kind', O) =:= 'Scope.Order' ->
    map_get('Total', O).
-spec 'OuterInt'(integer()) -> integer().
'OuterInt'(N) when is_integer(N) ->
    'InnerInt'(N).
-spec 'InnerInt'(integer()) -> integer().
'InnerInt'(N)
    when
        is_integer(N)
        andalso
        N >= 0 ->
    N;
'InnerInt'(N) when is_integer(N) ->
    0.
