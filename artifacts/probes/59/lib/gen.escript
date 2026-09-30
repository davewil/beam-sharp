#!/usr/bin/env escript
%% usage: gen.escript Dir K rec|int|both -- writes Dir/x.bs: module Dir with K private functions of the chosen kind,
%% called from one exported function whose own parameters are lists, so the erlang compiler cannot prove the callees' arguments.
main([Dir, KS, Kind]) ->
    K = list_to_integer(KS), Seq = lists:seq(1, K),
    Mod = filename:basename(Dir),
    filelib:ensure_dir(Dir ++ "/x"),
    Head = ["module ", Mod, "\n\nrecord Order { Id: int, Total: int }\ntype Octet = int where value >= 0 and value <= 255\n\n"],
    Rec = [io_lib:format("int R~p(Order o)\nR~p(o) -> o.Total + ~p\n\n", [I,I,I]) || I <- Seq, Kind =/= "int"],
    Int = [io_lib:format("int N~p(Octet n)\nN~p(n) when n >= 9 -> n + ~p\nN~p(n) -> ~p\n\n", [I,I,I,I,I]) || I <- Seq, Kind =/= "rec"],
    Calls = lists:join(" + ", ["0"] ++ [io_lib:format("R~p(o)", [I]) || I <- Seq, Kind =/= "int"]
                                    ++ [io_lib:format("N~p(n)", [I]) || I <- Seq, Kind =/= "rec"]),
    Use = ["public int Use(list<Order> os, list<Octet> ns)\nUse([o, .._], [n, .._]) -> ", Calls, "\nUse(_, _) -> 0\n"],
    file:write_file(Dir ++ "/x.bs", [Head, Rec, Int, Use]).
