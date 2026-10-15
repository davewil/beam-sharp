#!/usr/bin/env bash
set -u; cd "$(dirname "$0")"; . ./env.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59erl.XXXXXX"); erlc -o "$T" 59_erlang_survey.erl && erl -noshell -pa "$T" -eval "'59_erlang_survey':go(), halt()."
L=$(ls -d /nix/store/*erlang-28*/lib/erlang/lib/stdlib-*/src | head -1)
echo "--- stdlib idiom: guard at the exported door, none in the local worker ($L/lists.erl)"; sed -n '477,479p;481,487p' "$L/lists.erl"
