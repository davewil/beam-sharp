#!/usr/bin/env bash
# eunit.sh EBIN_DIR LABEL -- run the in-VM unit modules against a hand-built bsc.
# rebar3 is broken on OTP 29, so this lays out what bs_test_support:project_root/0
# expects (cwd under _build/) in a scratch tree. Modules that shell out to the
# escript (cli_tests and friends) cannot run: UNMEASURED here.
set -u
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
ebin=$(cd "$1" && pwd); label=$2
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT
lib=$root/_build/test/lib/bsc; mkdir -p "$lib"
cp -r /home/user/beam-sharp/compiler/examples "$root/examples" 2>/dev/null
cp -r /home/user/beam-sharp/compiler/bin "$root/bin" 2>/dev/null
mkdir -p "$lib/test"
erlc -W0 -o "$lib/test" /home/user/beam-sharp/compiler/test/*.erl 2>&1 | head -5
mkdir -p "$root/_build/default/bin"
printf '#!/bin/sh\nexport PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8\nexec erl -noshell -pa %s -eval '"'"'bsc:main(init:get_plain_arguments()), halt().'"'"' -extra "$@"\n' "$ebin" > "$root/_build/default/bin/bsc"
chmod +x "$root/_build/default/bin/bsc"   # stands in for the escript rebar3 cannot build
cd "$lib"
mods=${MODS:-$(ls /home/user/beam-sharp/compiler/test/*_tests.erl | xargs -n1 basename | sed "s/\.erl//" | tr "\n" " ")}
MODS_RUN="$mods" erl -noshell -pa "$ebin" -pa "$lib/test" -eval '
  Mods = [list_to_atom(M) || M <- string:tokens(os:getenv("MODS_RUN"), " ")],
  Rs = [begin R = eunit:test(M, []), io:format("RESULT ~-30s ~p~n", [M, R]), R end || M <- Mods],
  halt().' 2>&1 | grep -E "^RESULT|Failed:|Passed|failed\*" | sed "s/^/[$label] /"
