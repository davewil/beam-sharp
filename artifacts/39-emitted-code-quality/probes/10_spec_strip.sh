#!/usr/bin/env bash
# §1 claim: stripping the 7 -spec attributes from bsc's .abstr leaves the loop byte-identical and time unmoved.
. "$(dirname "$0")/env.sh"
V=$W/p10; rm -rf $V; mkdir -p $V
erl -noshell -eval '
 {ok,Fs}=file:consult("'$W'/ebin/Day01.abstr"),
 Specs=[F||{attribute,_,spec,_}=F<-Fs], io:format("specs in .abstr: ~p~n",[length(Specs)]),
 Rn=fun(N,Forms)->[case F of {attribute,A,module,_}->{attribute,A,module,N}; _->F end||F<-Forms] end,
 W=fun(Name,Forms)->file:write_file("'$V'/"++atom_to_list(Name)++".abstr",[io_lib:format("~p.~n",[F])||F<-Forms]) end,
 W(s_with,Rn(s_with,Fs)), W(s_without,Rn(s_without,[F||F<-Fs,not (element(1,F)=:=attribute andalso element(3,F)=:=spec)])),
 halt().'
for n in s_with s_without; do erlc +from_abstr -o $V $V/$n.abstr; done
for n in s_with s_without; do erl -noshell -pa $W -eval 'dis:main(["'$V'/'$n'.beam"])' | sed "s/$n/M/g" > $V/$n.dis; done
echo "instr lists identical (module name normalised): $(cmp -s $V/s_with.dis $V/s_without.dis && echo YES || echo NO)"
echo "beam bytes: with=$(stat -c%s $V/s_with.beam) without=$(stat -c%s $V/s_without.beam)"
for i in 1 2 3; do erl -noshell -pa $V -pa $W/ebin -eval 'bench2:main(["'$INPUT'","80","with_spec:s_with:PartTwo","no_spec:s_without:PartTwo","erlang:bench_erl:part_two"])' | tail -4; echo; done
