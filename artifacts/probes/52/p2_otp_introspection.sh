#!/usr/bin/env bash
# P2: what can plain OTP tell a compile-time check about a module and its application?
set -u; . "$(dirname "$0")/common.sh"
mkfake $WORK/lib
q() { ERL_LIBS=$WORK/lib erl -noshell -eval "$1" -eval 'halt().'; }
echo "--- module present on path, app NOT loaded"
q 'io:format("code:which(fakereq)        = ~p~n",[code:which(fakereq)]),
   io:format("code:which(nope)           = ~p~n",[code:which(nope)]),
   io:format("code:lib_dir(fakereq)      = ~p~n",[code:lib_dir(fakereq)]),
   io:format("code:lib_dir(nope)         = ~p~n",[code:lib_dir(nope)]),
   io:format("get_application(fakereq)   = ~p~n",[application:get_application(fakereq)]),
   io:format("get_key(fakereq,vsn)       = ~p~n",[application:get_key(fakereq,vsn)])'
echo "--- after application:load(fakereq)"
q 'ok = application:load(fakereq),
   io:format("get_key(fakereq,vsn)       = ~p~n",[application:get_key(fakereq,vsn)]),
   io:format("get_key(fakereq,modules)   = ~p~n",[application:get_key(fakereq,modules)]),
   io:format("get_application(fakereq)   = ~p~n",[application:get_application(fakereq)])'
echo "--- module -> app is known to OTP only through a LOADED .app file, and the names differ (Elixir.Logger lives in app logger)"
cat > $WORK/ex.erl <<'EOF'
-module(ex).
-export([m/0]).
m() ->
    {ok, Ex} = file:list_dir(code:lib_dir(elixir) ++ "/ebin") , _ = Ex,
    io:format("code:which('Elixir.String') = ~p~n", [code:which('Elixir.String')]),
    io:format("code:which('Elixir.Logger') = ~p~n", [code:which('Elixir.Logger')]),
    ok = application:load(elixir), ok = application:load(logger),
    io:format("get_application('Elixir.String') = ~p  (module String lives in app elixir)~n",
              [application:get_application('Elixir.String')]),
    io:format("get_application('Elixir.Logger') = ~p  (module Logger lives in app logger)~n",
              [application:get_application('Elixir.Logger')]).
EOF
erlc -o $WORK $WORK/ex.erl
ERL_LIBS=$(dirname "$(dirname "$(readlink -f "$(command -v elixir)")")")/lib erl -noshell -pa $WORK -eval 'ex:m()' -eval 'halt().' 2>&1 | head
echo "--- app lookup by file when module is absent but app dir exists with the .app file"
q 'io:format("code:where_is_file(\"fakereq.app\") = ~p~n",[code:where_is_file("fakereq.app")]),
   io:format("code:where_is_file(\"req.app\")     = ~p~n",[code:where_is_file("req.app")])'
echo "--- scan ERL_LIBS-style path for an .app declaring a module (cost, 1 call)"
q '{T,R}=timer:tc(fun()->[ F || D<-code:get_path(), F<-filelib:wildcard(filename:join(D,"*.app"))] end),
   io:format("scanned ~p .app files in ~p us~n",[length(R),T])'
