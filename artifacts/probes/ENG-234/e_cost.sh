#!/usr/bin/env bash
# (e) Cost of "is application X on the code path" at compile time.
set -u; D=$(mktemp -d); cd "$D"
mkdir -p libs/fakeapp/ebin
echo '{application, fakeapp, [{description,"y"},{vsn,"0.0.1"},{modules,[]},{applications,[kernel,stdlib]}]}.' > libs/fakeapp/ebin/fakeapp.app
ERL_LIBS=$PWD/libs erl -noshell -eval '
T=fun(F,N)-> {U,_}=timer:tc(fun()->[F()||_<-lists:seq(1,N)] end), U/N end,
io:format("code:lib_dir(fakeapp) ~p~n",[code:lib_dir(fakeapp)]),
io:format("code:lib_dir(absent)  ~p~n",[code:lib_dir(absent_app)]),
io:format("code:where_is_file(\"fakeapp.app\") ~p~n",[code:where_is_file("fakeapp.app")]),
io:format("code:which(lists) ~p~n",[code:which(lists)]),
io:format("first lib_dir hit us:   ~p~n",[element(1,timer:tc(fun()->code:lib_dir(fakeapp) end))]),
io:format("avg lib_dir hit us (n=10000):  ~p~n",[T(fun()->code:lib_dir(fakeapp) end,10000)]),
io:format("avg lib_dir miss us (n=10000): ~p~n",[T(fun()->code:lib_dir(absent_app) end,10000)]),
io:format("avg where_is_file miss us (n=1000):  ~p~n",[T(fun()->code:where_is_file("absent_app.app") end,1000)]),
io:format("code path entries: ~p~n",[length(code:get_path())]),
halt().'
