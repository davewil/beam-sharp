#!/usr/bin/env bash
# ticket 60: does Gleam enforce internal_modules / @internal across packages?  Expect rc=0 both times.
set -u; cd "$(dirname "$0")/gl"; export PATH=/opt/gleam:$PATH
rm -rf app/build lib/build
(cd app && gleam build --target erlang > ../app.log 2>&1; echo "app (imports lib/internal/secret, calls helper() and @internal marked()) rc=$?"; tail -3 ../app.log)
(cd lib && gleam docs build > ../docs.log 2>&1; python3 -I -c "
import json;d=json.load(open('build/dev/docs/lib/package-interface.json'));print('modules in generated docs:',list(d['modules'].keys()))")
