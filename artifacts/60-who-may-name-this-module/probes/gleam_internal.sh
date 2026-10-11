#!/usr/bin/env bash
# Probe (b): what Gleam 1.19.1 enforces for @internal and internal_modules.
# One command: ./gleam_internal.sh   (no hex access needed: both packages have zero deps)
source ${BS_ENV:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh}
HERE=$(cd "$(dirname "$0")" && pwd); W=$(mktemp -d); cp -r "$HERE/gleam/." "$W/"
gleam --version
echo "### 1. app (other package) imports lib/internal/secret and calls @internal lib.attr_internal"
cd "$W/app"; mv src/app_ctl.gleam /tmp/app_ctl.$$.gleam
gleam build 2>&1; echo "gleam build exit=$?"
erl -noshell -pa build/dev/erlang/*/ebin -eval 'io:format("app:main() = ~p  (5*2 + 2*3 = 16 means BOTH the internal module and @internal fn were reached)~n",[app:main()]),halt().'
echo
echo "### 2. what the package interface (docs/tooling) shows of lib"
(cd "$W/lib" && gleam export package-interface --out "$W/pi.json" >/dev/null 2>&1; python3 -I -c "
import json;d=json.load(open('$W/pi.json'))
for m,v in d['modules'].items(): print('module',m,'functions',sorted(v['functions']),'types',sorted(v['types']))
print('NOT listed: module lib/internal/secret, fn attr_internal, type HiddenType')")
echo
echo "### 3. explicit internal_modules in gleam.toml, other package still imports it?"
cd "$W/lib" && printf 'internal_modules = ["lib/internal", "lib/internal/*", "lib/helper"]\n' >> gleam.toml
cat > "$W/app/src/app.gleam" <<'EOT'
import lib/helper

pub fn main() -> Int {
  helper.via_helper(5)
}
EOT
cd "$W/app" && rm -rf build && gleam build 2>&1; echo "exit=$?"
echo
echo "### 4. NEGATIVE CONTROL: the compiler DOES enforce a non-pub function (so the probe could see an error)"
cp /tmp/app_ctl.$$.gleam "$W/app/src/app_ctl.gleam"; rm -f /tmp/app_ctl.$$.gleam
cd "$W/app" && gleam build 2>&1 | head -20; echo "exit=${PIPESTATUS[0]}"
