#!/usr/bin/env bash
# ticket 52: BEAM bytes added by recording provenance as a module attribute.
set -eu; cd "$(dirname "$0")"; mkdir -p attr; cd attr
printf -- "-module(a0).\n-export([f/0]).\nf() -> 1.\n" > a0.erl
printf -- "-module(a1).\n-export([f/0]).\n-bsharp_requires([{req,\"0.5\"}]).\nf() -> 1.\n" > a1.erl
printf -- "-module(a3).\n-export([f/0]).\n-bsharp_requires([{req,\"0.5\"},{epgsql,\"4.7\"},{jason,\"1.4\"}]).\nf() -> 1.\n" > a3.erl
erlc a0.erl a1.erl a3.erl
for m in a0 a1 a3; do printf "%s %s B\n" $m $(stat -c%s $m.beam); done
erl -noshell -pa . -eval 'io:format("a3 attributes: ~p~n",[proplists:get_value(bsharp_requires,a3:module_info(attributes))]),halt().'
