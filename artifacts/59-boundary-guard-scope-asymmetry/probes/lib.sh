# shared helpers for the ticket-59 probes (sourced, not run)
export PATH=/opt/otp28/bin:$PATH
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
# bs_build NAME DIR_WITH_bs OUTDIR  -> compiles module dir with $BSC
bs_build() { "$BSC" -o "$2" "$1"; }
# abstr FILE.beam : pretty-print the emitted Erlang forms (functions only)
abstr() { erl -noshell -eval '{ok,{_,[{abstract_code,{_,F}}]}}=beam_lib:chunks(hd(init:get_plain_arguments()),[abstract_code]), [io:format("~s~n",[erl_pp:function(X)]) || X={function,_,N,_,_}<-F, N=/=bs@type_atoms], halt().' -extra "$1"; }
# asm FILE.beam FUNCNAME ARITY : disassembled BEAM instructions of one function
asm() { erl -noshell -eval '[B,N,A]=init:get_plain_arguments(), {beam_file,_,_,_,_,Fs}=beam_disasm:file(B), Na=list_to_atom(N), Ar=list_to_integer(A), [io:format("~p~n",[I]) || {function,Nm,Ar2,_,Is}<-Fs, Nm=:=Na, Ar2=:=Ar, I<-Is], halt().' -extra "$1" "$2" "$3"; }
# code_bytes FILE.beam : size of the Code chunk and whole file
code_bytes() { erl -noshell -eval '[B]=init:get_plain_arguments(), {ok,_,Cs}=beam_lib:all_chunks(B), {"Code",C}=lists:keyfind("Code",1,Cs), io:format("Code=~p file=~p~n",[byte_size(C), filelib:file_size(B)]), halt().' -extra "$1"; }
