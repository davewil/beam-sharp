%% Stand-in for bsc output: PascalCase export with a -spec, snake alias WITHOUT a spec,
%% a third (alias2) WITH its own spec, and callers that violate the contract.
-module(dm).
-export(['Total'/1, total/1, total2/1, bad_pascal/0, bad_alias/0, bad_alias2/0]).
-spec 'Total'(integer()) -> integer().
'Total'(X) -> X + 1.
total(X) -> 'Total'(X).
-spec total2(integer()) -> integer().
total2(X) -> 'Total'(X).
bad_pascal() -> 'Total'(not_an_int).
bad_alias()  -> total(not_an_int).
bad_alias2() -> total2(not_an_int).
