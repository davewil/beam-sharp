-module(e_micro).
-export([main/0]).
%% Verbatim copies of the prototype predicates (variant A and B) from patches/variant_{A,B}.patch,
%% timed in isolation: the per-`using` cost of the check, to set against a 10-15 ms compile.
allowed_a(Self, M, World) ->
    case maps:get(friends, maps:get(M, World), []) of
        [] -> true;
        Fr -> case Self =:= M orelse lists:any(fun(F) -> friend_match(F, Self) end, Fr) of
                  true  -> true;
                  false -> {false, x}
              end
    end.
friend_match({F, exact}, Self)   -> F =:= Self;
friend_match({F, subtree}, Self) -> Self =:= F orelse lists:prefix(atom_to_list(F) ++ ".", atom_to_list(Self)).
allowed_b(Self, M, _World) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case lists:splitwith(fun(S) -> S =/= "Internal" end, Segs) of
        {_, []}      -> true;
        {Parent, _}  ->
            P = string:join(Parent, "."),
            case Parent =:= [] orelse atom_to_list(Self) =:= P
                     orelse lists:prefix(P ++ ".", atom_to_list(Self)) of
                true  -> true;
                false -> {false, P}
            end
    end.
main() ->
    N = 1000000,
    WorldNone = #{'Shop.Orders' => #{friends => []}},
    WorldA = #{'Shop.Orders' => #{friends => [{'Shop.Reports', exact}, {'Shop.Admin', subtree}]}},
    Bench = fun(Name, F) ->
        Ts = lists:sort([element(1, timer:tc(fun() -> loop(N, F) end)) || _ <- lists:seq(1, 21)]),
        io:format("~-34s median ~.1f ns/call  (min ~.1f, max ~.1f; 21 x ~p calls)~n",
                  [Name, lists:nth(11, Ts) * 1000 / N, hd(Ts) * 1000 / N, lists:last(Ts) * 1000 / N, N]) end,
    Bench("A: no friend list (every module)", fun() -> allowed_a('Other', 'Shop.Orders', WorldNone) end),
    Bench("A: 2 friends, caller listed", fun() -> allowed_a('Shop.Reports', 'Shop.Orders', WorldA) end),
    Bench("A: 2 friends, caller refused", fun() -> allowed_a('Other', 'Shop.Orders', WorldA) end),
    Bench("B: no Internal segment", fun() -> allowed_b('Other', 'Shop.Orders', #{}) end),
    Bench("B: Internal, caller allowed", fun() -> allowed_b('Shop.Orders.Total', 'Shop.Orders.Internal.Pricing', #{}) end),
    Bench("B: Internal, caller refused", fun() -> allowed_b('Shop.Reports', 'Shop.Orders.Internal.Pricing', #{}) end),
    Bench("control: empty fun", fun() -> ok end),
    halt().
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N - 1, F).
