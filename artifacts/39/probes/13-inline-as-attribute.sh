#!/usr/bin/env bash
# Can `inline` travel IN the forms (so `erlc +from_abstr` of the .abstr also gets it)? Insert {attribute,0,compile,inline}
# into Day01.abstr (after the module attribute), compile WITHOUT the inline option, and compare asm + timing.
# (v2: v1 crashed in the disassembly step on an unquoted atom in my own eval; logged in 13-...v1-quoting-bug.*; nothing else changed)
R=/home/user/beam-sharp/artifacts/39; B=$R/build; O=$B/inl; rm -rf $O; mkdir -p $O
cat > $O/mk.erl <<'XEOF'
-module(mk).
-export([main/1]).
main([In, Out, Dir]) ->
    {ok, [_Mod | Rest]} = file:consult(In),
    Fs = [{attribute,0,module,'Day01_attr'}, {attribute,0,compile,inline} | Rest],
    ok = file:write_file(Out, [io_lib:format("~p.~n", [X]) || X <- Fs]),
    io:format("compile: ~p~n", [compile:file(Out, [from_abstr, debug_info, {outdir, Dir}])]),
    {beam_file,_,_,_,_,Bf} = beam_disasm:file(filename:join(Dir, "Day01_attr.beam")),
    [{function,_,_,_,C}] = [F || {function,N,4,_,_} = F <- Bf, N =:= 'Spin'],
    io:format("Spin/4 after attribute-inline: ~p instrs, ~p local calls~n",
              [length(C), length([X || X <- C, is_tuple(X), lists:member(element(1,X), [call,call_last,call_only])])]),
    halt().
XEOF
erlc -o $O $O/mk.erl
erl -noshell -pa $O -eval "mk:main([\"$B/day01/Day01.abstr\",\"$O/Day01_attr.abstr\",\"$O\"])"
erlc -o $O $R/probes/bench2.erl
erl -noshell -pa $O -pa $B/day01 -run bench2 main /home/user/beam-sharp/aoc/2025/Day01/input.txt 150 bench_erl:part_two "Day01:PartTwo" "Day01_attr:PartTwo" bench_gleam:part_two
