#!/bin/sh
# Gleam internal_modules/@internal probe. Usage: sh run.sh <gleam-binary>
G=${1:?gleam binary}; cd "$(dirname "$0")"
echo "## A: other package imports lib/internal/helper (internal_modules) and calls @internal api.secret"
(cd app_internal && rm -rf build && $G build 2>&1 | tail -8; echo "rc=$?")
echo "## B (control): other package calls a NON-pub fn"; (cd app && rm -rf build && $G build 2>&1 | grep -A6 '^error')
echo "## interface export: internal hidden?"; (cd lib && $G export package-interface --out ../iface.json >/dev/null 2>&1; python3 -I -c "
import json;d=json.load(open('../iface.json'));print({m:list(v['functions']) for m,v in d['modules'].items()})")
echo "## generated erl exports"; grep -h "^-export" app_internal/build/dev/erlang/lib/_gleam_artefacts/*.erl
