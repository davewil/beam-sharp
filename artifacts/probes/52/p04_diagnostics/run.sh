#!/bin/sh
# p04: diagnostics before/after. PROTOTYPE compiler (proto/build.sh): `using :M in :app { }`.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
"$HERE/../proto/build.sh" /tmp/bs52_proto >/dev/null 2>&1 || { echo "proto build failed"; exit 1; }
B="$HERE/../proto/bsc52.sh"
EL=/tmp/otp/lib/elixir/lib
W=$(mktemp -d)
mk() { rm -rf "$W/Probe"; mkdir "$W/Probe"; cp "$HERE/src/$1.bs" "$W/Probe/probe.bs"; }
run() { ( cd "$W"; echo "\$ BS52=$1 ERL_LIBS=${2:-<unset>} bsc Probe $3"; env -u ERL_LIBS ${2:+ERL_LIBS=$2} BS52=$1 "$B" Probe $3 > "$W/o" 2>&1; rc=$?; sed 's/^/    /' "$W/o"; echo "    exit=$rc" ); }
echo "######## 0. BASELINE (unpatched semantics: no BS52): compile only vs run, lib missing"
mk plain
run off "" ""
run off "" "Shout \"hi\""
echo "######## 1. module-presence check, no new syntax (BS52=module)"
run module "" ""
run module "$EL" "Shout \"hi\""
echo "######## 2. app named, correct (BS52=app)"
mk right; run app "" ""; run app "$EL" "Shout \"hi\""
echo "######## 3. app named, WRONG application (module lives in elixir, declared eex)"
mk wrongapp; run app "$EL" "Shout \"hi\""
echo "######## 4. app named, application absent (req), module present elsewhere"
mk wrongname; run app "$EL" "Shout \"hi\""
echo "######## 5. false positive: module reachable by bare -pa (no app dir), app check refuses"
T=$(mktemp -d); mkdir $T/bare; cp $EL/elixir/ebin/* $T/bare/
mk right
( cd "$W"; echo "\$ BS52=module  erl -pa bare  (module check)";
  env -u ERL_LIBS BS52=module erl -noshell -pa "$T/bare" -pa /tmp/bs52_proto/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra Probe Shout '"hi"' 2>&1 | sed 's/^/    /'
  echo "\$ BS52=app     erl -pa bare  (app check)";
  env -u ERL_LIBS BS52=app erl -noshell -pa "$T/bare" -pa /tmp/bs52_proto/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra Probe Shout '"hi"' 2>&1 | sed 's/^/    /' )
