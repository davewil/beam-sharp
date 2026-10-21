-module('Shop').
-export(['New'/1, new/1, 'Which'/1]).
'New'(Id) -> #{'Kind' => 'Shop.Order', 'Id' => Id, 'Total' => 0}.
new(Id) -> 'New'(Id).
'Which'(#{'Kind' := 'Shop.Order'}) -> order.
