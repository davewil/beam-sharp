%% Hand-written stand-in for bsc output of examples/Shop/shop.bs.
%% Exports PascalCase names exactly as bsc does (62a section 1), plus the
%% snake_case aliases a candidate-2 compiler would add.
-module('Shop').
-export(['New'/1, 'Which'/1, 'Pay'/1, new/1, which/1, pay/1, 'bs@type_atoms'/0]).

'New'(Id) -> #{'Kind' => 'Shop.Order', 'Id' => Id, 'Total' => 0}.
'Pay'(#{'Kind' := 'Shop.Order'} = O) -> O#{'Total' := 500}.
'Which'(#{'Kind' := 'Shop.Order'}) -> order.
'bs@type_atoms'() -> ['Shop.Order'].

%% aliases as trampolines
new(A) -> 'New'(A).
pay(A) -> 'Pay'(A).
which(A) -> 'Which'(A).
