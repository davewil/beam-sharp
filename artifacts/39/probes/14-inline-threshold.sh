#!/usr/bin/env bash
# `inline` leaves Wrap/1 as a call in the bs build but not in the Erlang build. Is it the size threshold (the FFI-result
# `case .. when is_integer` wrapper counts toward it)? Try {inline,N} for a few N; count local calls left in Spin/4.
R=/home/user/beam-sharp/artifacts/39; B=$R/build; O=$B/inl2; rm -rf $O; mkdir -p $O
cat > $O/t.erl <<'XEOF'
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
XEOF
erlc -o $O $O/t.erl && erl -noshell -pa $O -eval 't:main()'
echo "--- same four settings on the hand-written Erlang"
erl -noshell -eval '[begin {ok,_,Bin}=compile:file("'$R'/../../aoc/bench/bench_erl.erl",[binary,O]), {beam_file,_,_,_,_,Bf}=beam_disasm:file(Bin),[{function,_,_,_,C}]=[F||{function,N,4,_,_}=F<-Bf,N=:=spin],io:format("~-16w ~p instrs, ~p calls~n",[O,length(C),length([X||X<-C,is_tuple(X),lists:member(element(1,X),[call,call_last,call_only])])]) end||O<-[inline,{inline,40},{inline,60},{inline,100}]],halt().'
