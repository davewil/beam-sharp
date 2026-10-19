-module('Shop').
-export(['New'/1, new/1, 'Total'/1]).
'New'(Id) -> #{'Kind' => 'Shop.Order', 'Id' => Id, 'Total' => 0}.
new(Id) -> 'New'(Id).
'Total'(#{'Kind' := 'Shop.Order', 'Total' := T}) -> T.
