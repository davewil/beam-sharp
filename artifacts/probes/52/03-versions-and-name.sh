#!/usr/bin/env bash
# CLAIM (ticket 52): "A name is checkable at compile time; a version constraint is resolution".
# Tests (a) where the VERSION lives for a present app (dir name vs .app vsn), (b) which of two versions
# the code server hands back, (c) how regular installed `vsn` values are (could a compiler compare them?).
# REFUTED IF: (a) lib_dir and the .app vsn always agree (then "mismatch" is not a hazard);
#             (b) the first ERL_LIBS entry does NOT win / the choice is not deterministic;
#             (c) every installed vsn parses as dotted-numeric (then a minimum-version compare is trivial).
. "$(dirname "$0")/lib.sh"
V=$WORK/vers; rm -rf "$V"; mkdir -p "$V/a" "$V/b" "$V/c"
echo "### (a) dir name says 9.9.9, the .app inside says 0.3.1"
cp -r "$MYLIBS/mylib" "$V/a/mylib-9.9.9"
ERL_LIBS=$V/a erl -noshell -eval 'io:format("lib_dir(mylib)=~s~n",[code:lib_dir(mylib)]), ok=application:load(mylib), {ok,Vs}=application:get_key(mylib,vsn), io:format("application vsn=~s~n",[Vs]), halt().'
echo; echo "### (b1) two versions side by side in ONE ERL_LIBS dir: mylib-0.3.1 and mylib-0.10.0 (.app vsn patched to match)"
cp -r "$MYLIBS/mylib" "$V/b/mylib-0.3.1"
cp -r "$MYLIBS/mylib" "$V/b/mylib-0.10.0"; sed -i 's/{vsn,"0.3.1"}/{vsn,"0.10.0"}/' "$V/b/mylib-0.10.0/ebin/mylib.app"
ERL_LIBS=$V/b erl -noshell -eval 'io:format("lib_dir(mylib)=~s~n",[code:lib_dir(mylib)]), ok=application:load(mylib), {ok,Vs}=application:get_key(mylib,vsn), io:format("loaded vsn=~s~n",[Vs]), halt().'
echo; echo "### (b2) two ERL_LIBS entries, the 0.3.1 one listed FIRST, 0.10.0 second"
mkdir -p "$V/c/x" "$V/c/y"; cp -r "$MYLIBS/mylib" "$V/c/x/mylib"; cp -r "$MYLIBS/mylib" "$V/c/y/mylib"; sed -i 's/{vsn,"0.3.1"}/{vsn,"0.10.0"}/' "$V/c/y/mylib/ebin/mylib.app"
ERL_LIBS=$V/c/x:$V/c/y erl -noshell -eval 'io:format("lib_dir(mylib)=~s~n",[code:lib_dir(mylib)]), ok=application:load(mylib), {ok,Vs}=application:get_key(mylib,vsn), io:format("loaded vsn=~s~n",[Vs]), halt().'
echo "(reversed order)"
ERL_LIBS=$V/c/y:$V/c/x erl -noshell -eval 'ok=application:load(mylib), {ok,Vs}=application:get_key(mylib,vsn), io:format("loaded vsn=~s~n",[Vs]), halt().'
echo; echo "### (c) every vsn in every .app file installed under the toolchain, classified"
find "$SCRATCH/env/lib" -name '*.app' | sort > "$V/apps.txt"; wc -l < "$V/apps.txt" | sed 's/^/app files: /'
erl -noshell -eval '
{ok,B}=file:read_file("'$V/apps.txt'"), Fs=string:tokens(binary_to_list(B),"\n"),
Vs=lists:flatmap(fun(F)-> case file:consult(F) of {ok,[{application,N,P}]} -> [{N,proplists:get_value(vsn,P)}]; _ -> [] end end, Fs),
Num=fun(V)-> re:run(V,"^[0-9]+(\\.[0-9]+){1,3}$",[{capture,none}])=:=match end,
{Good,Odd}=lists:partition(fun({_,V})-> is_list(V) andalso Num(V) end, Vs),
io:format("with an .app vsn: ~p  dotted-numeric: ~p  other: ~p~n",[length(Vs),length(Good),length(Odd)]),
io:format("other forms: ~p~n",[Odd]),
halt().'
