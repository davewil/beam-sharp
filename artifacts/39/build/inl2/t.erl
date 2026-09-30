-module(t).
-export([main/0]).
main() ->
    [begin
        {ok, M, Bin} = compile:file("/home/user/beam-sharp/artifacts/39/build/day01/Day01.abstr", [from_abstr, binary, Opt]),
        {beam_file,_,_,_,_,Bf} = beam_disasm:file(Bin),
        [{function,_,_,_,C}] = [F || {function,N,4,_,_} = F <- Bf, N =:= 'Spin'],
        Calls = [element(3, X) || X <- C, is_tuple(X), lists:member(element(1,X), [call,call_last,call_only])],
        io:format("~-16w ~p instrs; calls left in Spin: ~p~n", [Opt, length(C), [case Y of {_,F2,_} -> F2; _ -> Y end || Y <- Calls]]),
        M
     end || Opt <- [inline, {inline, 40}, {inline, 60}, {inline, 100}]],
    halt().
