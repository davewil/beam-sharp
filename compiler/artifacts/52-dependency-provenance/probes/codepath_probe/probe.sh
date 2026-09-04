#!/bin/sh
# 52a -- does the compiler already have an O(1), free-standing way to ask
# "is this foreign module reachable right now?" -- run for real, 2026-09-04.
#
# fauxmod.erl is compiled to fauxapp/ebin/fauxmod.beam (NOT part of any real
# OTP application -- there is no fauxapp.app resource file). This isolates
# two different questions real Elixir/Erlang FFI code raises together:
#   (1) is the MODULE named in a `using` line on the code path right now?
#   (2) can the OTP APPLICATION name be recovered from that module alone?
set -e
cd "$(dirname "$0")"
mkdir -p fauxapp/ebin
erlc -o fauxapp/ebin fauxmod.erl

echo "=== (1) code:which/1, ERL_LIBS unset ==="
unset ERL_LIBS
erl -noshell -eval 'io:format("~p~n",[code:which(fauxmod)]), halt().'

echo "=== (1) code:which/1, ERL_LIBS pointed at the app root ==="
ERL_LIBS="$PWD" erl -noshell -eval 'io:format("~p~n",[code:which(fauxmod)]), halt().'

echo "=== (2) application:get_application/1 on a real, loaded stdlib module ==="
erl -noshell -eval 'io:format("lists -> ~p~n",[application:get_application(lists)]), halt().'

echo "=== (2) application:get_application/1 on fauxmod: on the path, but no .app file names it ==="
ERL_LIBS="$PWD" erl -noshell -eval \
  "code:ensure_loaded(fauxmod), io:format(\"fauxmod -> ~p~n\",[application:get_application(fauxmod)]), halt()."

echo "=== (2) same probe against REAL Elixir (Elixir.Enum), app root from :code.lib_dir(:elixir) ==="
LIBDIR=$(elixir -e "IO.puts(:code.lib_dir(:elixir))" 2>/dev/null)
PARENT=$(dirname "$LIBDIR")
ERL_LIBS="$PARENT" erl -noshell -eval \
  "code:ensure_loaded('Elixir.Enum'), io:format(\"which -> ~p~n\",[code:which('Elixir.Enum')]), io:format(\"get_application (no explicit load) -> ~p~n\",[application:get_application('Elixir.Enum')]), application:load(elixir), io:format(\"get_application (after application:load(elixir)) -> ~p~n\",[application:get_application('Elixir.Enum')]), halt()."
