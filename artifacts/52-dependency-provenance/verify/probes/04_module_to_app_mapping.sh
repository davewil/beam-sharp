#!/bin/sh
# Can the compiler cheaply learn module -> application, and where does that break?
# Two methods: (P) path shape <lib>/<app>[-vsn]/ebin/<mod>.beam ; (A) the .app `modules` key.
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
erlc -o $W $here/prov.erl
rm -rf $W/esc_src $W/umb; cp -r $FIX/esc $W/esc_src
mkdir -p $W/orphan && cp $W/greet/out/*.beam $W/orphan/ 2>/dev/null
echo "== mix umbrella (two sibling apps), built with system OTP25/Elixir 1.14"
( cd $W && PATH=/usr/bin:/bin mix new umb --umbrella >/dev/null 2>&1 && cd umb/apps && \
  PATH=/usr/bin:/bin mix new alpha >/dev/null 2>&1 && PATH=/usr/bin:/bin mix new beta >/dev/null 2>&1 && cd .. && \
  PATH=/usr/bin:/bin mix compile 2>&1 | tail -3; ls -l _build/dev/lib; )
export ERL_LIBS=$W/greeter_build/dev/lib:$W/rlib_src/_build/default/lib:$W/glib_src/build/dev/erlang:$W/umb/_build/dev/lib
erl -noshell -pa $W -pa $W/orphan -eval '
P = fun(M) -> io:format("  P  ~-18s ~p~n", [M, prov:app_of(M)]) end,
io:format("-- (P) path-shape~n"),
[P(M) || M <- [lists, gen_server, crypto, '"'"'Elixir.Greeter'"'"', rlib_util, glib, '"'"'Elixir.Alpha'"'"', '"'"'Elixir.Beta'"'"', '"'"'Elixir.Nope'"'"']],
io:format("-- (A) .app modules / applications / vsn~n"),
[io:format("  A  ~-8s ~p~n", [A, prov:app_modules(A)]) || A <- [greeter, rlib, glib, alpha, beta, stdlib, req]],
halt().' 2>&1 | sed 's/\[\([a-z_]*,\)\{40\}.*//'
echo "== a module compiled by bsc into a plain output dir put on the path with -pa (no app)"
ls $W/orphan
erl -noshell -pa $W -pa $W/orphan -eval '
io:format("  P  Greet : ~p~n", [prov:app_of('"'"'Greet'"'"')]),
io:format("  lib_dir(orphan) : ~p~n", [code:lib_dir(orphan)]), halt().'
echo "== inside an escript (where bsc itself runs)"
( cd $W/esc_src && /tmp/tc/rebar3 escriptize 2>&1 | tail -1; ERL_LIBS=$W/greeter_build/dev/lib ./_build/default/bin/esc )
echo "== a protocol beam in mix's consolidated/ directory (ON the path in a release, NOT under ebin)"
erl -noshell -pa $W -pa $W/greeter_build/dev/lib/greeter/consolidated -eval 'io:format("  P  Elixir.Enumerable : ~p~n", [prov:app_of('"'"'Elixir.Enumerable'"'"')]), halt().'
