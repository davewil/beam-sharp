#!/usr/bin/env bash
# P7a: Gleam 1.12.0 -- generated Erlang for a pub and a private function, and a private
# function returned as a value. Needs no hex package (gleam_stdlib dropped from gleam.toml).
set -e; T=$(mktemp -d); cd "$T"
/tmp/tools/gleam new probe59 --skip-git --skip-github >/dev/null 2>&1; cd probe59
python3 - <<'PY'
import re; s=open('gleam.toml').read(); open('gleam.toml','w').write(re.sub(r'\[dependencies\].*','[dependencies]\n',s,flags=re.S))
PY
rm -rf test src/*; cp "$(dirname "$0")/p7_survey_gleam.gleam" src/probe59.gleam 2>/dev/null || cp /home/user/beam-sharp/artifacts/59/probes/p7_survey_gleam.gleam src/probe59.gleam
/tmp/tools/gleam build --target erlang 2>&1 | tail -2
cat build/dev/erlang/probe59/_gleam_artefacts/probe59.erl
erl -noshell -pa build/dev/erlang/probe59/ebin -eval 'F = probe59:rule(), io:format("rule()(1.5) = ~p~n", [F(1.5)]), halt().'
