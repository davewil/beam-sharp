#!/usr/bin/env bash
# CLAIM (mine): if every `using` had to carry an app, authors would have to know that `:erlang` lives in `erts`, `:ets`
# in `stdlib`, `:file` in `kernel` -- facts that are not guessable from the module atom -- and the 14 `using :erlang`
# blocks of the corpus would each need `app: erts`.   Run in a plain VM.
# REFUTED IF: get_application/1 answers `erlang` with `erts` without help, or the app name equals the module name for
# most of the corpus's OTP modules.
. "$(dirname "$0")/lib.sh"
env -u ERL_LIBS erl -noshell -eval '
Ms=[erlang,ets,lists,file,maps,binary,string,gen_server,json,crypto],
io:format("before loading any application:~n"),
[io:format("  ~-11w get_application=~w~n",[M,application:get_application(M)])||M<-Ms],
[application:load(A)||A<-[erts,crypto,kernel,stdlib]],
io:format("after application:load of erts, crypto, kernel, stdlib:~n"),
[io:format("  ~-11w get_application=~w~n",[M,application:get_application(M)])||M<-Ms],
halt().'
cd /home/user/beam-sharp
echo "count of foreign using blocks per module atom, repo .bs corpus: compiler/examples (incl. exemplars) and wayfinder/prototypes:"
grep -rhoE "using\s+:('[^']+'|[a-zA-Z_0-9@]+)\s*\{" --include=*.bs compiler/examples wayfinder/prototypes 2>/dev/null | sed -E "s/using\s+://; s/\s*\{//" | sort | uniq -c | sort -rn
