#!/usr/bin/env bash
# Gleam: does the compiler emit any runtime argument check on pub vs non-pub functions? Read the generated erl.
set -u; HERE="$(cd "$(dirname "$0")" && pwd)"; W=$(mktemp -d); cp -r "$HERE/proj" $W/; cd $W/proj
gleam --version; gleam build 2>&1 | tail -3
echo "=== generated code: build/dev/erlang/probe/_gleam_artefacts/probe.abstr (Gleam 1.19 writes abstract format, not .erl), pretty-printed ==="
erl -noshell -eval '{ok,Bin}=file:read_file("build/dev/erlang/probe/_gleam_artefacts/probe.abstr"), Fs=binary_to_term(Bin), [io:put_chars(erl_pp:form(F)) || F <- Fs, element(1,F)=:=function], halt().'
echo "=== forging at the boundary: pass a tuple with wrong tag and a float ==="
erl -noshell -pa build/dev/erlang/probe/ebin -eval '
T = fun(N,F) -> R = try F() catch C:E -> {C,E} end, io:format("~-28s ~p~n",[N,R]) end,
T("outer({order,1,7})", fun() -> probe:outer({order,1,7}) end),
T("outer({invoice,1,7})  forged", fun() -> probe:outer({invoice,1,7}) end),
T("outer_int(1.5)  forged", fun() -> probe:outer_int(1.5) end),
halt().'
