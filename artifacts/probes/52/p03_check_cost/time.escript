#!/usr/bin/env escript
%% time.escript DIR : compile Big/ 30x in ONE VM per mode, report median ms. Uses the PROTOTYPE ebin.
main([Dir]) ->
    true = code:add_pathz("/tmp/bs52_proto/ebin"),
    {ok, Cwd} = file:get_cwd(), ok = file:set_cwd(Dir),
    [begin
         os:putenv("BS52", Mode),
         Opts = [bsc:file("Big/big.bs") || _ <- [warm]],   %% warm
         _ = Opts,
         Ts = [begin {T, R} = timer:tc(fun() -> bsc:file("Big/big.bs") end), {T, R} end || _ <- lists:seq(1, 30)],
         Sorted = lists:sort([T || {T,_} <- Ts]),
         Med = lists:nth(15, Sorted) / 1000,
         Res = element(2, hd(Ts)),
         io:format("  BS52=~-7s median ~7.2f ms  min ~7.2f ms  result=~p~n", [Mode, Med, hd(Sorted)/1000, element(1,Res)])
     end || Mode <- ["off", "module", "app", "off", "module", "app"]],
    file:set_cwd(Cwd).
