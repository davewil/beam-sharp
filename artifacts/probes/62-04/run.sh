#!/usr/bin/env bash
# Probe 62-04: what Gleam accepts as a function name and what it emits.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W=$(mktemp -d); cp -r "$HERE/src" "$HERE/gleam.toml" $W/; cd $W
echo "=== A. valid module: build and show generated Erlang"
gleam build 2>&1 | tail -3
for f in $(find build -name '*.erl' | sort); do echo "--- $f"; grep -v '^%' $f | grep -n "module\|export\|^[a-z_]*(\|^-spec\|-type\|->" | head -30; done
echo "=== A2. the .beam file names (module atom encoding)"
find build -name '*.beam' | sort
echo "=== A3. erlang view: exports, and the atom a PascalCase constructor becomes"
erl -noshell -pa build/dev/erlang/demo/ebin -eval 'io:format("demo exports: ~p~n",[demo:module_info(exports)]), io:format("make() -> ~p ; err() -> ~p~n",[demo:make(), demo:err()]), io:format("deep@nested exports: ~p~n",[(list_to_atom("deep@nested")):module_info(exports)]), halt().'
echo "=== B. rejected function names"
for n in a b c d; do
  cp $HERE/bad/$n.gleam src/demo.gleam; echo "--- bad/$n.gleam"; cat src/demo.gleam; echo "-->"; gleam build 2>&1 | grep -v "^ *Compiling\|Resolving" | head -20
done
rm -rf $W
