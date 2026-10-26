#!/usr/bin/env bash
# P3: does OTP 25 have -moduledoc/-doc (OTP 27+ only)? Run it.
D=$(mktemp -d); cd "$D"
printf -- '-module(m).\n-moduledoc false.\n-export([f/0]).\nf() -> ok.\n' > m.erl
erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
erlc m.erl; echo "erlc exit=$?"
printf -- '-module(d).\n-export([f/0, g/0]).\n-deprecated([{g,0,"use f/0"}]).\nf() -> ok.\ng() -> ok.\n' > d.erl
printf -- '-module(e).\n-export([h/0]).\nh() -> d:g().\n' > e.erl
echo "--- -deprecated is advisory: compiles, warns, still callable"
erlc d.erl && erlc +warn_deprecated_function e.erl; echo "erlc exit=$?"
erl -noshell -eval 'io:format("~p~n",[e:h()]),halt().'
echo "--- is -moduledoc a real attribute on OTP 25 or an inert wild attribute?"
erl -noshell -pa . -eval 'io:format("~p~n",[m:module_info(attributes)]),halt().'
echo "--- does anything enforce -deprecated? only xref"
mkdir -p x && erlc +debug_info -o x d.erl e.erl
erl -noshell -eval '{ok,_}=xref:start(s),{ok,_}=xref:add_directory(s,"x"),io:format("~p~n",[xref:analyze(s,deprecated_function_calls)]),halt().'
