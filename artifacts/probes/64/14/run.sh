#!/usr/bin/env bash
# Probe 64/14 - cost of the operation-pair shape (Has + Get) against a tagged find and a defaulted get.
set -u; cd "$(dirname "$0")"; W=$(mktemp -d); trap 'rm -rf $W' EXIT
erlc -o $W pair.erl && erl -noshell -pa $W -eval 'pair:bench(), halt().'
