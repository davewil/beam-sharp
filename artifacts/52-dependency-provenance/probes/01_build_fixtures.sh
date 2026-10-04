#!/bin/sh
# Builds three real libraries, one per neighbour toolchain, into $W.
. "$(dirname "$0")/env.sh"
now() { date +%s%N; }; ms() { echo "  built in $(( ($(now) - $1) / 1000000 )) ms"; }
rm -rf $W/greeter_src $W/greeter_build $W/rlib_src $W/glib_src
echo "== Elixir lib via mix (system OTP 25 + Elixir 1.14; beams then loaded by OTP 28)"
cp -r $FIX/greeter $W/greeter_src
t=$(now); (cd $W/greeter_src && PATH=/usr/bin:/bin GREETER_BUILD=$W/greeter_build mix compile 2>&1 | tail -4)
ms $t
find $W/greeter_build -name '*.beam' -o -name '*.app' | sort
echo "== Erlang lib via rebar3 (OTP 28)"
cp -r $FIX/rlib $W/rlib_src
t=$(now); (cd $W/rlib_src && /tmp/tc/rebar3 compile 2>&1 | tail -3); ms $t
find $W/rlib_src/_build -name '*.beam' -o -name '*.app' | sort
echo "== Gleam lib via gleam (OTP 28)"
mkdir -p $W/glib_src && cp -r $FIX/glib/. $W/glib_src/
t=$(now); (cd $W/glib_src && /tmp/tc/gleam build --target erlang 2>&1 | tail -5); ms $t
find $W/glib_src/build -name '*.beam' -o -name '*.app' | head -20
