%% 66b — what `Delta(Payment p)` would emit under ticket 66's yes, written by
%% hand so the target is known to compile and dispatch before any emitter work.
%% One clause for the union: a map match binding the tag, and a guard naming
%% the members. Erlang has no or-pattern, so the membership test is a guard.
%%
%%   erlc 66b_yes_target.erl && erl -noshell -s '66b_yes_target' main -s init stop
-module('66b_yes_target').
-export([main/0, 'Delta'/1]).

'Delta'(P = #{'Kind' := K}) when K =:= 'L.CardPaid'; K =:= 'L.BankPaid' ->
    map_get('Amount', P);
'Delta'(R = #{'Kind' := 'L.Refunded'}) ->
    0 - map_get('Amount', R).

main() ->
    Card = #{'Kind' => 'L.CardPaid', 'Id' => 1, 'Amount' => 5},
    Bank = #{'Kind' => 'L.BankPaid', 'Id' => 2, 'Amount' => 7},
    Ref  = #{'Kind' => 'L.Refunded', 'Id' => 3, 'Amount' => 4},
    Void = #{'Kind' => 'L.Voided',   'Id' => 4, 'Amount' => 9},
    io:format("card ~p, bank ~p, refunded ~p~n",
              ['Delta'(Card), 'Delta'(Bank), 'Delta'(Ref)]),
    io:format("voided ~p~n", [catch 'Delta'(Void)]).
