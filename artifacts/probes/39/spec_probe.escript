#!/usr/bin/env escript
%% Does anything the Abstract Format can carry (a -spec, a guard) change what beam_ssa_type derives?
%% The same loop four ways, with spin/4 EXPORTED so inference cannot see its callers.
main([]) ->
    Tail = "    Next = wrap(Pos + Step),\n    spin(Next, Step, Left - 1, Zeros + hit(Next)).\n"
           "wrap(N) -> ((N rem 100) + 100) rem 100.\nhit(0) -> 1;\nhit(_) -> 0.\n",
    Head = "-module(sp).\n-export([spin/4]).\n",
    Plain = "spin(Pos, _Step, 0, Zeros) -> {Pos, Zeros};\nspin(Pos, Step, Left, Zeros) ->\n",
    Guard = "spin(Pos, _Step, 0, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, is_integer(Zeros) -> {Pos, Zeros};\n"
            "spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, is_integer(Step), Step >= -1, Step =< 1, is_integer(Left), is_integer(Zeros) ->\n",
    Wide = "-spec spin(integer(), integer(), integer(), integer()) -> {integer(), integer()}.\n",
    Narrow = "-spec spin(0..99, -1..1, non_neg_integer(), non_neg_integer()) -> {0..99, non_neg_integer()}.\n",
    [try_variant(Name, Head ++ Spec ++ Heads ++ Tail) ||
        {Name, Spec, Heads} <- [{"no spec", "", Plain}, {"wide spec", Wide, Plain},
                                {"NARROW spec", Narrow, Plain}, {"guards", "", Guard}]].

try_variant(Name, Src) ->
    File = filename:join(os:getenv("TMPDIR", "/tmp"), "sp.erl"),
    ok = file:write_file(File, Src),
    {ok, _M, Bin, _W} = compile:file(File, [binary, return]),
    {beam_file,_,_,_,_,Code} = beam_disasm:file(Bin),
    [{function,spin,4,_,Is}] = [F || F={function,spin,4,_,_} <- Code],
    Gc = [As || {gc_bif,_,_,_,As,_} <- Is],
    Trs = [T || As <- Gc, {tr,_,T} <- As],
    io:format("~-12s tr-annotated operands: ~p ~p~n", [Name, length(Trs), Trs]).
