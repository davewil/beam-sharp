#!/usr/bin/env bash
# Can `inline` travel IN the forms (so `erlc +from_abstr` of the .abstr also gets it)? Insert {attribute,0,compile,inline}
# into Day01.abstr (after the module attribute), compile WITHOUT the inline option, and compare asm + timing.
R=/home/user/beam-sharp/artifacts/39; B=$R/build; O=$B/inl; rm -rf $O; mkdir -p $O
erl -noshell -eval '
{ok,[Fs]} = {ok, element(2, file:consult("'$B'/day01/Day01.abstr"))}, _ = Fs, halt().' >/dev/null 2>&1
erl -noshell -eval '
{ok,Fs0} = file:consult("'$B'/day01/Day01.abstr"),
[M|Rest] = Fs0,
Fs = [M, {attribute,0,compile,inline}|Rest],
Fs1 = [setelement(3, F, list_to_atom(atom_to_list(element(3,F)))) || F <- [M]],
_ = Fs1,
Ren = fun(T) -> T end, _ = Ren,
Out = [io_lib:format("~p.~n",[X]) || X <- [ {attribute,0,module,'"'Day01_attr'"'} | tl(Fs) ]],
ok = file:write_file("'$O'/Day01_attr.abstr", Out),
R = compile:file("'$O'/Day01_attr.abstr",[from_abstr,debug_info,{outdir,"'$O'"}]),
io:format("compile: ~p~n",[R]),halt().'
echo "local calls in Spin after attribute-inline:"
erl -noshell -pa $O -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file(code:which(Day01_attr)),[{function,_,_,_,C}]=[F||{function,N,4,_,_}=F<-Fs,N=:='"'Spin'"'],io:format("~p instrs, ~p calls~n",[length(C),length([X||X<-C,is_tuple(X),lists:member(element(1,X),[call,call_last,call_only])])]),halt().'
erlc -o $O $R/probes/bench2.erl
erl -noshell -pa $O -pa $B/day01 -run bench2 main /home/user/beam-sharp/aoc/2025/Day01/input.txt 150 bench_erl:part_two "Day01:PartTwo" "Day01_attr:PartTwo" bench_gleam:part_two
