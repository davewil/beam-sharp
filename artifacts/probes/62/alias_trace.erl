-module(alias_trace).
-export([main/1]).

%% An Erlang control that is NOT tail-calling, to prove the stack probe can see an extra frame.
-export([nt/1]).
nt(A) -> R = 'Shop':'Which'(A), {R}.

ar(A) when is_list(A) -> length(A);
ar(A) -> A.

main([Dir]) ->
    {ok, F} = file:consult(filename:join(Dir, "Shop.abstr")),
    {ok, _, Base} = compile:forms(F, [debug_info, binary, return_errors]),
    {ok, _, Wrap} = compile:forms(alias_xform:xform(simple, wrapper, F), [debug_info, binary, return_errors]),
    %% 1. what does the alias compile to? (asm of the wrapper)
    {ok, _, Asm} = compile:forms(alias_xform:xform(simple, wrapper, F), ['S', return_errors]),
    {Fn, _} = lists:partition(fun({function, which, 1, _, _}) -> true; (_) -> false end, element(4, Asm)),
    io:format("== (1) asm of the alias `which/1` (from `erlc -S` equivalent):~n~p~n", [Fn]),
    %% 2. stack trace through the alias vs through the original
    code:load_binary('Shop', "Shop.beam", Wrap),
    Bad = #{'Kind' => 'Other.Thing', 'Id' => 1},
    St = fun(M, Fun, Args) -> try apply(M, Fun, Args) catch error:E:S -> {E, [{Mod, Name, ar(Ar)} || {Mod, Name, Ar, _} <- S]} end end,
    io:format("~n== (2) stack trace of a function_clause crash~n"),
    io:format("   via 'Which'/1 : ~p~n", [St('Shop', 'Which', [Bad])]),
    io:format("   via  which/1  : ~p~n", [St('Shop', which, [Bad])]),
    io:format("   CONTROL non-tail wrapper nt/1 (must show an EXTRA alias_trace frame): ~p~n", [St(alias_trace, nt, [Bad])]),
    %% 3. process_info current_stacktrace from inside a callee, via alias, many calls deep (tail => constant stack)
    %% Build a self-recursive pair: loop via alias n times, memory must stay flat.
    io:format("~n== (3) 1,000,000 tail calls through alias vs original: stack/heap growth~n"),
    ok = mkloop(),
    Run = fun(Entry) ->
              Self = self(),
              P = spawn(fun() -> R = looptest:Entry(1000000), Self ! {done, R, 0, 0} end),
              receive {done, R, Mem, Heap} -> {bytes_of_process_memory_at_the_bottom, R} after 20000 -> {timeout, P} end
          end,
    io:format("   direct  loop_a (tail via local) : ~p~n", [Run(a_direct)]),
    io:format("   via alias loop_b (tail via exported alias, wrapper non-tail would grow) : ~p~n", [Run(b_alias)]),
    io:format("   CONTROL non-tail recursion c_nontail (must grow) : ~p~n", [Run(c_nontail)]),
    %% 4. can two export names share one label? patch the ExpT/AtU8 chunks of the BASE beam
    io:format("~n== (4) one code label exported under two names (hand-patched ExpT/AtU8 of the real Shop.beam)~n"),
    shared_label(Base).

mkloop() ->
    Src = "-module(looptest).\n-export([a_direct/1, b_alias/1, c_nontail/1, loop_b/1, loop_alias/1]).\n"
          "a_direct(0) -> mem(); a_direct(N) -> a_direct(N-1).\n"
          "loop_b(0) -> mem(); loop_b(N) -> looptest:loop_alias(N-1).\n"
          "loop_alias(N) -> looptest:loop_b(N).\n"
          "b_alias(N) -> loop_b(N).\n"
          "mem() -> element(2, process_info(self(), memory)).\nc_nontail(0) -> mem(); c_nontail(N) -> R = c_nontail(N-1), erlang:put(x, 1), R.\n",
    {ok, Ts, _} = erl_scan:string(Src), Forms = parse(Ts, []),
    {ok, M, B} = compile:forms(Forms, [binary]), {module, M} = code:load_binary(M, "looptest.beam", B), ok.
parse([], Acc) -> [{attribute,1,file,{"x",1}}|lists:reverse(Acc)];
parse(Ts, Acc) ->
    {Form, Rest} = split(Ts, []),
    {ok, F} = erl_parse:parse_form(Form), parse(Rest, [F|Acc]).
split([{dot,_}=D|R], Acc) -> {lists:reverse([D|Acc]), R};
split([T|R], Acc) -> split(R, [T|Acc]).

shared_label(Base) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Base),
    {"AtU8", At} = lists:keyfind("AtU8", 1, Chunks),
    {"ExpT", Ex} = lists:keyfind("ExpT", 1, Chunks),
    <<NegN:32/signed, Rest/binary>> = At,
    N = -NegN,
    %% atom names are compact-term-length-prefixed; for len < 16 one byte (Len bsl 4)
    NewAtom = <<(5 bsl 4):8, "which">>,
    At2 = <<(-(N+1)):32/signed, Rest/binary, NewAtom/binary>>,
    <<Cnt:32, Ents/binary>> = Ex,
    Entries = [{A, Ar, L} || <<A:32, Ar:32, L:32>> <= Ents],
    {ok, {_, [{atoms, Atoms}]}} = beam_lib:chunks(Base, [atoms]),
    NewIdx = N + 1,
    Names = maps:from_list([{Nm, I} || {I, Nm} <- Atoms]),
    NewIdxOfNew = case maps:find(which, Names) of {ok, I0} -> I0; error -> NewIdx end,
    io:format("   atom table: ~p atoms, 'which' present before patch: ~p~n", [N, maps:is_key(which, Names)]),
    NewIdxOfNew = NewIdx,
    NewIdxAtom = maps:get('Which', Names),
    {NewIdxAtom, 1, Label} = lists:keyfind(NewIdxAtom, 1, Entries),
    io:format("   'Which'/1 entry label: ~p~n", [Label]),
    Ex2 = <<(Cnt+1):32, Ents/binary, NewIdx:32, 1:32, Label:32>>,
    Chunks2 = lists:keystore("ExpT", 1, lists:keystore("AtU8", 1, Chunks, {"AtU8", At2}), {"ExpT", Ex2}),
    {ok, Patched} = beam_lib:build_module(Chunks2),
    Mid = "Shop",
    code:purge('Shop'), code:delete('Shop'), code:purge('Shop'),
    case catch code:load_binary('Shop', Mid ++ ".beam", Patched) of
        {module, 'Shop'} ->
            io:format("   LOADED. exports now contain which/1: ~p~n", [lists:member({which,1}, 'Shop':module_info(exports))]),
            Ok = #{'Kind' => 'Shop.Order', 'Id' => 9, 'Total' => 5},
            io:format("   'Which'(Order) == which(Order): ~p ; value ~p~n", [('Shop':'Which'(Ok) =:= 'Shop':which(Ok)), 'Shop':which(Ok)]),
            Bad = #{'Kind' => 'Other.Thing', 'Id' => 1},
            St = fun(Fun) -> try 'Shop':Fun(Bad) catch error:E:S -> {E, [{Nm, ar(Ar)} || {'Shop', Nm, Ar, _} <- S]} end end,
            io:format("   crash via 'Which': ~p~n", [St('Which')]),
            io:format("   crash via which (SAME label, second export name): ~p~n", [St(which)]),
            io:format("   -> the trace names the label's func_info ('Which'), not the export name used.~n"),
            io:format("   erlang:function_exported(Shop,which,1): ~p~n", [erlang:function_exported('Shop', which, 1)]);
        Other ->
            io:format("   LOAD FAILED: ~p~n", [Other])
    end.
