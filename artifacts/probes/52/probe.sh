#!/usr/bin/env bash
# ticket 52: what does each neighbour say at COMPILE time when a dependency's module is absent from the code path?
set -u; cd "$(dirname "$0")"; mkdir -p out; export PATH=/opt/gleam:$PATH
echo "== erlc (OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().'))"; erlc +debug_info -o out caller.erl; echo "rc=$?"
echo "== erlc +warn_missing / xref"; erl -noshell -pa out -eval 'xref:start(s), xref:set_default(s,[{warnings,true}]), {ok,_}=xref:add_directory(s,"out"), io:format("~p~n",[xref:analyze(s,undefined_function_calls)]), halt().'
echo "== run it"; erl -noshell -pa out -eval 'try caller:go() catch C:R -> io:format("~p:~p~n",[C,R]) end, halt().'
echo "== elixirc (no dep on path)"; elixirc -o out caller.ex > ex.log 2>&1; echo "rc=$?"; head -3 ex.log
echo "== elixirc with @compile {:no_warn_undefined, Req}"; elixirc -o out caller_noWarn.ex > ex2.log 2>&1; echo "rc=$?"; head -3 ex2.log
echo "== gleam @external to Elixir.Req"; (cd gl && gleam build --target erlang > ../gl.log 2>&1; echo "rc=$?"; tail -3 ../gl.log)
echo "== presence check cost: code:which / code:lib_dir on a missing app"
erl -noshell -eval '
 T=fun(F,N)-> {U,_}=timer:tc(fun()->[F()||_<-lists:seq(1,N)] end), U/N end,
 io:format("code:which(missing)   = ~p, ~.2f us/call~n",[code:which(req_x), T(fun()->code:which(req_x) end,10000)]),
 io:format("code:lib_dir(missing) = ~p, ~.2f us/call~n",[code:lib_dir(req_x), T(fun()->code:lib_dir(req_x) end,10000)]),
 io:format("code:which(lists)     = ~p, ~.2f us/call~n",[code:which(lists), T(fun()->code:which(lists) end,10000)]),
 halt().'
