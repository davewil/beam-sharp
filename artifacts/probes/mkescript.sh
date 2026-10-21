#!/usr/bin/env bash
# mkescript.sh VARIANT -> installs compiler/_build/default/bin/bsc built from that variant (stand-in for `rebar3 escriptize`)
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
eb=$PROBE_HOME/variants/$1/ebin
mkdir -p "$root/compiler/_build/default/bin"
erl -noshell -eval '
  {ok,Fs}=file:list_dir("'$eb'"),
  Beams=[{"bsc/ebin/"++F,element(2,file:read_file("'$eb'/"++F))}||F<-Fs,filename:extension(F)==".beam"],
  {ok,App}=file:read_file("'$BSC_SRC'/bsc.app.src"),
  ok=escript:create("'$root'/compiler/_build/default/bin/bsc",
     [shebang,{emu_args,"-escript main bsc"},{archive,Beams,[]}]), halt().'
chmod +x "$root/compiler/_build/default/bin/bsc"
