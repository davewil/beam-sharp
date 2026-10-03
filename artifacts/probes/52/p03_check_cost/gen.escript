#!/usr/bin/env escript
%% gen.escript N ANNOTATED(0|1) OUTDIR : a B# module with N foreign using blocks drawn from real Elixir modules
main([NS, Ann, Out]) ->
    N = list_to_integer(NS),
    {ok, Fs} = file:list_dir("/tmp/otp/lib/elixir/lib/elixir/ebin"),
    Mods = lists:sort([list_to_atom(filename:rootname(F)) || F <- Fs, lists:prefix("Elixir.", F), filename:extension(F) =:= ".beam"]),
    Reserved = [module,type,in,using,'when',for,var,with,record,switch,behaviour,implements,public,private,'not','and','or',true,false,'if','else',match,fn,'let'],
    Cands = lists:append([ [{M, F} || {F, 1} <- exports(M),
                                        lists:all(fun(C) -> (C >= $a andalso C =< $z) end, atom_to_list(F)),
                                        not lists:member(F, Reserved)] || M <- Mods]),
    %% one function per module, first N distinct modules
    Uniq = take(N, Cands, []),
    Blocks = [io_lib:format("using :'~s'~s {\n    term ~s(term x)\n}\n\n", [M, if Ann =:= "1" -> " in :elixir"; true -> "" end, F]) || {M, F} <- Uniq],
    ok = filelib:ensure_path(filename:join(Out, "Big")),
    file:write_file(filename:join([Out, "Big", "big.bs"]),
        ["module Big\n\n", Blocks, "public term Go(term x)\n\nGo(x) -> x\n"]).
exports(M) -> try M:module_info(exports) catch _:_ -> [] end.
take(0, _, Acc) -> lists:reverse(Acc);
take(_, [], Acc) -> lists:reverse(Acc);
take(N, [{M,F}|T], Acc) -> case lists:keymember(M, 1, Acc) of true -> take(N, T, Acc); false -> take(N-1, T, [{M,F}|Acc]) end.
