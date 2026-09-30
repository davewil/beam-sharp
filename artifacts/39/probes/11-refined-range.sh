#!/usr/bin/env bash
# B# holds an exact interval for Clamp's result. Show (1) the emitted spec, (2) the final asm of Run/Bucket/Clamp (OTP 25).
R=/home/user/beam-sharp/artifacts/39; O=$R/build/ref; mkdir -p $O
$R/probes/bsc.sh -o $O $R/probes/RefWrap || exit 1
erl -noshell -eval '{ok,F}=file:consult("'$O'/RefWrap.abstr"),[io:format("~p~n",[X])||X={attribute,_,spec,_}<-F],halt().'
erl -noshell -eval 'compile:file("'$O'/RefWrap.abstr",[from_abstr,debug_info,'"'S'"',{outdir,"'$O'"}]),halt().' >/dev/null
grep -v "^ *{line\|^$" $O/RefWrap.S | sed -n '/function/,$p' | head -80
