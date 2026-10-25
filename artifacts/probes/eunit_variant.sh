#!/usr/bin/env bash
# usage: eunit_variant.sh LABEL EBIN   — run compiler/test against the compiler build in EBIN.
# Copies compiler/ to $SCRATCH/run/LABEL, builds the escript the tests shell out to
# (rebar3 is not installed here; escript:create with the same archive layout), runs eunit.
. "$(dirname "$0")/env.sh"
mkdir -p "$SCRATCH/tests"
L=$1; EB=$(readlink -f "$2"); R=$SCRATCH/run/$L; rm -rf "$R"; mkdir -p "$R"
cp -r "$(dirname "$0")/../../compiler/." "$R/"; rm -rf "$R/_build"; mkdir -p "$R/_build/default/bin"
erl -noshell -eval '
  {ok,Fs}=file:list_dir("'"$EB"'"),
  Files=[{"bsc/ebin/"++F, element(2,file:read_file("'"$EB"'/"++F))} || F<-Fs],
  ok=escript:create("'"$R"'/_build/default/bin/bsc",[shebang,{emu_args,"-escript main bsc"},{archive,Files,[]}]),
  halt().'
chmod +x "$R/_build/default/bin/bsc"
mkdir -p "$R/_build/test/lib"; erlc -o "$SCRATCH/tests" "$R"/test/*.erl 2>&1 | grep -v Warning | head -3
MODS=$(cd "$SCRATCH/tests"; ls *.beam | sed 's/\.beam//' | grep -v '^bs_test_support$' | tr '\n' ',' | sed 's/,$//')
cd "$R" && timeout 1500 erl -noshell -pa "$EB" -pa "$SCRATCH/tests" -eval "eunit:test([$MODS],[verbose]), halt()." > "$SCRATCH/run/$L.log" 2>&1 < /dev/null
tail -4 "$SCRATCH/run/$L.log"; grep -c '\*failed\*' "$SCRATCH/run/$L.log"
