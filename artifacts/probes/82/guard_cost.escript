#!/usr/bin/env escript
%% ticket 82 Q2: what does the deep guard cost beside json:encode?  OTP 28.
%%   deep    = the module bsc emits for ToJson<list<Order>> (argv[1] is its ebin dir)
%%   shallow = ticket 26 section 4's design: one map_size test per element, then json:encode
%%   none    = json:encode alone (publishes undeclared fields)
main([Ebin]) ->
    true = code:add_patha(Ebin),
    Order = fun(I) -> #{'Kind' => 'Many.Order', 'Id' => I, 'Total' => I * 3} end,
    io:format("~-8s ~-8s ~12s~n", ["orders", "form", "us/call"]),
    [begin
         L = [Order(I) || I <- lists:seq(1, N)],
         Reps = max(5, 200000 div N),
         D = bench(fun() -> 'Many':'Body'(L) end, Reps),
         S = bench(fun() -> shallow(L) end, Reps),
         Z = bench(fun() -> iolist_to_binary(json:encode(L)) end, Reps),
         [io:format("~-8w ~-8s ~12.2f~n", [N, F, T]) || {F, T} <- [{"deep", D}, {"shallow", S}, {"none", Z}]],
         io:format("~-8w deep/none = ~.2fx~n", [N, D / Z])
     end || N <- [1, 100, 10000]].

shallow(L) ->
    [begin true = is_map(O) andalso map_size(O) =:= 3, ok end || O <- L],
    iolist_to_binary(json:encode(L)).

bench(F, Reps) ->
    F(), F(),
    {US, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, Reps)] end),
    US / Reps.
