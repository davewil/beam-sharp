%% PROTOTYPE — throwaway. The Erlang that prototype 01c's Orders domain lowers to.
%%
%% Written to test claims made in 01b/01c that had never been executed:
%%   - property patterns in the head       -> Erlang map patterns
%%   - list-shape patterns in the head     -> #{lines := [_|_]}
%%   - `not :shipped` as a pattern         -> ??? (Erlang has no negation pattern)
%%   - `when amt >= Total(o)`              -> ??? (user function in a guard is ILLEGAL)
%%
%% The last two are the interesting ones.

-module('01f_orders_lowering').
-export([apply_/2, total/1, merge/1, demo/0]).

%% Order = #{id, status, lines, paid};  Line = #{sku, qty, unit}

%% ---- the transition table -------------------------------------------------
%% Each beam-sharp clause -> one Erlang clause head, EXCEPT where noted.

apply_(#{status := draft} = O, {add_line, L}) ->
    {ok, O#{lines := [L | maps:get(lines, O)]}};

apply_(#{status := draft} = O, {remove_line, Sku}) ->
    remove_line(O, Sku);

%% `Lines: [_, .._]` lowers to a native map+list pattern. No guard needed.
apply_(#{status := draft, lines := [_|_]} = O, place) ->
    {ok, O#{status := placed}};

apply_(#{status := draft}, place) ->
    {error, empty_order};

%% `when amt >= Total(o)` CANNOT be expressed: total/1 is a user function and
%% BEAM guards permit only guard BIFs. The lowering must hoist the call and
%% dispatch on its result. beam-sharp would have to do the same - or hoist it
%% automatically, which purity makes safe (see the write-up).
apply_(#{status := placed} = O, {pay, Amt}) ->
    pay(O, Amt, total(O));

apply_(#{status := paid} = O, {ship, _}) ->
    {ok, O#{status := shipped}};

%% `{ Status: not :shipped }` CANNOT be a pattern: Erlang has no negation
%% pattern. It lowers to a guard on the bound value.
apply_(#{status := S} = O, cancel) when S =/= shipped ->
    {ok, O#{status := cancelled}};

apply_(O, E) ->
    {error, {not_allowed, maps:get(status, O), E}}.

pay(O, Amt, Total) when Amt >= Total -> {ok, O#{status := paid, paid := Amt}};
pay(_O, Amt, Total)                  -> {error, {underpaid, Total - Amt}}.

remove_line(O, Sku) ->
    Lines = maps:get(lines, O),
    Kept  = [L || L <- Lines, maps:get(sku, L) =/= Sku],
    case length(Kept) =:= length(Lines) of
        true  -> {error, {no_such_line, Sku}};
        false -> {ok, O#{lines := Kept}}
    end.

%% ---- recursion ------------------------------------------------------------

total(O) when is_map(O) -> total(maps:get(lines, O), 0).

total([], Acc)                                  -> Acc;
total([#{qty := Q, unit := U} | Rest], Acc)     -> total(Rest, Acc + Q * U).

merge([])                                       -> [];
merge([L])                                      -> [L];
merge([#{sku := S} = A, #{sku := S} = B | Rest]) ->
    merge([A#{qty := maps:get(qty, A) + maps:get(qty, B)} | Rest]);
merge([A | Rest])                               -> [A | merge(Rest)].

%% ---- demo -----------------------------------------------------------------

demo() ->
    L1 = #{sku => <<"a">>, qty => 2, unit => 500},
    L2 = #{sku => <<"a">>, qty => 3, unit => 500},
    L3 = #{sku => <<"b">>, qty => 1, unit => 250},
    O0 = #{id => <<"o1">>, status => draft, lines => [], paid => 0},

    io:format("place on empty     -> ~p~n", [apply_(O0, place)]),

    {ok, O1} = apply_(O0, {add_line, L1}),
    {ok, O2} = apply_(O1, {add_line, L3}),
    io:format("total after 2 lines-> ~p~n", [total(O2)]),

    io:format("remove missing     -> ~p~n", [apply_(O2, {remove_line, <<"zz">>})]),

    {ok, O3} = apply_(O2, place),
    io:format("placed             -> ~p~n", [maps:get(status, O3)]),

    io:format("underpay           -> ~p~n", [apply_(O3, {pay, 100})]),
    {ok, O4} = apply_(O3, {pay, 1250}),
    io:format("paid               -> ~p paid=~p~n", [maps:get(status, O4), maps:get(paid, O4)]),

    {ok, O5} = apply_(O4, {ship, <<"tracking">>}),
    io:format("shipped            -> ~p~n", [maps:get(status, O5)]),

    io:format("cancel when shipped-> ~p~n", [apply_(O5, cancel)]),
    io:format("cancel when placed -> ~p~n", [element(1, apply_(O3, cancel))]),

    io:format("merge same sku     -> ~p~n", [merge([L1, L2, L3])]),
    ok.
