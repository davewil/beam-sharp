-module(p9_check_micro).
-export([main/0]).
%% Verbatim copies of the prototype check bodies (optA.diff internal_ok/2; optC.diff friend_ok/3; optB.diff view/2 per-import share).
internal_ok(Self, M) ->
    Segs = string:split(atom_to_list(M), ".", all),
    case lists:splitwith(fun(S) -> S =/= "Internal" end, Segs) of
        {_, []}     -> ok;
        {Parent, _} ->
            SelfSegs = string:split(atom_to_list(Self), ".", all),
            case lists:prefix(Parent, SelfSegs) of
                true  -> ok;
                false -> {no, list_to_atom(lists:flatten(lists:join(".", Parent)))}
            end
    end.
friend_ok(Self, M, World) ->
    case maps:get(friends, maps:get(M, World, #{}), []) of
        [] -> ok;
        Fs ->
            S = string:split(atom_to_list(Self), ".", all),
            case lists:any(fun(F) -> lists:prefix(string:split(atom_to_list(F), ".", all), S) end, Fs) of
                true  -> ok;
                false -> {no, Fs}
            end
    end.
view(World, Self) ->
    SelfSegs = string:split(atom_to_list(Self), ".", all),
    maps:map(fun(M, Entry) ->
        Internal = maps:get(internal, Entry, #{}),
        case maps:size(Internal) =:= 0 orelse
             lists:prefix(string:split(atom_to_list(M), ".", all), SelfSegs) of
            true -> Entry;
            false -> Entry#{exports := maps:without(maps:keys(Internal), maps:get(exports, Entry))}
        end end, World).
t(F, N) -> {T, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, N)] end), T * 1000 / N.   % ns per call
main() ->
    N = 200000, Self = 'Acme.Billing.M1', M = 'Acme.Orders.Internal.Pricing',
    World = #{M => #{friends => ['Acme.Orders'], internal => #{{'H',1} => true}, exports => #{{'H',1} => x, {'C',1} => y}}},
    W200 = maps:from_list([{list_to_atom("Syn.G" ++ integer_to_list(I) ++ ".Core"),
                            #{internal => #{{'H',1} => true}, exports => #{{'H',1} => x, {'C',1} => y}}} || I <- lists:seq(1,40)] ++
                          [{list_to_atom("Syn.G" ++ integer_to_list(I) ++ ".Lib"), #{exports => #{{'L',1} => y}}} || I <- lists:seq(1,160)]),
    Run = fun(L, F) -> Ts = lists:sort([t(F, N) || _ <- lists:seq(1,11)]),
                       io:format("~s median ~w ns/call (min ~w, max ~w)~n", [L, round(lists:nth(6, Ts)), round(hd(Ts)), round(lists:last(Ts))]) end,
    Run("A internal_ok (refused path)", fun() -> internal_ok(Self, M) end),
    Run("A internal_ok (no Internal segment)", fun() -> internal_ok(Self, 'Acme.Orders') end),
    Run("C friend_ok (refused path)", fun() -> friend_ok(Self, M, World) end),
    Run("C friend_ok (no friends)", fun() -> friend_ok(Self, 'Acme.Orders', World) end),
    Ts = lists:sort([t(fun() -> view(W200, Self) end, 1000) || _ <- lists:seq(1,11)]),
    io:format("B view/2 over a 200-module World median ~w ns/call (min ~w, max ~w)~n", [round(lists:nth(6, Ts)), round(hd(Ts)), round(lists:last(Ts))]),
    io:format("(B's view/2 runs once per compiled module in the prototype; 200 modules => ~p calls per full build)~n", [200]).
