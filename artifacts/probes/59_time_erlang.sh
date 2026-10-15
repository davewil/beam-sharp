#!/usr/bin/env bash
set -u; cd "$(dirname "$0")"; . ./env.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/p59terl.XXXXXX"); erlc -o "$T" 59_time_erlang.erl && erl -noshell -pa "$T" -eval "'59_time_erlang':go(), halt()."
