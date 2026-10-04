#!/usr/bin/env bash
# Side finding (NOT this ticket): `type T = int where value == 3` fails with "compile: a.bs:0: bad range type" with a
# POSITIVE literal, on the unpatched bsc. erl_lint rejects a range whose bounds are equal (stdlib-7.0/src/erl_lint.erl:3432-3436,
# requires X < Y; message from :555-556). Confirm Erlang itself rejects `3..3` and `-3..-3`.
export PATH=/opt/otp28/bin:$PATH
d=$(mktemp -d); trap 'rm -rf $d' EXIT; cd $d
printf -- '-module(r).\n-export([f/1]).\n-type t() :: 3..3.\n-spec f(t()) -> ok.\nf(_) -> ok.\n' > r.erl; echo "== erlc, -type t() :: 3..3."; erlc r.erl 2>&1
printf -- '-module(r).\n-export([f/1]).\n-type t() :: -3..-3.\n-spec f(t()) -> ok.\nf(_) -> ok.\n' > r.erl; echo "== erlc, -type t() :: -3..-3."; erlc r.erl 2>&1
source /home/user/beam-sharp/artifacts/57-negative-literals-in-refinements/probes/lib.sh
probe EqThree 'type T = int where value == 3
public int Id(T b)
Id(b) -> b'
