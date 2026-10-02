#!/usr/bin/env bash
# P5: what the VM itself says when an APPLICATION (not a module) is missing,
# i.e. what a declared `app:` would line up with at run time.
set -u
D="$(cd "$(dirname "$0")" && pwd)"; W="$(mktemp -d)"; cd "$W" || exit 2; fail=0
mkdir -p libA/req-0.7.3/ebin
cp "$D/src/Req_stub.erl" Elixir.Req.erl; sed -i '/on_load/d;/boot()/d' Elixir.Req.erl
erlc -o libA/req-0.7.3/ebin Elixir.Req.erl || exit 2
echo '{application,req,[{vsn,"0.7.3"},{modules,['"'Elixir.Req'"']},{applications,[kernel,stdlib,mint]}]}.' > libA/req-0.7.3/ebin/req.app
r1=$(erl -noshell -eval 'io:format("~p~n",[application:ensure_all_started(req)]), halt().')
echo "app absent entirely:           $r1"
r2=$(ERL_LIBS="$W/libA" erl -noshell -eval 'io:format("~p~n",[application:ensure_all_started(req)]), halt().')
echo "req present, its dep mint absent: $r2"
r3=$(ERL_LIBS="$W/libA" erl -noshell -eval 'io:format("~p~n",[application:load(req)]), io:format("~p~n",[application:get_key(req,applications)]), halt().')
echo "application:load(req) (no deps started): $r3"
case "$r1" in *"req.app"*) ;; *) echo "UNEXPECTED r1"; fail=1;; esac
case "$r2" in *mint*) ;; *) echo "UNEXPECTED r2"; fail=1;; esac
rm -rf "${W:?}"; exit $fail
