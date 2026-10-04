#!/bin/sh
# Sub-decision "name only or version": what does the code server do when two versions of one
# application are on the path, and what would a version in the source be compared against?
. "$(dirname "$0")/env.sh"
here=$(cd "$(dirname "$0")" && pwd)
rm -rf $W/two && mkdir -p $W/two/libA $W/two/libB
for v in 1.0.0 2.0.0; do
  d=$W/two/libA/rlib-$v; mkdir -p $d; cp -r $W/rlib_src/_build/default/lib/rlib/ebin $d/
  sed -i "s/\"1.2.0\"/\"$v\"/" $d/ebin/rlib.app
done
# a version that LIES: dir says 3.0.0, .app says 1.2.0, in a separate lib dir
d=$W/two/libB/rlib-3.0.0; mkdir -p $d; cp -r $W/rlib_src/_build/default/lib/rlib/ebin $d/
echo "== ERL_LIBS=libA (rlib-1.0.0 and rlib-2.0.0 side by side)"
ERL_LIBS=$W/two/libA erl -noshell -eval '
io:format("  code:lib_dir(rlib) = ~p~n", [code:lib_dir(rlib)]),
io:format("  code:which(rlib)   = ~p~n", [code:which(rlib)]),
halt().' 2>&1 | head -6
echo "== (application:load reads the .app; vsn is then queryable)"
ERL_LIBS=$W/two/libA erl -noshell -eval '
ok = application:load(rlib), io:format("  loaded vsn = ~p~n", [application:get_key(rlib, vsn)]), halt().'
echo "== ERL_LIBS=libB:libA, directory name 3.0.0, .app says 1.2.0"
ERL_LIBS=$W/two/libB:$W/two/libA erl -noshell -eval '
io:format("  code:lib_dir(rlib) = ~p~n", [code:lib_dir(rlib)]),
ok = application:load(rlib), io:format("  .app vsn           = ~p~n", [application:get_key(rlib, vsn)]), halt().'
echo "== two copies of the SAME module on the path: which one does a call reach?"
ERL_LIBS=$W/two/libA erl -noshell -eval '
io:format("  rlib:double(2) = ~p from ~p~n", [rlib:double(2), code:which(rlib)]), halt().'
