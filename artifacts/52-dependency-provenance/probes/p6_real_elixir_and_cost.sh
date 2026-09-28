#!/bin/sh
# PROBE 6 — (a) the same lookups against the REAL Elixir install (unversioned dirs lib/<app>/ebin), (b) cost of the proposed
# compile-time check relative to compiling one small module, (c) size of the candidate declarations in bytes.
# PREDICTIONS: (a) with ERL_LIBS=/usr/lib/elixir/lib, lib_dir(logger) resolves and 'Elixir.Logger' -> app logger via path parse;
#   without it both fail. (b) the check for one app (code:lib_dir ~2-3us) is >1000x cheaper than erlc on a trivial module (~100s of ms
#   of VM start-up; I expect ~200-400 ms wall) so latency cannot be an argument against the check. (c) `app: req` adds ~10 bytes/using block.
cd "$(dirname "$0")"
echo "== ERL_LIBS=/usr/lib/elixir/lib"
ERL_LIBS=/usr/lib/elixir/lib erl -noshell -eval '[io:format("  lib_dir(~w)=~p~n",[A,code:lib_dir(A)]) || A <- [elixir,logger,mix,req]], [io:format("  which(~w)=~p~n",[M,code:which(M)]) || M <- [ '"'"'Elixir.Logger'"'"','"'"'Elixir.String'"'"','"'"'Elixir.Req'"'"']], halt().'
echo "== ERL_LIBS unset"
env -u ERL_LIBS erl -noshell -eval '[io:format("  lib_dir(~w)=~p~n",[A,code:lib_dir(A)]) || A <- [elixir,logger,mix,req]], [io:format("  which(~w)=~p~n",[M,code:which(M)]) || M <- [ '"'"'Elixir.Logger'"'"','"'"'Elixir.String'"'"','"'"'Elixir.Req'"'"']], halt().'
echo "== wall time: erlc on a trivial module vs VM+check (VM start+halt is the floor for any Erlang tool; bsc is already a running VM)"
W=work/p6; rm -rf $W; mkdir -p $W; printf -- '-module(t).\n-export([f/0]).\nf() -> 1.\n' > $W/t.erl
t() { s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )); }
for i in 1 2 3; do echo "  erlc t.erl: $(cd $W && t erlc t.erl) ms"; done
for i in 1 2 3; do echo "  erl -noshell -eval halt: $(t erl -noshell -eval 'halt().') ms"; done
echo "  in-VM cost of check for 9 apps (lib_dir x9, mean of 1000 runs), microseconds:"
erl -noshell -eval 'Apps=[stdlib,kernel,ssl,inets,crypto,public_key,mnesia,xmerl,nope], {T,_}=timer:tc(fun()->[[code:lib_dir(A)||A<-Apps]||_<-lists:seq(1,1000)] end), io:format("  ~.2f us per 9-app check~n",[T/1000]), halt().'
echo "== declaration sizes in bytes (one using block header)"
for h in "using :'Elixir.Req' {" "[app: req] using :'Elixir.Req' {" "[external: elixir, app: req] using :'Elixir.Req' {" "requires :req;"; do printf '  %3d  %s\n' "$(printf %s "$h" | wc -c)" "$h"; done
