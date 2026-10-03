-module(sel).
-export([main/1]).
main([Build, Out]) ->
    file:make_dir(Out),
    {ok, Bs} = file:consult(Build ++ "/Day01.abstr"),
    Ins = fun(Spec) -> {A,[M|B]} = lists:splitwith(fun(F) -> not (element(1,F)=:=attribute andalso element(3,F)=:=module) end, Bs),
                       A ++ [M,{attribute,0,compile,Spec}|B] end,
    V = [{s0_none, Bs},
         {s1_wrap_only,  Ins({inline,[{'Wrap',1}]})},
         {s2_hit_only,   Ins({inline,[{'Hit',1}]})},
         {s3_wrap_hit,   Ins({inline,[{'Wrap',1},{'Hit',1}]})},
         {s4_all_inline, Ins(inline)},
         {s5_inline_size100, Ins([inline,{inline_size,100}])}],
    [begin Fs = [case F of {attribute,A,module,_} -> {attribute,A,module,N}; _ -> F end || F <- Forms],
           {ok,N,Bin} = compile:noenv_forms(Fs, [binary,debug_info]),
           file:write_file(Out ++ "/" ++ atom_to_list(N) ++ ".beam", Bin),
           io:format("built ~-18s ~p bytes~n", [N, byte_size(Bin)]) end || {N,Forms} <- V],
    halt().
